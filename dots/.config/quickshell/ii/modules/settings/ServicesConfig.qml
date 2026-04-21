import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell.Io
import qs.services
import qs.modules.common
import qs.modules.common.widgets

ContentPage {
    id: servicesPage
    forceWidth: true

    property var allSystemServices: []
    property var _collected: ({})
    property int _pendingCount: 0

    function _parseServices(text) {
        const lines = text.trim().split("\n");
        const names = [];
        for (let i = 0; i < lines.length; i++) {
            const parts = lines[i].trim().split(/\s+/);
            if (parts.length >= 1 && parts[0].endsWith(".service")) {
                const name = parts[0].replace(/\.service$/, "");
                if (!name.endsWith("@")) {
                    names.push(name);
                }
            }
        }
        return names;
    }

    function _collectResult(key, names) {
        _collected[key] = names;
        _pendingCount--;
        if (_pendingCount > 0) return;

        const userKeys = new Set(["userFiles", "userUnits"]);
        const seen = new Set();
        const merged = [];
        const keys = Object.keys(_collected);
        for (let k = 0; k < keys.length; k++) {
            const isUser = userKeys.has(keys[k]);
            const arr = _collected[keys[k]];
            for (let i = 0; i < arr.length; i++) {
                const dedupeKey = arr[i] + (isUser ? ":user" : ":system");
                if (!seen.has(dedupeKey)) {
                    seen.add(dedupeKey);
                    merged.push({
                        name: arr[i],
                        user: isUser,
                        display: isUser ? `${arr[i]} @${SystemInfo.username}` : arr[i]
                    });
                }
            }
        }
        merged.sort((a, b) => a.display.localeCompare(b.display));
        allSystemServices = merged;
    }

    // System unit files (templates + static services)
    Process {
        id: listSystemFilesProc
        command: ["systemctl", "list-unit-files", "--type=service", "--no-legend", "--no-pager"]
        stdout: StdioCollector {
            onStreamFinished: {
                servicesPage._collectResult("systemFiles", servicesPage._parseServices(text));
            }
        }
    }

    // User unit files
    Process {
        id: listUserFilesProc
        command: ["systemctl", "--user", "list-unit-files", "--type=service", "--no-legend", "--no-pager"]
        stdout: StdioCollector {
            onStreamFinished: {
                servicesPage._collectResult("userFiles", servicesPage._parseServices(text));
            }
        }
    }

    // Running system units (includes instantiated templates like syncthing@mtfk)
    Process {
        id: listSystemUnitsProc
        command: ["systemctl", "list-units", "--type=service", "--all", "--no-legend", "--no-pager"]
        stdout: StdioCollector {
            onStreamFinished: {
                servicesPage._collectResult("systemUnits", servicesPage._parseServices(text));
            }
        }
    }

    // Running user units (includes instantiated templates)
    Process {
        id: listUserUnitsProc
        command: ["systemctl", "--user", "list-units", "--type=service", "--all", "--no-legend", "--no-pager"]
        stdout: StdioCollector {
            onStreamFinished: {
                servicesPage._collectResult("userUnits", servicesPage._parseServices(text));
            }
        }
    }

    Component.onCompleted: {
        _pendingCount = 4;
        listSystemFilesProc.running = true;
        listUserFilesProc.running = true;
        listSystemUnitsProc.running = true;
        listUserUnitsProc.running = true;
    }

    ContentSection {
        icon: "manufacturing"
        title: Translation.tr("Systemd Services")

        ContentSubsectionLabel {
            text: Translation.tr("Services listed here appear as toggles in the right sidebar for quick start/stop control.")
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 4

            Repeater {
                model: Config.options.systemd.services

                RowLayout {
                    required property int index
                    required property string modelData
                    Layout.fillWidth: true
                    spacing: 8

                    MaterialSymbol {
                        text: "drag_indicator"
                        iconSize: Appearance.font.pixelSize.normal
                        color: Appearance.colors.colSubtext
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: {
                            const state = Systemd.getState(modelData);
                            return state.user ? `${modelData} @${SystemInfo.username}` : modelData;
                        }
                        font.pixelSize: Appearance.font.pixelSize.small
                        color: Appearance.colors.colOnLayer2
                    }

                    RippleButton {
                        implicitWidth: 32
                        implicitHeight: 32
                        onClicked: {
                            let services = [...Config.options.systemd.services];
                            services.splice(index, 1);
                            Config.options.systemd.services = services;
                        }
                        contentItem: MaterialSymbol {
                            anchors.centerIn: parent
                            text: "close"
                            iconSize: Appearance.font.pixelSize.normal
                            color: Appearance.colors.colError
                        }
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Item {
                Layout.fillWidth: true
                implicitHeight: newServiceField.implicitHeight

                MaterialTextField {
                    id: newServiceField
                    anchors.left: parent.left
                    anchors.right: parent.right
                    placeholderText: Translation.tr("Service name (e.g. docker, sshd, tailscaled)")
                    onAccepted: {
                        if (suggestionList.visible && suggestionList.currentIndex >= 0) {
                            newServiceField.text = filteredModel[suggestionList.currentIndex].name;
                            suggestionPopup.visible = false;
                        } else {
                            addServiceButton.addService();
                        }
                    }
                    onTextChanged: {
                        suggestionList.currentIndex = -1;
                        suggestionPopup.visible = newServiceField.text.trim().length > 0 && filteredModel.length > 0;
                    }

                    property var filteredModel: {
                        const query = newServiceField.text.trim().toLowerCase();
                        if (query === "") return [];
                        const existing = Config.options.systemd.services;
                        const results = [];
                        for (let i = 0; i < servicesPage.allSystemServices.length && results.length < 8; i++) {
                            const svc = servicesPage.allSystemServices[i];
                            if (svc.name.toLowerCase().indexOf(query) !== -1 && existing.indexOf(svc.name) === -1) {
                                results.push(svc);
                            }
                        }
                        return results;
                    }

                    Keys.onPressed: event => {
                        if (!suggestionPopup.visible) return;
                        if (event.key === Qt.Key_Down) {
                            suggestionList.currentIndex = Math.min(suggestionList.currentIndex + 1, newServiceField.filteredModel.length - 1);
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Up) {
                            suggestionList.currentIndex = Math.max(suggestionList.currentIndex - 1, -1);
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Escape) {
                            suggestionPopup.visible = false;
                            event.accepted = true;
                        }
                    }

                    onActiveFocusChanged: {
                        if (!activeFocus) {
                            Qt.callLater(() => { suggestionPopup.visible = false; });
                        }
                    }
                }

                Popup {
                    id: suggestionPopup
                    visible: false
                    y: newServiceField.height + 4
                    width: newServiceField.width
                    height: Math.min(suggestionList.contentHeight + 16, 300)
                    padding: 4
                    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutsideParent

                    background: Item {
                        StyledRectangularShadow {
                            target: popupBg
                        }
                        Rectangle {
                            id: popupBg
                            anchors.fill: parent
                            color: Appearance.m3colors.m3surfaceContainerHigh
                            radius: Appearance.rounding.small
                        }
                    }

                    contentItem: ListView {
                        id: suggestionList
                        clip: true
                        implicitHeight: contentHeight
                        model: newServiceField.filteredModel
                        currentIndex: -1
                        interactive: contentHeight > 280

                        delegate: RippleButton {
                            required property int index
                            required property var modelData
                            width: suggestionList.width
                            implicitHeight: 36
                            buttonRadius: Appearance.rounding.small
                            colBackground: index === suggestionList.currentIndex ? Appearance.colors.colLayer2 : "transparent"

                            onClicked: {
                                newServiceField.text = modelData.name;
                                suggestionPopup.visible = false;
                                addServiceButton.addService();
                            }

                            contentItem: StyledText {
                                anchors.verticalCenter: parent.verticalCenter
                                leftPadding: 8
                                text: modelData.display
                                font.pixelSize: Appearance.font.pixelSize.small
                                color: Appearance.colors.colOnLayer1
                            }
                        }
                    }
                }
            }

            RippleButton {
                id: addServiceButton
                implicitWidth: 36
                implicitHeight: 36

                function addService() {
                    let name = newServiceField.text.trim();
                    const atIdx = name.indexOf(" @");
                    if (atIdx !== -1) name = name.substring(0, atIdx);
                    if (name === "") return;
                    let services = [...Config.options.systemd.services];
                    if (services.indexOf(name) !== -1) return;
                    services.push(name);
                    Config.options.systemd.services = services;
                    newServiceField.text = "";
                    suggestionPopup.visible = false;
                }

                onClicked: addService()

                contentItem: MaterialSymbol {
                    anchors.centerIn: parent
                    text: "add"
                    iconSize: Appearance.font.pixelSize.larger
                    color: Appearance.colors.colPrimary
                }
            }
        }
    }

    ContentSection {
        icon: "neurology"
        title: Translation.tr("AI")

        MaterialTextArea {
            Layout.fillWidth: true
            placeholderText: Translation.tr("System prompt")
            text: Config.options.ai.systemPrompt
            wrapMode: TextEdit.Wrap
            onTextChanged: {
                Qt.callLater(() => {
                    Config.options.ai.systemPrompt = text;
                });
            }
        }
    }

    ContentSection {
        icon: "music_cast"
        title: Translation.tr("Music Recognition")

        ConfigSpinBox {
            icon: "timer_off"
            text: Translation.tr("Total duration timeout (s)")
            value: Config.options.musicRecognition.timeout
            from: 10
            to: 100
            stepSize: 2
            onValueChanged: {
                Config.options.musicRecognition.timeout = value;
            }
        }
        ConfigSpinBox {
            icon: "av_timer"
            text: Translation.tr("Polling interval (s)")
            value: Config.options.musicRecognition.interval
            from: 2
            to: 10
            stepSize: 1
            onValueChanged: {
                Config.options.musicRecognition.interval = value;
            }
        }
    }

    ContentSection {
        icon: "cell_tower"
        title: Translation.tr("Networking")

        MaterialTextArea {
            Layout.fillWidth: true
            placeholderText: Translation.tr("User agent (for services that require it)")
            text: Config.options.networking.userAgent
            wrapMode: TextEdit.Wrap
            onTextChanged: {
                Config.options.networking.userAgent = text;
            }
        }
    }

    ContentSection {
        icon: "memory"
        title: Translation.tr("Resources")

        ConfigSpinBox {
            icon: "av_timer"
            text: Translation.tr("Polling interval (ms)")
            value: Config.options.resources.updateInterval
            from: 100
            to: 10000
            stepSize: 100
            onValueChanged: {
                Config.options.resources.updateInterval = value;
            }
        }
        
    }

    ContentSection {
        icon: "file_open"
        title: Translation.tr("Save paths")

        MaterialTextArea {
            Layout.fillWidth: true
            placeholderText: Translation.tr("Video Recording Path")
            text: Config.options.screenRecord.savePath
            wrapMode: TextEdit.Wrap
            onTextChanged: {
                Config.options.screenRecord.savePath = text;
            }
        }
        
        MaterialTextArea {
            Layout.fillWidth: true
            placeholderText: Translation.tr("Screenshot Path (leave empty to just copy)")
            text: Config.options.screenSnip.savePath
            wrapMode: TextEdit.Wrap
            onTextChanged: {
                Config.options.screenSnip.savePath = text;
            }
        }
    }

    ContentSection {
        icon: "search"
        title: Translation.tr("Search")

        ConfigSwitch {
            text: Translation.tr("Use Levenshtein distance-based algorithm instead of fuzzy")
            checked: Config.options.search.sloppy
            onCheckedChanged: {
                Config.options.search.sloppy = checked;
            }
            StyledToolTip {
                text: Translation.tr("Could be better if you make a ton of typos,\nbut results can be weird and might not work with acronyms\n(e.g. \"GIMP\" might not give you the paint program)")
            }
        }

        ContentSubsection {
            title: Translation.tr("Prefixes")
            ConfigRow {
                uniform: true
                MaterialTextArea {
                    Layout.fillWidth: true
                    placeholderText: Translation.tr("Action")
                    text: Config.options.search.prefix.action
                    wrapMode: TextEdit.Wrap
                    onTextChanged: {
                        Config.options.search.prefix.action = text;
                    }
                }
                MaterialTextArea {
                    Layout.fillWidth: true
                    placeholderText: Translation.tr("Clipboard")
                    text: Config.options.search.prefix.clipboard
                    wrapMode: TextEdit.Wrap
                    onTextChanged: {
                        Config.options.search.prefix.clipboard = text;
                    }
                }
                MaterialTextArea {
                    Layout.fillWidth: true
                    placeholderText: Translation.tr("Emojis")
                    text: Config.options.search.prefix.emojis
                    wrapMode: TextEdit.Wrap
                    onTextChanged: {
                        Config.options.search.prefix.emojis = text;
                    }
                }
            }

            ConfigRow {
                uniform: true
                MaterialTextArea {
                    Layout.fillWidth: true
                    placeholderText: Translation.tr("Math")
                    text: Config.options.search.prefix.math
                    wrapMode: TextEdit.Wrap
                    onTextChanged: {
                        Config.options.search.prefix.math = text;
                    }
                }
                MaterialTextArea {
                    Layout.fillWidth: true
                    placeholderText: Translation.tr("Shell command")
                    text: Config.options.search.prefix.shellCommand
                    wrapMode: TextEdit.Wrap
                    onTextChanged: {
                        Config.options.search.prefix.shellCommand = text;
                    }
                }
                MaterialTextArea {
                    Layout.fillWidth: true
                    placeholderText: Translation.tr("Web search")
                    text: Config.options.search.prefix.webSearch
                    wrapMode: TextEdit.Wrap
                    onTextChanged: {
                        Config.options.search.prefix.webSearch = text;
                    }
                }
            }
        }
        ContentSubsection {
            title: Translation.tr("Web search")
            MaterialTextArea {
                Layout.fillWidth: true
                placeholderText: Translation.tr("Base URL")
                text: Config.options.search.engineBaseUrl
                wrapMode: TextEdit.Wrap
                onTextChanged: {
                    Config.options.search.engineBaseUrl = text;
                }
            }
        }
    }

    // There's no update indicator in ii for now so we shouldn't show this yet
    // ContentSection {
    //     icon: "deployed_code_update"
    //     title: Translation.tr("System updates (Arch only)")

    //     ConfigSwitch {
    //         text: Translation.tr("Enable update checks")
    //         checked: Config.options.updates.enableCheck
    //         onCheckedChanged: {
    //             Config.options.updates.enableCheck = checked;
    //         }
    //     }

    //     ConfigSpinBox {
    //         icon: "av_timer"
    //         text: Translation.tr("Check interval (mins)")
    //         value: Config.options.updates.checkInterval
    //         from: 60
    //         to: 1440
    //         stepSize: 60
    //         onValueChanged: {
    //             Config.options.updates.checkInterval = value;
    //         }
    //     }
    // }

    ContentSection {
        icon: "weather_mix"
        title: Translation.tr("Weather")
        ConfigRow {
            ConfigSwitch {
                buttonIcon: "assistant_navigation"
                text: Translation.tr("Enable GPS based location")
                checked: Config.options.bar.weather.enableGPS
                onCheckedChanged: {
                    Config.options.bar.weather.enableGPS = checked;
                }
            }
            ConfigSwitch {
                buttonIcon: "thermometer"
                text: Translation.tr("Fahrenheit unit")
                checked: Config.options.bar.weather.useUSCS
                onCheckedChanged: {
                    Config.options.bar.weather.useUSCS = checked;
                }
                StyledToolTip {
                    text: Translation.tr("It may take a few seconds to update")
                }
            }
        }
        
        MaterialTextArea {
            Layout.fillWidth: true
            placeholderText: Translation.tr("City name")
            text: Config.options.bar.weather.city
            wrapMode: TextEdit.Wrap
            onTextChanged: {
                Config.options.bar.weather.city = text;
            }
        }
        ConfigSpinBox {
            icon: "av_timer"
            text: Translation.tr("Polling interval (m)")
            value: Config.options.bar.weather.fetchInterval
            from: 5
            to: 50
            stepSize: 5
            onValueChanged: {
                Config.options.bar.weather.fetchInterval = value;
            }
        }
    }
}

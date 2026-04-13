pragma ComponentBehavior: Bound

import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell

WindowDialog {
    id: root
    backgroundHeight: 600
    backgroundWidth: 380

    Component.onCompleted: MonitorManager.refresh()

    WindowDialogTitle {
        text: Translation.tr("Monitor Settings")
    }

    WindowDialogSeparator {}

    Flickable {
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.topMargin: -8
        Layout.bottomMargin: -8
        Layout.leftMargin: -4
        Layout.rightMargin: -4
        contentHeight: monitorColumn.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        ColumnLayout {
            id: monitorColumn
            width: parent.width
            spacing: 16

            Repeater {
                model: MonitorManager.monitors

                delegate: MonitorCard {
                    required property var modelData
                    required property int index
                    Layout.fillWidth: true
                    monitor: modelData
                    allMonitors: MonitorManager.monitors
                }
            }
        }
    }

    WindowDialogSeparator {}

    WindowDialogButtonRow {
        Layout.fillWidth: true

        DialogButton {
            buttonText: Translation.tr("Refresh")
            onClicked: MonitorManager.refresh()
        }

        Item {
            Layout.fillWidth: true
        }

        DialogButton {
            buttonText: Translation.tr("Done")
            onClicked: root.dismiss()
        }
    }

    component MonitorCard: Rectangle {
        id: card
        required property var monitor
        required property var allMonitors

        radius: Appearance.rounding.small
        color: Appearance.colors.colLayer1
        implicitHeight: cardContent.implicitHeight + 24

        ColumnLayout {
            id: cardContent
            anchors {
                fill: parent
                margins: 12
            }
            spacing: 8

            // Monitor header
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                MaterialSymbol {
                    text: "monitor"
                    iconSize: Appearance.font.pixelSize.hugeass
                    color: card.monitor.focused ? Appearance.colors.colPrimary : Appearance.colors.colOnLayer1
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    StyledText {
                        text: card.monitor.name
                        font.pixelSize: Appearance.font.pixelSize.large
                        font.weight: 600
                        color: Appearance.colors.colOnLayer1
                    }

                    StyledText {
                        text: {
                            const m = card.monitor;
                            return `${m.model || m.make || ""}  ${m.width}x${m.height}`;
                        }
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        color: Appearance.colors.colSubtext
                    }
                }

                // Enable/disable toggle
                StyledSwitch {
                    checked: !card.monitor.disabled
                    onClicked: {
                        if (checked) MonitorManager.enableMonitor(card.monitor.name);
                        else MonitorManager.disableMonitor(card.monitor.name);
                    }
                    StyledToolTip {
                        text: Translation.tr("Enable/Disable monitor")
                    }
                }
            }

            // Only show controls if monitor is enabled
            Loader {
                Layout.fillWidth: true
                active: !card.monitor.disabled
                visible: active
                sourceComponent: ColumnLayout {
                    spacing: 8

                    // Scale slider
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        StyledText {
                            text: Translation.tr("Scale: %1").arg(scaleSlider.value.toFixed(2))
                            font.pixelSize: Appearance.font.pixelSize.small
                            color: Appearance.colors.colOnLayer1
                        }

                        StyledSlider {
                            id: scaleSlider
                            Layout.fillWidth: true
                            configuration: StyledSlider.Configuration.S
                            from: 0.5
                            to: 3.0
                            stepSize: 0.25
                            value: card.monitor.scale
                            stopIndicatorValues: [0.5, 1.0, 1.5, 2.0, 2.5, 3.0]
                            tooltipContent: value.toFixed(2)

                            onPressedChanged: {
                                if (!pressed) {
                                    MonitorManager.setScale(card.monitor.name, value);
                                }
                            }
                        }
                    }

                    // Resolution/mode selector
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        StyledText {
                            text: Translation.tr("Resolution")
                            font.pixelSize: Appearance.font.pixelSize.small
                            color: Appearance.colors.colOnLayer1
                        }

                        StyledComboBox {
                            id: modeCombo
                            Layout.fillWidth: true
                            buttonIcon: "aspect_ratio"

                            property var availableModes: MonitorManager.parseAvailableModes(card.monitor)
                            model: availableModes
                            currentIndex: {
                                const current = MonitorManager.currentModeString(card.monitor);
                                for (let i = 0; i < availableModes.length; i++) {
                                    if (availableModes[i] === current) return i;
                                }
                                return 0;
                            }

                            onActivated: (index) => {
                                MonitorManager.setMode(card.monitor.name, availableModes[index]);
                            }
                        }
                    }

                    // Position controls (only when multiple monitors)
                    Loader {
                        Layout.fillWidth: true
                        active: card.allMonitors.length > 1
                        visible: active
                        sourceComponent: ColumnLayout {
                            spacing: 4

                            StyledText {
                                text: Translation.tr("Position")
                                font.pixelSize: Appearance.font.pixelSize.small
                                color: Appearance.colors.colOnLayer1
                            }

                            // Position relative to other monitors
                            Flow {
                                Layout.fillWidth: true
                                spacing: 4

                                Repeater {
                                    model: {
                                        const others = [];
                                        for (let i = 0; i < card.allMonitors.length; i++) {
                                            if (card.allMonitors[i].name !== card.monitor.name) {
                                                others.push(card.allMonitors[i]);
                                            }
                                        }
                                        return others;
                                    }

                                    delegate: ColumnLayout {
                                        required property var modelData
                                        spacing: 2

                                        StyledText {
                                            text: Translation.tr("Relative to %1").arg(modelData.name)
                                            font.pixelSize: Appearance.font.pixelSize.smaller
                                            color: Appearance.colors.colSubtext
                                        }

                                        Row {
                                            spacing: 4

                                            PositionButton {
                                                buttonIcon: "arrow_back"
                                                tooltipText: Translation.tr("Left of %1").arg(modelData.name)
                                                onClicked: MonitorManager.setPositionLeftOf(card.monitor.name, modelData.name)
                                            }
                                            PositionButton {
                                                buttonIcon: "arrow_upward"
                                                tooltipText: Translation.tr("Above %1").arg(modelData.name)
                                                onClicked: MonitorManager.setPositionAbove(card.monitor.name, modelData.name)
                                            }
                                            PositionButton {
                                                buttonIcon: "arrow_downward"
                                                tooltipText: Translation.tr("Below %1").arg(modelData.name)
                                                onClicked: MonitorManager.setPositionBelow(card.monitor.name, modelData.name)
                                            }
                                            PositionButton {
                                                buttonIcon: "arrow_forward"
                                                tooltipText: Translation.tr("Right of %1").arg(modelData.name)
                                                onClicked: MonitorManager.setPositionRightOf(card.monitor.name, modelData.name)
                                            }
                                        }
                                    }
                                }
                            }

                            // Mirror control
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2

                                StyledText {
                                    text: Translation.tr("Mirror")
                                    font.pixelSize: Appearance.font.pixelSize.small
                                    color: Appearance.colors.colOnLayer1
                                }

                                Row {
                                    spacing: 4

                                    RippleButton {
                                        implicitWidth: implicitHeight
                                        implicitHeight: 36
                                        buttonRadius: Appearance.rounding.small
                                        toggled: card.monitor.mirrorOf !== "none" && card.monitor.mirrorOf !== ""
                                        visible: card.monitor.mirrorOf !== "none" && card.monitor.mirrorOf !== ""
                                        contentItem: MaterialSymbol {
                                            text: "cancel"
                                            iconSize: Appearance.font.pixelSize.large
                                            horizontalAlignment: Text.AlignHCenter
                                            color: Appearance.colors.colOnSecondaryContainer
                                        }
                                        onClicked: MonitorManager.unmirrorMonitor(card.monitor.name)
                                        StyledToolTip {
                                            text: Translation.tr("Stop mirroring")
                                        }
                                    }

                                    Repeater {
                                        model: {
                                            const others = [];
                                            for (let i = 0; i < card.allMonitors.length; i++) {
                                                if (card.allMonitors[i].name !== card.monitor.name) {
                                                    others.push(card.allMonitors[i]);
                                                }
                                            }
                                            return others;
                                        }
                                        delegate: RippleButton {
                                            required property var modelData
                                            implicitHeight: 36
                                            padding: 12
                                            buttonRadius: Appearance.rounding.small
                                            toggled: card.monitor.mirrorOf === modelData.name
                                            contentItem: StyledText {
                                                text: modelData.name
                                                font.pixelSize: Appearance.font.pixelSize.small
                                                horizontalAlignment: Text.AlignHCenter
                                                color: Appearance.colors.colOnSecondaryContainer
                                            }
                                            onClicked: MonitorManager.mirrorMonitor(card.monitor.name, modelData.name)
                                            StyledToolTip {
                                                text: Translation.tr("Mirror %1").arg(modelData.name)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    component PositionButton: RippleButton {
        id: posBtn
        property string buttonIcon
        property string tooltipText
        implicitWidth: 36
        implicitHeight: 36
        buttonRadius: Appearance.rounding.small
        contentItem: MaterialSymbol {
            text: posBtn.buttonIcon
            iconSize: Appearance.font.pixelSize.large
            horizontalAlignment: Text.AlignHCenter
            color: Appearance.colors.colOnSecondaryContainer
        }
        StyledToolTip {
            text: posBtn.tooltipText
        }
    }
}

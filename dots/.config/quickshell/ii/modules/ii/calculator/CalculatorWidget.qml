import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

Scope {
    id: root

    property bool historyVisible: Persistent.states.calculator.history.length > 0

    Loader {
        id: calcLoader
        active: GlobalStates.calculatorOpen
        onActiveChanged: {
            if (calcLoader.active) {
                CalculatorService.clearExpression();
            }
        }

        sourceComponent: PanelWindow {
            id: calcWindow
            visible: calcLoader.active && !GlobalStates.screenLocked

            anchors {
                top: true
                left: true
                right: true
            }

            function hide() {
                GlobalStates.calculatorOpen = false;
            }

            exclusiveZone: 0
            implicitWidth: calcBackground.width
            implicitHeight: calcBackground.height
            WlrLayershell.namespace: "quickshell:calculator"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
            color: "transparent"

            mask: Region {
                item: calcBackground
            }

            property real openProgress: 0
            Behavior on openProgress {
                NumberAnimation {
                    duration: Appearance.animation.elementMove.duration
                    easing.type: Appearance.animation.elementMove.type
                    easing.bezierCurve: Appearance.animation.elementMove.bezierCurve
                }
            }

            Component.onCompleted: {
                GlobalFocusGrab.addDismissable(calcWindow);
                openProgress = 1;
                hiddenInput.forceActiveFocus();
            }
            Component.onDestruction: {
                GlobalFocusGrab.removeDismissable(calcWindow);
            }
            Connections {
                target: GlobalFocusGrab
                function onDismissed() {
                    calcWindow.hide();
                }
            }

            TextInput {
                id: hiddenInput
                visible: false
                focus: true
                Keys.onPressed: (event) => {
                    event.accepted = true;
                    if (event.key === Qt.Key_Escape) {
                        calcWindow.hide();
                        return;
                    }
                    if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                        CalculatorService.evaluate();
                        return;
                    }
                    if (event.key === Qt.Key_Backspace) {
                        CalculatorService.backspace();
                        return;
                    }
                    if (event.key === Qt.Key_Delete || event.key === Qt.Key_Clear) {
                        CalculatorService.clearExpression();
                        return;
                    }
                    let keyMap = {};
                    keyMap[Qt.Key_Asterisk] = "×";
                    keyMap[Qt.Key_Slash] = "÷";
                    keyMap[Qt.Key_Minus] = "−";
                    keyMap[Qt.Key_Plus] = "+";
                    keyMap[Qt.Key_Percent] = "%";
                    keyMap[Qt.Key_ParenLeft] = "(";
                    keyMap[Qt.Key_ParenRight] = ")";
                    keyMap[Qt.Key_Period] = ".";
                    keyMap[Qt.Key_Comma] = ".";
                    keyMap[Qt.Key_Caret] = "^";
                    if (keyMap[event.key]) {
                        CalculatorService.appendToExpression(keyMap[event.key]);
                        return;
                    }
                    if (event.key >= Qt.Key_0 && event.key <= Qt.Key_9) {
                        CalculatorService.appendToExpression((event.key - Qt.Key_0).toString());
                        return;
                    }
                    if (event.text && event.text.length === 1) {
                        let c = event.text;
                        let mapped = c.replace(/\*/g, '×').replace(/\//g, '÷').replace(/-/g, '−');
                        CalculatorService.appendToExpression(mapped);
                    }
                }
            }

            StyledRectangularShadow {
                target: calcBackground
            }

            Rectangle {
                id: calcBackground
                anchors.horizontalCenter: parent.horizontalCenter
                y: -calcBackground.height * (1 - calcWindow.openProgress)
                color: Appearance.colors.colLayer0
                radius: Appearance.rounding.windowRounding
                border.width: 1
                border.color: Appearance.colors.colLayer0Border
                property real padding: 12
                implicitWidth: mainLayout.implicitWidth + padding * 2
                implicitHeight: mainLayout.implicitHeight + padding * 2

                ColumnLayout {
                    id: mainLayout
                    anchors.centerIn: parent
                    spacing: 8

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        StyledText {
                            text: Translation.tr("Calculator")
                            font.pixelSize: Appearance.font.pixelSize.normal
                            font.weight: 600
                            color: Appearance.colors.colOnLayer0
                            Layout.alignment: Qt.AlignVCenter
                        }

                        Item { Layout.fillWidth: true }

                        RippleButton {
                            Layout.alignment: Qt.AlignVCenter
                            Layout.preferredWidth: 28
                            Layout.preferredHeight: 28
                            buttonRadius: Appearance.rounding.full
                            visible: CalculatorService.history.length > 0
                            colBackground: ColorUtils.transparentize(Appearance.colors.colLayer1, 0)
                            colBackgroundHover: Appearance.colors.colLayer1Hover
                            onClicked: root.historyVisible = !root.historyVisible
                            contentItem: MaterialSymbol {
                                text: "history"
                                iconSize: 18
                                fill: root.historyVisible ? 1 : 0
                                color: Appearance.colors.colOnLayer1
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }
                        }

                        RippleButton {
                            Layout.alignment: Qt.AlignVCenter
                            Layout.preferredWidth: 30
                            Layout.preferredHeight: 30
                            buttonRadius: Appearance.rounding.full
                            colBackground: ColorUtils.transparentize(Appearance.colors.colLayer1, 0)
                            colBackgroundHover: Appearance.colors.colLayer1Hover
                            onClicked: calcWindow.hide()
                            contentItem: MaterialSymbol {
                                text: "close"
                                iconSize: 18
                                color: Appearance.colors.colOnLayer1
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 4

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: displayColumn.implicitHeight + 16
                                radius: Appearance.rounding.normal
                                color: Appearance.colors.colLayer1

                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: hiddenInput.forceActiveFocus()
                                }

                                ColumnLayout {
                                    id: displayColumn
                                    anchors.fill: parent
                                    anchors.margins: 8
                                    spacing: 2

                                    StyledText {
                                        Layout.fillWidth: true
                                        text: CalculatorService.expression || "0"
                                        font.pixelSize: Config.options.calculator.fontSize
                                        color: Appearance.colors.colOnLayer1
                                        horizontalAlignment: Text.AlignRight
                                        elide: Text.ElideLeft
                                        wrapMode: Text.NoWrap
                                    }

                                    StyledText {
                                        Layout.fillWidth: true
                                        text: {
                                            if (CalculatorService.errorMsg) return CalculatorService.errorMsg;
                                            if (CalculatorService.result) return "= " + CalculatorService.result;
                                            return "";
                                        }
                                        font.pixelSize: Config.options.calculator.fontSize * 0.7
                                        font.weight: 600
                                        color: CalculatorService.errorMsg ? Appearance.colors.colError : Appearance.colors.colPrimary
                                        horizontalAlignment: Text.AlignRight
                                        elide: Text.ElideRight
                                    }
                                }
                            }

                            GridLayout {
                                Layout.fillWidth: true
                                columns: 5
                                rowSpacing: 4
                                columnSpacing: 4

                                component CalcButton: RippleButton {
                                    property string label: ""
                                    property color labelColor: Appearance.colors.colOnLayer1
                                    property color bgColor: Appearance.colors.colLayer1
                                    property color bgColorHover: Appearance.colors.colLayer1Hover
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 38
                                    buttonRadius: Appearance.rounding.small
                                    colBackground: bgColor
                                    colBackgroundHover: bgColorHover
                                    contentItem: StyledText {
                                        text: label
                                        font.pixelSize: Math.max(Config.options.calculator.fontSize * 0.6, 14)
                                        font.weight: 600
                                        color: labelColor
                                        horizontalAlignment: Text.AlignHCenter
                                        verticalAlignment: Text.AlignVCenter
                                    }
                                }

                                CalcButton { label: "C"; bgColor: Appearance.colors.colErrorContainer; labelColor: Appearance.colors.colOnErrorContainer; onClicked: CalculatorService.clearExpression() }
                                CalcButton { label: "("; onClicked: CalculatorService.appendToExpression("(") }
                                CalcButton { label: ")"; onClicked: CalculatorService.appendToExpression(")") }
                                CalcButton { label: "%"; onClicked: CalculatorService.appendToExpression("%") }
                                CalcButton { label: "⌫"; onClicked: CalculatorService.backspace() }

                                CalcButton { label: "7"; onClicked: CalculatorService.appendToExpression("7") }
                                CalcButton { label: "8"; onClicked: CalculatorService.appendToExpression("8") }
                                CalcButton { label: "9"; onClicked: CalculatorService.appendToExpression("9") }
                                CalcButton { label: "÷"; bgColor: Appearance.colors.colPrimary; labelColor: Appearance.colors.colOnPrimary; onClicked: CalculatorService.appendToExpression("÷") }
                                CalcButton { label: "^"; bgColor: Appearance.colors.colPrimary; labelColor: Appearance.colors.colOnPrimary; onClicked: CalculatorService.appendToExpression("^") }

                                CalcButton { label: "4"; onClicked: CalculatorService.appendToExpression("4") }
                                CalcButton { label: "5"; onClicked: CalculatorService.appendToExpression("5") }
                                CalcButton { label: "6"; onClicked: CalculatorService.appendToExpression("6") }
                                CalcButton { label: "×"; bgColor: Appearance.colors.colPrimary; labelColor: Appearance.colors.colOnPrimary; onClicked: CalculatorService.appendToExpression("×") }
                                CalcButton { label: "−"; bgColor: Appearance.colors.colPrimary; labelColor: Appearance.colors.colOnPrimary; onClicked: CalculatorService.appendToExpression("−") }

                                CalcButton { label: "1"; onClicked: CalculatorService.appendToExpression("1") }
                                CalcButton { label: "2"; onClicked: CalculatorService.appendToExpression("2") }
                                CalcButton { label: "3"; onClicked: CalculatorService.appendToExpression("3") }
                                CalcButton { label: "+"; bgColor: Appearance.colors.colPrimary; labelColor: Appearance.colors.colOnPrimary; onClicked: CalculatorService.appendToExpression("+") }
                                CalcButton { label: "="; bgColor: Appearance.colors.colSecondaryContainer; labelColor: Appearance.colors.colOnSecondaryContainer; onClicked: CalculatorService.evaluate() }

                                CalcButton { label: "0"; Layout.columnSpan: 2; onClicked: CalculatorService.appendToExpression("0") }
                                CalcButton { label: "."; onClicked: CalculatorService.appendToExpression(".") }
                                CalcButton { label: "⏎"; bgColor: Appearance.colors.colSecondaryContainer; labelColor: Appearance.colors.colOnSecondaryContainer; onClicked: CalculatorService.evaluate(); Layout.columnSpan: 2 }
                            }
                        }

                        ColumnLayout {
                            visible: root.historyVisible && CalculatorService.history.length > 0
                            Layout.preferredWidth: 180
                            Layout.fillHeight: true
                            spacing: 4

                            RowLayout {
                                Layout.fillWidth: true
                                StyledText {
                                    text: Translation.tr("History")
                                    font.pixelSize: Appearance.font.pixelSize.small
                                    font.weight: 600
                                    color: Appearance.colors.colOnLayer0
                                }
                                Item { Layout.fillWidth: true }
                                RippleButton {
                                    Layout.preferredWidth: 24
                                    Layout.preferredHeight: 24
                                    buttonRadius: Appearance.rounding.full
                                    colBackground: ColorUtils.transparentize(Appearance.colors.colLayer1, 0)
                                    colBackgroundHover: Appearance.colors.colLayer1Hover
                                    onClicked: root.historyVisible = false
                                    contentItem: MaterialSymbol {
                                        text: "chevron_right"
                                        iconSize: 14
                                        color: Appearance.colors.colOnLayer1
                                        horizontalAlignment: Text.AlignHCenter
                                        verticalAlignment: Text.AlignVCenter
                                    }
                                }
                                RippleButton {
                                    Layout.preferredWidth: 24
                                    Layout.preferredHeight: 24
                                    buttonRadius: Appearance.rounding.full
                                    colBackground: ColorUtils.transparentize(Appearance.colors.colLayer1, 0)
                                    colBackgroundHover: Appearance.colors.colLayer1Hover
                                    onClicked: CalculatorService.clearHistory()
                                    contentItem: MaterialSymbol {
                                        text: "delete"
                                        iconSize: 14
                                        color: Appearance.colors.colOnLayer1
                                        horizontalAlignment: Text.AlignHCenter
                                        verticalAlignment: Text.AlignVCenter
                                    }
                                }
                            }

                            StyledListView {
                                id: historyList
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                Layout.minimumHeight: 100
                                Layout.maximumHeight: 300
                                spacing: 2
                                clip: true
                                popin: true

                                model: ScriptModel {
                                    values: CalculatorService.history.slice().reverse()
                                }

                                delegate: Rectangle {
                                    id: histItem
                                    required property int index
                                    required property var modelData
                                    width: historyList.width
                                    height: histLayout.implicitHeight + 8
                                    radius: Appearance.rounding.small
                                    color: histMouseArea.containsMouse ? Appearance.colors.colLayer1Hover : Appearance.colors.colLayer1

                                    RowLayout {
                                        id: histLayout
                                        anchors.fill: parent
                                        anchors.leftMargin: 6
                                        anchors.rightMargin: 6
                                        spacing: 4

                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            spacing: 0

                                            StyledText {
                                                Layout.fillWidth: true
                                                text: histItem.modelData.expression
                                                font.pixelSize: Appearance.font.pixelSize.smaller
                                                color: Appearance.colors.colSubtext
                                                elide: Text.ElideRight
                                            }
                                            StyledText {
                                                text: "= " + histItem.modelData.result
                                                font.pixelSize: Appearance.font.pixelSize.small
                                                font.weight: 600
                                                color: Appearance.colors.colPrimary
                                            }
                                        }
                                    }

                                    MouseArea {
                                        id: histMouseArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        acceptedButtons: Qt.LeftButton
                                        onClicked: CalculatorService.useHistoryResult(histItem.modelData.result)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    IpcHandler {
        target: "calculator"

        function toggle(): void {
            GlobalStates.calculatorOpen = !GlobalStates.calculatorOpen;
        }

        function close(): void {
            GlobalStates.calculatorOpen = false;
        }

        function open(): void {
            GlobalStates.calculatorOpen = true;
        }
    }

    GlobalShortcut {
        name: "calculatorToggle"
        description: "Toggles calculator"

        onPressed: {
            GlobalStates.calculatorOpen = !GlobalStates.calculatorOpen;
        }
    }
}

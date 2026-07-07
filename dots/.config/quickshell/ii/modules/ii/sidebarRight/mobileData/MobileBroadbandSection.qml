import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts
import Quickshell

ColumnLayout {
    id: root
    spacing: 8

    WindowDialogSectionHeader {
        text: Translation.tr("Mobile broadband")
    }

    RowLayout { // Status
        Layout.fillWidth: true
        spacing: 10

        MaterialSymbol {
            iconSize: Appearance.font.pixelSize.hugeass
            text: MobileData.materialSymbol
            color: MobileData.connected ? Appearance.colors.colPrimary : Appearance.colors.colOnSurfaceVariant
        }
        StyledText {
            Layout.fillWidth: true
            color: Appearance.colors.colOnSurfaceVariant
            elide: Text.ElideRight
            text: MobileData.statusText
            textFormat: Text.PlainText
        }
        DialogButton {
            visible: MobileData.connected
            buttonText: Translation.tr("Disconnect")
            onClicked: MobileData.disconnectActive()
        }
    }

    Rectangle { // Connection profiles list
        Layout.fillWidth: true
        Layout.topMargin: 4
        visible: connectionsColumn.children.length > 0
        implicitHeight: connectionsColumn.implicitHeight
        radius: Appearance.rounding.small
        color: "transparent"
        clip: true

        ColumnLayout {
            id: connectionsColumn
            anchors {
                left: parent.left
                right: parent.right
            }
            spacing: 0

            Repeater {
                model: ScriptModel {
                    values: MobileData.connections
                    objectProp: "uuid"
                }
                delegate: MobileConnectionItem {
                    required property var modelData
                    connection: modelData
                    Layout.fillWidth: true
                }
            }
        }
    }
}

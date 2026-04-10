import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

ColumnLayout {
    id: root
    spacing: 4
    visible: serviceRepeater.count > 0

    StyledText {
        text: Translation.tr("Services")
        font.pixelSize: Appearance.font.pixelSize.small
        font.weight: 600
        color: Appearance.colors.colOnLayer1
        Layout.leftMargin: 4
    }

    Repeater {
        id: serviceRepeater
        model: Config.options.systemd.services

        RippleButton {
            id: serviceButton
            required property int index
            required property string modelData
            property var state: Systemd.getState(modelData)

            Layout.fillWidth: true
            implicitHeight: contentLayout.implicitHeight + 12

            onClicked: Systemd.toggle(modelData)

            contentItem: RowLayout {
                id: contentLayout
                spacing: 10
                anchors.fill: parent
                anchors.leftMargin: 8
                anchors.rightMargin: 8

                MaterialSymbol {
                    text: serviceButton.state.loading ? "sync" : serviceButton.state.active ? "stop_circle" : "play_circle"
                    iconSize: Appearance.font.pixelSize.larger
                    fill: serviceButton.state.active ? 1 : 0
                    color: serviceButton.state.active ? Appearance.colors.colPrimary : Appearance.colors.colOnLayer2

                    RotationAnimation on rotation {
                        running: serviceButton.state.loading
                        from: 0
                        to: 360
                        duration: 1000
                        loops: Animation.Infinite
                    }
                }

                StyledText {
                    Layout.fillWidth: true
                    text: serviceButton.modelData
                    font.pixelSize: Appearance.font.pixelSize.small
                    color: Appearance.colors.colOnLayer2
                    elide: Text.ElideRight
                }

                StyledText {
                    text: serviceButton.state.loading ? Translation.tr("...") : serviceButton.state.active ? Translation.tr("Active") : Translation.tr("Inactive")
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: serviceButton.state.active ? Appearance.colors.colPrimary : Appearance.colors.colSubtext
                }
            }
        }
    }
}

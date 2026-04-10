import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.modules.common.functions as CF

Item {
    id: root
    property bool vertical: false
    readonly property HyprlandMonitor monitor: Hyprland.monitorFor(root.QsWindow.window?.screen)
    readonly property string activeSpecialName: monitor?.lastIpcObject.specialWorkspace?.name ?? ""
    property var specialWorkspaces: Hyprland.workspaces.values.filter(w => {
        if (!w.name.startsWith("special:")) return false;
        if (Config.options.specialWorkspaces.showOnlyWithWindows) {
            // Show if has windows OR is currently active
            return w.lastIpcObject.windows > 0 || w.name === root.activeSpecialName;
        }
        return true;
    })

    visible: specialWorkspaces.length > 0 && Config.options.specialWorkspaces.showInBar
    implicitWidth: visible ? (vertical ? Appearance.sizes.verticalBarWidth : workspaceRow.implicitWidth) : 0
    implicitHeight: visible ? (vertical ? workspaceRow.implicitHeight : Appearance.sizes.barHeight) : 0

    Behavior on implicitWidth {
        animation: Appearance.animation.elementMove.numberAnimation.createObject(this)
    }

    RowLayout {
        id: workspaceRow
        visible: !root.vertical
        anchors.centerIn: parent
        spacing: 2

        Repeater {
            model: root.specialWorkspaces

            SpecialWsButton {
                required property var modelData
                wsName: modelData.name
                wsWindows: modelData.lastIpcObject.windows
                isActive: modelData.name === root.activeSpecialName
            }
        }
    }

    ColumnLayout {
        id: workspaceCol
        visible: root.vertical
        anchors.centerIn: parent
        spacing: 2

        Repeater {
            model: root.specialWorkspaces

            SpecialWsButton {
                required property var modelData
                wsName: modelData.name
                wsWindows: modelData.lastIpcObject.windows
                isActive: modelData.name === root.activeSpecialName
            }
        }
    }

    component SpecialWsButton: Rectangle {
        id: wsButton
        property string wsName: ""
        property int wsWindows: 0
        property bool isActive: false
        property string shortName: wsName.replace("special:", "")
        property string icon: CF.SpecialWorkspaceUtils.getIcon(wsName)
        property bool isIconText: icon.length === 1

        implicitWidth: 26
        implicitHeight: 26
        radius: Appearance.rounding.full
        color: isActive ? Appearance.colors.colPrimary : (wsButtonArea.containsMouse ? Appearance.colors.colLayer1Hover : "transparent")

        Behavior on color {
            animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
        }

        Loader {
            anchors.centerIn: parent
            sourceComponent: wsButton.isIconText ? letterComp : iconComp
        }

        Component {
            id: iconComp
            MaterialSymbol {
                text: wsButton.icon
                fill: wsButton.isActive ? 1 : 0
                iconSize: 18
                color: wsButton.isActive ? Appearance.m3colors.m3onPrimary : Appearance.m3colors.m3onSurface
            }
        }

        Component {
            id: letterComp
            StyledText {
                text: wsButton.icon
                font.pixelSize: Appearance.font.pixelSize.small
                font.weight: 600
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                color: wsButton.isActive ? Appearance.m3colors.m3onPrimary : Appearance.m3colors.m3onSurface
            }
        }

        // Badge for window count
        Rectangle {
            visible: wsButton.wsWindows > 1 && !wsButton.isActive
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.rightMargin: -2
            anchors.topMargin: -2
            width: 12
            height: 12
            radius: 6
            color: Appearance.m3colors.m3tertiary

            StyledText {
                anchors.centerIn: parent
                text: wsButton.wsWindows
                font.pixelSize: 8
                color: Appearance.m3colors.m3onTertiary
            }
        }

        MouseArea {
            id: wsButtonArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: Hyprland.dispatch(`togglespecialworkspace ${wsButton.shortName}`)
        }

    }
}

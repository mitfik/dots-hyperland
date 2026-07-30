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
        property bool hasWindows: wsWindows > 0
        property string shortName: wsName.replace("special:", "")
        property string icon: CF.SpecialWorkspaceUtils.getIcon(wsName)
        property bool isIconText: icon.length === 1
        // Dim the empty ones instead of showing a window count
        property color colContent: isActive ? Appearance.m3colors.m3onPrimary : hasWindows ? Appearance.m3colors.m3onSurface : ColorUtils.transparentize(Appearance.m3colors.m3onSurface, 0.55)

        implicitWidth: 26
        implicitHeight: 26
        radius: Appearance.rounding.full
        color: isActive ? Appearance.colors.colPrimary : (wsButtonArea.containsMouse ? Appearance.colors.colLayer1Hover : hasWindows ? ColorUtils.transparentize(Appearance.colors.colLayer1Hover, 0.5) : "transparent")

        Behavior on colContent {
            animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
        }

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
                color: wsButton.colContent
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
                color: wsButton.colContent
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

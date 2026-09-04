import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Layouts

/*
 * Pending system updates. Hidden while the system is up to date, so the bar
 * only grows an icon when there is something to do about it.
 */
Item {
    id: root
    property bool vertical: false
    readonly property bool showCount: Config.options.bar.indicators.updates.showCount
    property color colText: Updates.updateStronglyAdvised ? Appearance.colors.colError : Appearance.colors.colOnLayer1

    implicitWidth: layout.implicitWidth
    implicitHeight: root.vertical ? layout.implicitHeight : Appearance.sizes.barHeight

    Behavior on colText {
        animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
    }

    GridLayout {
        id: layout
        anchors.centerIn: parent
        columns: root.vertical ? 1 : 2
        columnSpacing: 4
        rowSpacing: 0

        MaterialSymbol {
            Layout.alignment: Qt.AlignHCenter
            text: Updates.checking ? "sync" : "system_update_alt"
            iconSize: Appearance.font.pixelSize.larger
            color: root.colText
        }

        StyledText {
            Layout.alignment: Qt.AlignHCenter
            visible: root.showCount && !Updates.checking
            font.pixelSize: Appearance.font.pixelSize.small
            font.weight: Updates.updateAdvised ? Font.DemiBold : Font.Normal
            color: root.colText
            text: Updates.count > 99 ? "99+" : Updates.count
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: !Config.options.bar.tooltips.clickToShow
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor

        // Left click walks straight into the upgrade, right click re-checks
        // without waiting for the daily timer
        onPressed: event => {
            if (event.button === Qt.LeftButton) Updates.update();
            else if (event.button === Qt.RightButton) Updates.refresh();
        }

        UpdatesPopup {
            hoverTarget: mouseArea
        }
    }
}

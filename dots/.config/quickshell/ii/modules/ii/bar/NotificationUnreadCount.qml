import QtQuick
import qs.services
import qs.modules.common
import qs.modules.common.widgets

MaterialSymbol {
    id: root
    readonly property bool showUnreadCount: Config.options.bar.indicators.notifications.showUnreadCount
    readonly property bool hasUnread: Notifications.unread > 0
    text: Notifications.silent ? "notifications_paused" : (root.hasUnread ? "notifications_active" : "notifications")
    iconSize: Appearance.font.pixelSize.larger
    // Unread notifications deserve attention even when the sidebar button isn't toggled
    color: root.hasUnread ? Appearance.colors.colError : rightSidebarButton.colText

    // Room for the badge to sit next to the bell rather than on top of it. The enclosing
    // Revealer clips to these implicit sizes, so the padding is what buys the space.
    readonly property real badgeRoom: (root.showUnreadCount && root.hasUnread) ? 5 : 0
    leftPadding: badgeRoom
    rightPadding: badgeRoom
    topPadding: badgeRoom
    bottomPadding: badgeRoom

    Behavior on color {
        animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
    }

    // Blink a few times whenever something new arrives, so a notification that
    // came and went is still noticeable without opening the sidebar
    Connections {
        target: Notifications
        function onUnreadChanged() {
            if (root.hasUnread) attentionBlink.restart();
        }
    }

    Rectangle {
        id: notifPing
        visible: root.hasUnread
        anchors {
            right: parent.right
            top: parent.top
            rightMargin: root.showUnreadCount ? 0 : 1
            topMargin: root.showUnreadCount ? 0 : 3
        }
        radius: Appearance.rounding.full
        color: Appearance.colors.colError
        z: 1

        implicitHeight: root.showUnreadCount ? Math.max(notificationCounterText.implicitWidth, notificationCounterText.implicitHeight) + 2 : 8
        implicitWidth: implicitHeight

        SequentialAnimation {
            id: attentionBlink
            loops: 3
            NumberAnimation { target: notifPing; property: "opacity"; to: 0.25; duration: 250; easing.type: Easing.InOutQuad }
            NumberAnimation { target: notifPing; property: "opacity"; to: 1.0; duration: 250; easing.type: Easing.InOutQuad }
            onStopped: notifPing.opacity = 1
        }

        StyledText {
            id: notificationCounterText
            visible: root.showUnreadCount
            anchors.centerIn: parent
            font.pixelSize: Appearance.font.pixelSize.smallest
            font.weight: Font.DemiBold
            color: Appearance.colors.colOnError
            text: Notifications.unread > 99 ? "99+" : Notifications.unread
        }
    }
}

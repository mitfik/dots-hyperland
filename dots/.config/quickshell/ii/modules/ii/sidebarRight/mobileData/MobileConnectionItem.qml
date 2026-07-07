import qs
import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Layouts

DialogListItem {
    id: root
    required property var connection // { uuid, name, active }

    readonly property bool isConnecting: MobileData.connectTargetUuid === connection?.uuid
    active: (connection?.active || isConnecting) ?? false
    enabled: !isConnecting

    onClicked: {
        if (connection?.active)
            MobileData.disconnectActive();
        else
            MobileData.connectProfile(connection?.uuid ?? "");
    }

    contentItem: RowLayout {
        anchors {
            fill: parent
            topMargin: root.verticalPadding
            bottomMargin: root.verticalPadding
            leftMargin: root.horizontalPadding
            rightMargin: root.horizontalPadding
        }
        spacing: 10

        MaterialSymbol {
            iconSize: Appearance.font.pixelSize.larger
            text: "sim_card"
            color: Appearance.colors.colOnSurfaceVariant
        }
        StyledText {
            Layout.fillWidth: true
            color: Appearance.colors.colOnSurfaceVariant
            elide: Text.ElideRight
            text: root.connection?.name ?? Translation.tr("Unknown")
            textFormat: Text.PlainText
        }
        MaterialSymbol {
            visible: (root.connection?.active || root.isConnecting) ?? false
            text: root.isConnecting ? "settings_ethernet" : "check"
            iconSize: Appearance.font.pixelSize.larger
            color: Appearance.colors.colOnSurfaceVariant
        }
    }
}

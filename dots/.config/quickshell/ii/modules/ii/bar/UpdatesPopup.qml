import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Layouts

StyledPopup {
    id: root
    readonly property int previewCount: 8
    readonly property string packageList: {
        const packages = Updates.repoPackages.concat(Updates.aurPackages);
        if (packages.length === 0) return Translation.tr("Everything is up to date");
        let list = packages.slice(0, root.previewCount).map(name => `  • ${name}`).join("\n");
        if (packages.length > root.previewCount)
            list += `\n  ${Translation.tr("... and %1 more").arg(packages.length - root.previewCount)}`;
        return list;
    }

    ColumnLayout {
        anchors.centerIn: parent
        spacing: 4

        StyledPopupHeaderRow {
            icon: "system_update_alt"
            label: Translation.tr("%1 updates available").arg(Updates.count)
        }

        StyledPopupValueRow {
            icon: "package_2"
            label: Translation.tr("Official repositories:")
            value: `${Updates.repoCount}`
        }

        StyledPopupValueRow {
            icon: "communities"
            label: Translation.tr("AUR:")
            value: Updates.aurAvailable ? `${Updates.aurCount}` : Translation.tr("no helper")
        }

        StyledPopupValueRow {
            icon: "schedule"
            label: Translation.tr("Last checked:")
            value: Updates.checking ? Translation.tr("checking...") : (Updates.checkedAtLeastOnce ? Qt.formatDateTime(Updates.lastCheck, "ddd HH:mm") : Translation.tr("never"))
        }

        StyledText {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignLeft
            wrapMode: Text.Wrap
            color: Appearance.colors.colOnSurfaceVariant
            text: root.packageList
        }

        StyledText {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignLeft
            font.pixelSize: Appearance.font.pixelSize.smaller
            color: Appearance.colors.colSubtext
            text: Translation.tr("Click to update • Right-click to check again")
        }
    }
}

import QtQuick
import Quickshell
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets

QuickToggleModel {
    name: Translation.tr("Monitors")
    statusText: Translation.tr("%1 monitor(s)").arg(MonitorManager.monitorCount)

    toggled: MonitorManager.monitorCount > 1
    icon: "monitor"

    mainAction: () => {}
    hasMenu: true

    tooltipText: Translation.tr("Monitor Settings")
}

import QtQuick
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets

QuickToggleModel {
    name: Translation.tr("Mobile data")
    statusText: MobileData.statusText
    tooltipText: Translation.tr("Mobile data: %1 | Right-click for details").arg(
        MobileData.enabled ? (MobileData.statusText || Translation.tr("On")) : Translation.tr("Off"))
    icon: MobileData.materialSymbol

    available: MobileData.available
    toggled: MobileData.enabled
    mainAction: () => MobileData.toggle()
    hasMenu: true
}

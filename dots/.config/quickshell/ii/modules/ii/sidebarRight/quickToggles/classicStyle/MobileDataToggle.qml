import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.modules.ii.sidebarRight.quickToggles
import qs
import QtQuick
import Quickshell

QuickToggleButton {
    visible: MobileData.available
    toggled: MobileData.enabled
    buttonIcon: MobileData.materialSymbol
    onClicked: MobileData.toggle()
    StyledToolTip {
        text: Translation.tr("Mobile data: %1 | Right-click for details").arg(
            MobileData.enabled ? (MobileData.statusText || Translation.tr("On")) : Translation.tr("Off"))
    }
}

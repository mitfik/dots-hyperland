import QtQuick
import qs.modules.common
import qs.modules.common.widgets
import qs.services

QuickToggleButton {
    id: monitorButton
    toggled: MonitorManager.monitorCount > 1
    buttonIcon: "monitor"

    signal requestMonitorDialog()

    onClicked: {
        monitorButton.requestMonitorDialog()
    }

    StyledToolTip {
        text: Translation.tr("Monitor Settings")
    }
}

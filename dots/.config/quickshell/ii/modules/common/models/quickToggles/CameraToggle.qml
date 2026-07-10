import QtQuick
import Quickshell
import Quickshell.Io
import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets

QuickToggleModel {
    id: root
    name: Translation.tr("Camera")
    statusText: toggled ? Translation.tr("On") : Translation.tr("Off")

    toggled: false
    icon: toggled ? "videocam" : "videocam_off"

    mainAction: () => {
        if (root.toggled) {
            root.toggled = false
            Quickshell.execDetached(["systemctl", "--user", "stop", "camera-bridge.service"])
        } else {
            root.toggled = true
            Quickshell.execDetached(["systemctl", "--user", "start", "camera-bridge.service"])
        }
    }

    // Reflect the actual bridge state (also catches external camera-on/off & crashes)
    Process {
        id: fetchActiveState
        running: true
        command: ["systemctl", "--user", "is-active", "camera-bridge.service"]
        stdout: StdioCollector {
            id: stateCollector
            onStreamFinished: {
                root.toggled = stateCollector.text.trim() === "active"
            }
        }
    }

    Timer {
        interval: 3000
        running: GlobalStates.sidebarRightOpen
        repeat: true
        triggeredOnStart: true
        onTriggered: fetchActiveState.running = true
    }

    tooltipText: Translation.tr("Webcam bridge (libcamera → /dev/video50)")
}

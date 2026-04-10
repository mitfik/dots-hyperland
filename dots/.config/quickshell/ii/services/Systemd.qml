pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.common

Singleton {
    id: root

    // Map of service name -> { active: bool, loading: bool }
    property var serviceStates: ({})
    // Bumped to trigger re-evaluation of bindings that read serviceStates
    property int stateRevision: 0

    function getState(serviceName) {
        void root.stateRevision;
        return root.serviceStates[serviceName] || { active: false, loading: false };
    }

    function toggle(serviceName) {
        const state = getState(serviceName);
        if (state.loading) return;
        const action = state.active ? "stop" : "start";
        setLoading(serviceName, true);
        toggleProc.command = ["pkexec", "systemctl", action, serviceName];
        toggleProc.running = true;
    }

    function refresh() {
        const services = Config.options.systemd.services;
        if (services.length === 0) return;
        refreshProc.running = false;
        refreshProc.command = ["systemctl", "is-active", ...services];
        refreshProc.running = true;
    }

    function setLoading(serviceName, loading) {
        const states = root.serviceStates;
        if (!states[serviceName]) states[serviceName] = { active: false, loading: false };
        states[serviceName].loading = loading;
        root.serviceStates = states;
        root.stateRevision++;
    }

    // Poll service status periodically
    Timer {
        interval: 5000
        running: Config.ready && Config.options.systemd.services.length > 0
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    // Re-check when service list changes
    Connections {
        target: Config.options.systemd
        function onServicesChanged() {
            root.refresh();
        }
    }

    // Check status of all configured services
    Process {
        id: refreshProc
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().split("\n");
                const services = Config.options.systemd.services;
                const states = {};
                for (let i = 0; i < services.length; i++) {
                    const status = (i < lines.length) ? lines[i].trim() : "unknown";
                    states[services[i]] = {
                        active: status === "active",
                        loading: false,
                    };
                }
                root.serviceStates = states;
                root.stateRevision++;
            }
        }
    }

    // Toggle a service (start/stop via pkexec)
    Process {
        id: toggleProc
        onExited: (exitCode, exitStatus) => {
            root.refresh();
        }
    }
}

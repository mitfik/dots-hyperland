pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.common

Singleton {
    id: root

    property var serviceStates: ({})
    property int stateRevision: 0

    function getState(serviceName) {
        void root.stateRevision;
        return root.serviceStates[serviceName] || { active: false, loading: false, user: false };
    }

    function toggle(serviceName) {
        const state = getState(serviceName);
        if (state.loading) return;
        const action = state.active ? "stop" : "start";
        setLoading(serviceName, true);
        if (state.user) {
            toggleProc.command = ["systemctl", "--user", action, serviceName];
        } else {
            toggleProc.command = ["pkexec", "systemctl", action, serviceName];
        }
        toggleProc.running = true;
    }

    function refresh() {
        const services = Config.options.systemd.services;
        if (services.length === 0) return;
        root._pendingRefreshes = 2;
        refreshSystemProc.running = false;
        refreshSystemProc.command = ["systemctl", "is-active", ...services];
        refreshSystemProc.running = true;
        refreshUserProc.running = false;
        refreshUserProc.command = ["systemctl", "--user", "is-active", ...services];
        refreshUserProc.running = true;
    }

    function setLoading(serviceName, loading) {
        const states = root.serviceStates;
        if (!states[serviceName]) states[serviceName] = { active: false, loading: false, user: false };
        states[serviceName].loading = loading;
        root.serviceStates = states;
        root.stateRevision++;
    }

    function _mergeResults() {
        const services = Config.options.systemd.services;
        const states = {};
        for (let i = 0; i < services.length; i++) {
            const name = services[i];
            const sysActive = (root._systemResults[name] || "") === "active";
            const usrActive = (root._userResults[name] || "") === "active";
            states[name] = {
                active: sysActive || usrActive,
                loading: false,
                user: usrActive && !sysActive,
            };
        }
        root.serviceStates = states;
        root.stateRevision++;
    }

    property var _systemResults: ({})
    property var _userResults: ({})
    property int _pendingRefreshes: 0

    Timer {
        interval: 5000
        running: Config.ready && Config.options.systemd.services.length > 0
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    Connections {
        target: Config.options.systemd
        function onServicesChanged() {
            root.refresh();
        }
    }

    Process {
        id: refreshSystemProc
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().split("\n");
                const services = Config.options.systemd.services;
                const results = {};
                for (let i = 0; i < services.length; i++) {
                    results[services[i]] = (i < lines.length) ? lines[i].trim() : "unknown";
                }
                root._systemResults = results;
                root._pendingRefreshes--;
                if (root._pendingRefreshes <= 0) root._mergeResults();
            }
        }
    }

    Process {
        id: refreshUserProc
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().split("\n");
                const services = Config.options.systemd.services;
                const results = {};
                for (let i = 0; i < services.length; i++) {
                    results[services[i]] = (i < lines.length) ? lines[i].trim() : "unknown";
                }
                root._userResults = results;
                root._pendingRefreshes--;
                if (root._pendingRefreshes <= 0) root._mergeResults();
            }
        }
    }

    Process {
        id: toggleProc
        onExited: (exitCode, exitStatus) => {
            root.refresh();
        }
    }
}

pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

/**
 * Manages monitor configuration via hyprctl.
 * Provides monitor list, scale/position/mirror control, and mode switching.
 */
Singleton {
    id: root

    property var monitors: HyprlandData.monitors
    property int monitorCount: monitors.length

    function refresh() {
        HyprlandData.updateMonitors();
    }

    function setScale(monitorName: string, scale: real) {
        const mon = getMonitor(monitorName);
        if (!mon) return;
        const mode = `${mon.width}x${mon.height}@${mon.refreshRate.toFixed(5)}`;
        const pos = `${mon.x}x${mon.y}`;
        Quickshell.execDetached(["hyprctl", "keyword", "monitor", `${monitorName},${mode},${pos},${scale}`]);
        refreshDelayed();
    }

    function setPosition(monitorName: string, x: int, y: int) {
        const mon = getMonitor(monitorName);
        if (!mon) return;
        const mode = `${mon.width}x${mon.height}@${mon.refreshRate.toFixed(5)}`;
        Quickshell.execDetached(["hyprctl", "keyword", "monitor", `${monitorName},${mode},${x}x${y},${mon.scale}`]);
        refreshDelayed();
    }

    function setMode(monitorName: string, mode: string) {
        const mon = getMonitor(monitorName);
        if (!mon) return;
        const pos = `${mon.x}x${mon.y}`;
        Quickshell.execDetached(["hyprctl", "keyword", "monitor", `${monitorName},${mode},${pos},${mon.scale}`]);
        refreshDelayed();
    }

    function mirrorMonitor(monitorName: string, targetName: string) {
        Quickshell.execDetached(["hyprctl", "keyword", "monitor", `${monitorName},preferred,auto,1,mirror,${targetName}`]);
        refreshDelayed();
    }

    function unmirrorMonitor(monitorName: string) {
        const mon = getMonitor(monitorName);
        if (!mon) return;
        Quickshell.execDetached(["hyprctl", "keyword", "monitor", `${monitorName},preferred,auto,${mon.scale}`]);
        refreshDelayed();
    }

    function disableMonitor(monitorName: string) {
        Quickshell.execDetached(["hyprctl", "keyword", "monitor", `${monitorName},disable`]);
        refreshDelayed();
    }

    function enableMonitor(monitorName: string) {
        Quickshell.execDetached(["hyprctl", "keyword", "monitor", `${monitorName},preferred,auto,1`]);
        refreshDelayed();
    }

    function setPositionRightOf(monitorName: string, targetName: string) {
        const target = getMonitor(targetName);
        if (!target) return;
        const newX = target.x + Math.round(target.width / target.scale);
        setPosition(monitorName, newX, target.y);
    }

    function setPositionLeftOf(monitorName: string, targetName: string) {
        const mon = getMonitor(monitorName);
        const target = getMonitor(targetName);
        if (!mon || !target) return;
        const newX = target.x - Math.round(mon.width / mon.scale);
        setPosition(monitorName, newX, target.y);
    }

    function setPositionAbove(monitorName: string, targetName: string) {
        const mon = getMonitor(monitorName);
        const target = getMonitor(targetName);
        if (!mon || !target) return;
        const newY = target.y - Math.round(mon.height / mon.scale);
        setPosition(monitorName, target.x, newY);
    }

    function setPositionBelow(monitorName: string, targetName: string) {
        const target = getMonitor(targetName);
        if (!target) return;
        const newY = target.y + Math.round(target.height / target.scale);
        setPosition(monitorName, target.x, newY);
    }

    function getMonitor(name: string) {
        for (let i = 0; i < root.monitors.length; i++) {
            if (root.monitors[i].name === name) return root.monitors[i];
        }
        return null;
    }

    function parseAvailableModes(mon) {
        if (!mon || !mon.availableModes) return [];
        const seen = new Set();
        const modes = [];
        for (const modeStr of mon.availableModes) {
            if (!seen.has(modeStr)) {
                seen.add(modeStr);
                modes.push(modeStr);
            }
        }
        return modes;
    }

    function currentModeString(mon) {
        if (!mon) return "";
        return `${mon.width}x${mon.height}@${mon.refreshRate.toFixed(2)}Hz`;
    }

    Timer {
        id: refreshTimer
        interval: 300
        repeat: false
        onTriggered: root.refresh()
    }

    function refreshDelayed() {
        refreshTimer.restart();
    }
}

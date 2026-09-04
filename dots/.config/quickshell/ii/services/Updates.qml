pragma Singleton

import qs.modules.common
import qs.modules.common.functions
import QtQuick
import Quickshell
import Quickshell.Io

/*
 * System updates service. Currently only supports Arch.
 *
 * Official repositories are read with checkupdates (pacman-contrib), the AUR
 * with whatever helper is installed. The two are counted separately because a
 * rolling release usually wants them applied together, but knowing which side
 * moved tells you how risky the upgrade is.
 */
Singleton {
    id: root

    property bool available: false
    property string aurHelper: ""
    readonly property bool aurAvailable: root.aurHelper !== ""
    readonly property bool checking: checkRepoProc.running || checkAurProc.running

    property int repoCount: 0
    property int aurCount: 0
    readonly property int count: root.repoCount + root.aurCount

    property list<string> repoPackages: []
    property list<string> aurPackages: []

    property date lastCheck: new Date(0)
    readonly property bool checkedAtLeastOnce: root.lastCheck.getTime() > 0

    readonly property bool updatesAvailable: available && count > 0
    readonly property bool updateAdvised: available && count > Config.options.updates.adviseUpdateThreshold
    readonly property bool updateStronglyAdvised: available && count > Config.options.updates.stronglyAdviseUpdateThreshold

    // Package lines look like "name 1.0-1 -> 1.1-1"; only the name is interesting here
    function parsePackages(text) {
        return text.trim().split("\n").filter(line => line.trim().length > 0).map(line => line.trim().split(/\s+/)[0]);
    }

    function load() {}

    function refresh() {
        if (!available) return;
        print("[Updates] Checking for system updates")
        checkRepoProc.running = true;
        if (Config.options.updates.checkAur && root.aurAvailable) checkAurProc.running = true;
    }

    // Starts the interactive upgrade in a terminal. Deliberately not automated:
    // a rolling release upgrade wants a human watching the pacman output.
    function update() {
        Quickshell.execDetached(["bash", "-c", Config.options.apps.update]);
        recheckAfterUpdate.restart();
    }

    // The upgrade runs in a terminal we don't own, so there is no completion to
    // wait for; look again a few minutes later to clear (or keep) the indicator
    Timer {
        id: recheckAfterUpdate
        interval: 5 * 60 * 1000
        repeat: false
        onTriggered: root.refresh()
    }

    Timer {
        interval: Config.options.updates.checkInterval * 60 * 1000
        repeat: true
        running: Config.ready && Config.options.updates.enableCheck
        onTriggered: {
            print("[Updates] Periodic update check due")
            root.refresh();
        }
    }

    Process {
        id: checkAvailabilityProc
        running: Config.ready && Config.options.updates.enableCheck
        command: ["which", "checkupdates"]
        onExited: (exitCode, exitStatus) => {
            root.available = (exitCode === 0);
            if (root.available) detectAurHelperProc.running = true;
        }
    }

    Process {
        id: detectAurHelperProc
        command: ["bash", "-c", `for helper in ${Config.options.updates.aurHelper} paru yay pikaur trizen; do command -v "$helper" >/dev/null 2>&1 && { echo "$helper"; break; }; done`]
        stdout: StdioCollector {
            onStreamFinished: {
                root.aurHelper = text.trim();
            }
        }
        onExited: root.refresh()
    }

    Process {
        id: checkRepoProc
        // checkupdates exits non-zero when there is nothing to update
        command: ["bash", "-c", "checkupdates || true"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.repoPackages = root.parsePackages(text);
                root.repoCount = root.repoPackages.length;
                root.lastCheck = new Date();
            }
        }
    }

    Process {
        id: checkAurProc
        // Same story: the helper reports "nothing to do" with a failing exit code
        command: ["bash", "-c", `${root.aurHelper} -Qua 2>/dev/null || true`]
        stdout: StdioCollector {
            onStreamFinished: {
                root.aurPackages = root.parsePackages(text);
                root.aurCount = root.aurPackages.length;
                root.lastCheck = new Date();
            }
        }
    }
}

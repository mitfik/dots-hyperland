pragma Singleton
pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import QtQuick

/**
 * Mobile broadband (WWAN / cellular) service.
 * Connection profiles and up/down are handled with nmcli; live modem status
 * (operator, signal quality, access technology, roaming) comes from mmcli.
 */
Singleton {
    id: root

    // Whether any cellular modem / gsm connection profile is present. When false
    // the UI hides the whole mobile broadband section, so machines without a
    // modem see no change.
    property bool available: false
    property bool enabled: false // WWAN radio enabled (nmcli radio wwan)
    property bool connected: false
    property bool connecting: connectProc.running || disconnectProc.running || root.deviceConnecting

    // Live modem status (mmcli)
    property string operatorName: ""
    property string accessTech: "" // Already human-friendly, e.g. "LTE", "5G"
    property int signalQuality: 0 // 0-100
    property bool roaming: false

    // gsm connection profiles: [{ uuid, name, active }, ...]
    property var connections: []
    property string activeUuid: ""
    property string activeName: ""
    property string device: ""
    property bool deviceConnecting: false

    // uuid currently being connected to (for disabling its row while in progress)
    property string connectTargetUuid: ""

    readonly property string statusText: {
        if (!available)
            return "";
        if (!enabled)
            return qsTr("Off");
        if (connecting)
            return qsTr("Connecting…");
        if (!connected)
            return qsTr("Not connected");
        let parts = [];
        if (operatorName.length > 0)
            parts.push(operatorName);
        if (accessTech.length > 0)
            parts.push(accessTech);
        if (roaming)
            parts.push(qsTr("Roaming"));
        return parts.length > 0 ? parts.join(" • ") : qsTr("Connected");
    }

    readonly property string materialSymbol: {
        if (!enabled)
            return "signal_cellular_off";
        if (!connected)
            return "signal_cellular_alt"; // radio on, searching / not connected
        return signalQuality > 80 ? "signal_cellular_4_bar" :
            signalQuality > 60 ? "signal_cellular_3_bar" :
            signalQuality > 40 ? "signal_cellular_2_bar" :
            signalQuality > 20 ? "signal_cellular_1_bar" :
            "signal_cellular_0_bar";
    }

    function accessTechLabel(techs) {
        // techs: array from mmcli, most-capable first (e.g. ["5gnr","lte"])
        const tech = (techs && techs.length > 0) ? techs[0].toLowerCase() : "";
        if (tech.includes("5g"))
            return "5G";
        if (tech.includes("lte"))
            return "LTE";
        if (tech.includes("umts") || tech.includes("hspa") || tech.includes("hsupa") || tech.includes("hsdpa"))
            return "3G";
        if (tech.includes("edge") || tech.includes("gprs") || tech.includes("gsm"))
            return "2G";
        return tech.toUpperCase();
    }

    // Control
    function setEnabled(on): void {
        toggleProc.exec(["nmcli", "radio", "wwan", on ? "on" : "off"]);
    }

    function toggle(): void {
        setEnabled(!enabled);
    }

    function connectProfile(uuid): void {
        if (!uuid || uuid.length === 0)
            return;
        root.connectTargetUuid = uuid;
        connectProc.exec({
            "environment": { "UUID": uuid },
            "command": ["bash", "-c", 'nmcli radio wwan on; nmcli connection up uuid "$UUID"']
        });
    }

    function disconnectActive(): void {
        if (root.activeUuid.length > 0) {
            disconnectProc.exec({
                "environment": { "UUID": root.activeUuid },
                "command": ["bash", "-c", 'nmcli connection down uuid "$UUID"']
            });
        } else if (root.device.length > 0) {
            disconnectProc.exec({
                "environment": { "DEV": root.device },
                "command": ["bash", "-c", 'nmcli device disconnect "$DEV"']
            });
        }
    }

    function update(): void {
        nmcliProc.running = true;
        modemProc.running = true;
    }

    Process {
        id: connectProc
        environment: ({ LANG: "C", LC_ALL: "C" })
        onExited: {
            root.connectTargetUuid = "";
            root.update();
        }
    }

    Process {
        id: disconnectProc
        environment: ({ LANG: "C", LC_ALL: "C" })
        onExited: root.update()
    }

    Process {
        id: toggleProc
        environment: ({ LANG: "C", LC_ALL: "C" })
        onExited: root.update()
    }

    // React to any NetworkManager change; coalesce bursts with a short timer.
    Process {
        id: subscriber
        running: true
        command: ["nmcli", "monitor"]
        stdout: SplitParser {
            onRead: debounce.restart()
        }
    }

    Timer {
        id: debounce
        interval: 300
        onTriggered: root.update()
    }

    // Periodically refresh live signal/operator while a modem exists.
    Timer {
        interval: 15000
        running: root.available
        repeat: true
        onTriggered: modemProc.running = true
    }

    // nmcli: radio state, gsm device state, gsm connection profiles.
    // NAME is queried last so profile names containing ':' don't break parsing.
    Process {
        id: nmcliProc
        running: true
        environment: ({ LANG: "C", LC_ALL: "C" })
        command: ["bash", "-c",
            'echo "WWAN:$(nmcli radio wwan 2>/dev/null)"; ' +
            'nmcli -t -f TYPE,STATE,DEVICE device 2>/dev/null | grep "^gsm:" | sed "s/^gsm:/DEV:/"; ' +
            'nmcli -t -f UUID,TYPE,ACTIVE,NAME connection show 2>/dev/null | grep ":gsm:" | sed "s/^/CONN:/"']
        stdout: StdioCollector {
            onStreamFinished: {
                let hasDevice = false;
                let deviceState = "";
                let deviceName = "";
                let radioEnabled = false;
                const parsed = [];

                for (const rawLine of text.trim().split("\n")) {
                    if (rawLine.length === 0)
                        continue;
                    if (rawLine.startsWith("WWAN:")) {
                        radioEnabled = rawLine.slice(5).trim() === "enabled";
                    } else if (rawLine.startsWith("DEV:")) {
                        hasDevice = true;
                        const parts = rawLine.slice(4).split(":");
                        deviceState = parts[0] ?? "";
                        deviceName = parts[1] ?? "";
                    } else if (rawLine.startsWith("CONN:")) {
                        const parts = rawLine.slice(5).split(":");
                        // parts: uuid, type(gsm), active(yes/no), name...(may contain ':')
                        const uuid = parts[0] ?? "";
                        const active = (parts[2] ?? "") === "yes";
                        const name = parts.slice(3).join(":").replace(/\\:/g, ":");
                        parsed.push({ uuid, name, active });
                    }
                }

                root.available = hasDevice || parsed.length > 0;
                root.enabled = radioEnabled;
                root.device = deviceName;
                root.deviceConnecting = deviceState.includes("connecting");
                root.connected = deviceState === "connected";

                const activeConn = parsed.find(c => c.active) ?? null;
                root.activeUuid = activeConn ? activeConn.uuid : "";
                root.activeName = activeConn ? activeConn.name : "";

                // Reassign wholesale; ScriptModel keeps delegates stable by uuid.
                root.connections = parsed;
            }
        }
    }

    // mmcli: operator, signal quality, access technology, roaming state.
    Process {
        id: modemProc
        running: true
        environment: ({ LANG: "C", LC_ALL: "C" })
        command: ["mmcli", "-m", "any", "-J"]
        stdout: StdioCollector {
            onStreamFinished: {
                const raw = text.trim();
                if (raw.length === 0)
                    return; // No modem exposed to ModemManager
                try {
                    const modem = JSON.parse(raw).modem;
                    const generic = modem.generic ?? {};
                    const gpp = modem["3gpp"] ?? {};
                    root.available = true;
                    root.operatorName = (gpp["operator-name"] && gpp["operator-name"] !== "--")
                        ? gpp["operator-name"] : "";
                    root.accessTech = root.accessTechLabel(generic["access-technologies"]);
                    const sq = generic["signal-quality"];
                    root.signalQuality = sq ? parseInt(sq.value) || 0 : 0;
                    root.roaming = (gpp["registration-state"] ?? "").includes("roaming");
                } catch (e) {
                    // Malformed output; leave previous values untouched.
                }
            }
        }
    }

    Component.onCompleted: root.update()
}

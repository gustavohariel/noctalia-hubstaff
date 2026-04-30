import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root
    visible: false

    property var pluginApi: null
    property var pluginSettings: pluginApi?.pluginSettings ?? ({})

    readonly property string cliPath: pluginSettings?.cliPath ?? "/home/realgh/Hubstaff/HubstaffCLI.bin.x86_64"
    readonly property int refreshIntervalSec: pluginSettings?.refreshIntervalSec ?? 5

    property bool isRunning: false
    property string projectName: ""
    property int projectId: -1
    property string trackedToday: "0:00:00"
    property string lastError: ""
    property bool everLoaded: false

    property int _baseSeconds: 0
    property real _baseEpoch: 0
    property real _now: Date.now()

    readonly property int elapsedSeconds: {
        if (!isRunning)
            return _baseSeconds;
        const delta = Math.max(0, (_now - _baseEpoch) / 1000);
        return _baseSeconds + Math.floor(delta);
    }

    readonly property string formattedTime: everLoaded ? formatHMS(elapsedSeconds) : "—"

    function formatHMS(total) {
        if (!Number.isFinite(total) || total < 0)
            total = 0;
        const h = Math.floor(total / 3600);
        const m = Math.floor((total % 3600) / 60);
        const s = total % 60;
        const pad = n => n < 10 ? "0" + n : String(n);
        return h + ":" + pad(m) + ":" + pad(s);
    }

    function parseHMS(s) {
        const parts = String(s ?? "").split(":");
        let h = 0, m = 0, sec = 0;
        if (parts.length === 3) {
            h = parseInt(parts[0]) || 0;
            m = parseInt(parts[1]) || 0;
            sec = parseInt(parts[2]) || 0;
        } else if (parts.length === 2) {
            m = parseInt(parts[0]) || 0;
            sec = parseInt(parts[1]) || 0;
        } else if (parts.length === 1) {
            sec = parseInt(parts[0]) || 0;
        }
        return h * 3600 + m * 60 + sec;
    }

    Timer {
        id: tickTimer
        interval: 1000
        running: root.isRunning
        repeat: true
        onTriggered: root._now = Date.now()
    }

    function refresh() {
        statusProcess.running = true;
    }

    function actionStart() {
        startProcess.running = true;
    }

    function actionStop() {
        stopProcess.running = true;
    }

    Timer {
        id: pollTimer
        interval: Math.max(2, root.refreshIntervalSec) * 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    Process {
        id: statusProcess
        command: [root.cliPath, "status"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.parseStatus(this.text);
            }
        }
        stderr: StdioCollector {}
    }

    Process {
        id: stopProcess
        command: [root.cliPath, "stop"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.parseAction(this.text);
                root.refresh();
            }
        }
        stderr: StdioCollector {}
    }

    Process {
        id: startProcess
        command: [root.cliPath, "--autostart", "resume"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.parseAction(this.text);
                root.refresh();
            }
        }
        stderr: StdioCollector {}
    }

    function parseStatus(text) {
        const trimmed = String(text || "").trim();
        if (trimmed === "")
            return;
        try {
            const r = JSON.parse(trimmed);
            if (r.error) {
                root.lastError = String(r.error);
                return;
            }
            const wasRunning = root.isRunning;
            const newRunning = r.tracking === true;
            const ap = r.active_project;
            const newProjectId = ap?.id ?? -1;
            const newSec = ap ? root.parseHMS(ap.tracked_today ?? "0:00:00") : 0;
            const projected = root.elapsedSeconds;
            const stateChanged = wasRunning !== newRunning || newProjectId !== root.projectId;
            const drift = Math.abs(newSec - projected);
            const shouldAnchor = !root.everLoaded || stateChanged || !newRunning || drift > 2;

            root.isRunning = newRunning;
            if (ap) {
                root.projectId = newProjectId;
                root.projectName = ap.name ?? "";
                root.trackedToday = ap.tracked_today ?? "0:00:00";
            } else {
                root.projectId = -1;
                root.projectName = "";
                root.trackedToday = "0:00:00";
            }

            if (shouldAnchor) {
                root._baseSeconds = newSec;
                root._baseEpoch = Date.now();
                root._now = Date.now();
            }
            root.lastError = "";
            root.everLoaded = true;
        } catch (e) {
            root.lastError = "Parse error: " + String(e);
        }
    }

    function parseAction(text) {
        const trimmed = String(text || "").trim();
        if (trimmed === "")
            return;
        try {
            const r = JSON.parse(trimmed);
            if (r.error) {
                root.lastError = String(r.error);
            } else {
                root.lastError = "";
            }
        } catch (e) {
        }
    }
}

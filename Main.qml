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

    readonly property string formattedTime: trackedToday !== "" ? trackedToday : "—"

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
            root.isRunning = r.tracking === true;
            const ap = r.active_project;
            if (ap) {
                root.projectId = ap.id ?? -1;
                root.projectName = ap.name ?? "";
                root.trackedToday = ap.tracked_today ?? "0:00:00";
            } else {
                root.projectId = -1;
                root.projectName = "";
                root.trackedToday = "0:00:00";
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

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

    // The Hubstaff GUI client lives next to the CLI in the same install dir;
    // re-launching it summons the window of the existing single-instance app.
    readonly property string clientPath: cliPath.indexOf("HubstaffCLI") >= 0 ? cliPath.replace("HubstaffCLI", "HubstaffClient") : "/home/realgh/Hubstaff/HubstaffClient.bin.x86_64"

    // The CLI is the source of truth: a successful `status` response means the
    // Hubstaff daemon is up; the specific "Could not connect to timer" error
    // means it isn't. The Hubstaff GUI window is independent of all this — open
    // or closed, the widget doesn't care.
    property bool hubstaffRunning: false

    // True when the Hubstaff window is in niri's tiling layout (i.e. visible to
    // the user). Driven by `hubstaff-window.sh state`. Used by the toggle to
    // decide between "Open" (false → Open) and "Hide" (true → Hide).
    property bool windowOpen: false

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
        if (root.hubstaffRunning) {
            windowStateProcess.running = true;
        }
    }

    function actionStart() {
        startProcess.running = true;
    }

    function actionStop() {
        stopProcess.running = true;
    }

    // Shared script lives on disk so we don't have to fight QML/JS string
    // escaping for the shell pipeline. Path resolves at runtime.
    readonly property string _windowScript: Qt.resolvedUrl("hubstaff-window.sh").toString().replace("file://", "")

    function openApp() {
        openAppProcess.running = true;
        root.windowOpen = true;             // optimistic; recheck confirms
        windowStateRecheckTimer.restart();
    }

    function hideWindow() {
        hideWindowProcess.running = true;
        root.windowOpen = false;            // optimistic; recheck confirms
        windowStateRecheckTimer.restart();
    }

    function toggleWindow() {
        if (root.windowOpen)
            hideWindow();
        else
            openApp();
    }

    Process {
        id: windowStateProcess
        command: ["sh", root._windowScript, "state"]
        stdout: StdioCollector {
            onStreamFinished: {
                const s = String(this.text || "").trim();
                root.windowOpen = (s === "tiling");
            }
        }
        stderr: StdioCollector {}
    }

    Timer {
        // Re-check window state shortly after a toggle so the button label
        // catches up after niri has actually applied the move.
        id: windowStateRecheckTimer
        interval: 300
        repeat: false
        onTriggered: windowStateProcess.running = true
    }

    Process {
        id: openAppProcess
        command: ["sh", root._windowScript, "open", root.clientPath]
        stdout: StdioCollector {}
        stderr: StdioCollector {
            onStreamFinished: {
                const err = String(this.text || "").trim();
                if (err)
                    root.lastError = err;
                else
                    root.lastError = "";
            }
        }
    }

    Process {
        id: hideWindowProcess
        command: ["sh", root._windowScript, "hide"]
        stdout: StdioCollector {}
        stderr: StdioCollector {
            onStreamFinished: {
                const err = String(this.text || "").trim();
                if (err)
                    root.lastError = err;
                else
                    root.lastError = "";
            }
        }
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
        // No `--autostart` here: the widget only renders when the daemon is up,
        // so resuming on a running daemon never needs to spawn the GUI. Adding
        // --autostart was surfacing the window on every play press.
        id: startProcess
        command: [root.cliPath, "resume"]
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
                const errStr = String(r.error);
                // The CLI returns this exact string when no daemon is reachable.
                // Treat it as "Hubstaff is not running" and tear down projection.
                if (errStr.indexOf("Could not connect") >= 0) {
                    if (root.hubstaffRunning) {
                        root.hubstaffRunning = false;
                        root.isRunning = false;
                        root.everLoaded = false;
                        root.projectName = "";
                        root.projectId = -1;
                        root.trackedToday = "0:00:00";
                        root.windowOpen = false;
                    }
                    root.lastError = "";   // suppress: widget is hidden anyway
                } else {
                    root.lastError = errStr;
                }
                return;
            }
            // Successful response → daemon is up.
            const hubstaffJustCameUp = !root.hubstaffRunning;
            root.hubstaffRunning = true;
            if (hubstaffJustCameUp) {
                // First successful response after daemon came online — fetch
                // window state immediately so the toggle starts with the right label.
                windowStateProcess.running = true;
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

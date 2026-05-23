# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A Hubstaff timer widget for the [Noctalia](https://noctalia.dev) shell, shipped in two variants because Noctalia's plugin API changed incompatibly between v4 and v5:

- **`noctalia-v4/`** — the original Quickshell/QML plugin (host: Noctalia ≥ 4.4.3, < 5).
- **`noctalia-v5/`** — a single-file Luau script using v5's [scripted-widget API](https://docs.noctalia.dev/v5/bar/scripted-widgets/).

There is no build step, package manager, or test suite — Noctalia loads each variant directly. To exercise changes, install the matching variant and restart the shell:

```sh
pkill -f "qs -c noctalia-shell"   # compositor autostart respawns it
```

`*.qmlc` cache files and `noctalia-v4/settings.json` (runtime plugin settings) are gitignored.

## v4 plugin shape (manifest-driven QML)

`noctalia-v4/manifest.json` declares four QML entry points the host instantiates separately:

- **`Main.qml`** — invisible singleton holding all state and side effects (CLI subprocesses, parsed timer state, polling/tick timers). Other entry points read state via `pluginApi.mainInstance`.
- **`BarWidget.qml`** — the bar capsule. Subscribes to `mainInstance.{isRunning, formattedTime, projectName}`. Left-click toggles the panel via `pluginApi.togglePanel`; right-click opens an `NPopupContextMenu`.
- **`Panel.qml`** — popup with Start/Stop buttons, project name, today's elapsed time, and an error banner bound to `mainInstance.lastError`.
- **`Settings.qml`** — edits a deep-copied `editSettings`, then writes back via `pluginApi.pluginSettings = ...; pluginApi.saveSettings()`. Reset reads from `pluginApi.manifest.metadata.defaultSettings`.

If you add a new entry point, register it under `entryPoints` in `manifest.json`. Defaults for new settings go under `metadata.defaultSettings` and are read at runtime via `pluginSettings?.<key> ?? <fallback>`.

### Host imports (v4)

These imports resolve against the running Noctalia shell, not this repo:

- `qs.Commons` — `Style`, `Color`, `Settings` (e.g. `Style.marginM`, `Color.mPrimary`, `Settings.getBarPositionForScreen`).
- `qs.Services.UI` — `TooltipService`, `PanelService`, `BarService`.
- `qs.Widgets` — `NIcon`, `NText`, `NButton`, `NTextInput`, `NSpinBox`, `NPopupContextMenu`.

Use these instead of raw `Text`/`Rectangle`/`Button` so the plugin matches the shell's theme and scaling. `applyUiScale: false` on bar widgets is intentional — bar height is already scaled by `Style.getCapsuleHeightForScreen`.

`minNoctaliaVersion` in the manifest gates which host APIs are available; bump it if you start using a newer Noctalia surface.

## v5 widget shape (single-file Luau script)

`noctalia-v5/hubstaff.lua` is a [scripted widget](https://docs.noctalia.dev/v5/bar/scripted-widgets/) — bar-only, no popup panel, no companion Settings.qml. The script's first statement is `barWidget.define({...})`, which declares the label, icon, and settings (`cliPath`, `clientPath`, `windowScript`, `refreshIntervalSec`). Noctalia renders the settings UI automatically from that manifest.

Lifecycle:

- `update()` is invoked by the framework on every tick (~250 ms while visible). It checks `os.time() - lastPollEpoch >= refreshIntervalSec` to decide whether to fire a new poll, then calls `render()` to push display state.
- `onClick()` toggles start/stop. `onRightClick()` toggles the Hubstaff GUI window (via the helper script). There is no middle-click handler.
- All CLI calls go through `noctalia.runAsync("sh -c " .. shq(pipeline), callback)`. The callback receives `{exitCode, stdout, stderr, timedOut}` — there is no synchronous execution in v5.
- Errors surface via `noctalia.notifyError(title, body)` (no in-panel banner since there is no panel).
- The widget hides itself with `barWidget.setVisible(false)` when the daemon is down.

Settings are read at runtime with `barWidget.getConfig(key, default)`. The `expand()` helper handles `~/` prefixes since the runtime does not.

JSON parsing constraint: Luau has no JSON helper and the runtime is async-only. The script pipes `HubstaffCLI status` through `jq` to produce a tab-delimited record (`OK\t<tracking>\t<name>\t<HMS>` or `ERR\t<msg>`), which it then splits in Lua. **`jq` is therefore a runtime dependency of the v5 variant.** Touching `pollStatus` means keeping the jq filter and the Lua splitter in sync.

`noctalia-v5/hubstaff-window.sh` is a copy of the v4 helper, kept so the v5 variant is self-contained. If you fix a bug in one copy, fix it in both (or convert one into a symlink).

## State model: server poll + local projection (shared between v4 and v5)

The Hubstaff CLI is slow and only reports `tracked_today` at whole-second resolution, so display is decoupled from polling:

- Status is polled every `refreshIntervalSec` seconds (min 2). `parseStatus` reads `tracking` and `active_project.tracked_today`.
- Displayed elapsed time = `baseSeconds + (now - baseEpoch)`. The render path doesn't wait on the CLI — it just re-projects from the anchor on every tick.
- After each poll, the projection re-anchors **only** on first load, state change, when stopped, or when projection drifts more than 2 s from the server value. Re-anchoring on every poll causes visible "1s tick stalls" (see commit `67b83dc`). Preserve this guard in both variants.

Implementation differences:

- v4: `pollTimer` (Quickshell `Timer`) drives `HubstaffCLI status`; `tickTimer` (1 s) bumps `_now = Date.now()` so the QML binding for `elapsedSeconds` re-evaluates.
- v5: `update()` is the single tick; it gates polling on `lastPollEpoch` and re-projects using `os.time()` on every frame.

CLI invocations (both variants):

- `HubstaffCLI status` — reads timer state.
- `HubstaffCLI resume` — start/resume.
- `HubstaffCLI stop` — stop tracking.

(v4's `Main.qml` documents why `--autostart` is *not* passed on resume: the widget only renders when the daemon is up, so the autostart side-effect would surface the GUI window on every play press.)

All three return JSON. `lastError` is set from `r.error` when present. The plugin never bypasses or modifies what Hubstaff reports — only the supported CLI is used.

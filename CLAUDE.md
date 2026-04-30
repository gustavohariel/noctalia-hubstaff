# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A [Noctalia](https://noctalia.dev) shell plugin (Quickshell/QML). There is no build step, package manager, or test suite — Quickshell loads the QML files directly. To exercise changes, install the plugin into the Noctalia plugins folder (or symlink) and restart the shell:

```sh
pkill -f "qs -c noctalia-shell"   # compositor autostart respawns it
```

`*.qmlc` cache files and a local `settings.json` are gitignored.

## Plugin shape (manifest-driven)

`manifest.json` declares four QML entry points the host instantiates separately:

- **`Main.qml`** — invisible singleton holding all state and side effects (CLI subprocesses, parsed timer state, polling/tick timers). Other entry points read state via `pluginApi.mainInstance`.
- **`BarWidget.qml`** — the bar capsule. Subscribes to `mainInstance.{isRunning, formattedTime, projectName}`. Left-click toggles the panel via `pluginApi.togglePanel`; right-click opens an `NPopupContextMenu`.
- **`Panel.qml`** — popup with Start/Stop buttons, project name, today's elapsed time, and an error banner bound to `mainInstance.lastError`.
- **`Settings.qml`** — edits a deep-copied `editSettings`, then writes back via `pluginApi.pluginSettings = ...; pluginApi.saveSettings()`. Reset reads from `pluginApi.manifest.metadata.defaultSettings`.

If you add a new entry point, register it under `entryPoints` in `manifest.json`. Defaults for new settings go under `metadata.defaultSettings` and are read at runtime via `pluginSettings?.<key> ?? <fallback>`.

## Host imports

These imports resolve against the running Noctalia shell, not this repo:

- `qs.Commons` — `Style`, `Color`, `Settings` (e.g. `Style.marginM`, `Color.mPrimary`, `Settings.getBarPositionForScreen`).
- `qs.Services.UI` — `TooltipService`, `PanelService`, `BarService`.
- `qs.Widgets` — `NIcon`, `NText`, `NButton`, `NTextInput`, `NSpinBox`, `NPopupContextMenu`.

Use these instead of raw `Text`/`Rectangle`/`Button` so the plugin matches the shell's theme and scaling. `applyUiScale: false` on bar widgets is intentional — bar height is already scaled by `Style.getCapsuleHeightForScreen`.

`minNoctaliaVersion` in the manifest gates which host APIs are available; bump it if you start using a newer Noctalia surface.

## State model: server poll + local projection

The Hubstaff CLI is slow and only reports `tracked_today` at whole-second resolution, so `Main.qml` decouples display from polling:

- `pollTimer` runs `HubstaffCLI status` every `refreshIntervalSec` seconds (min 2). `parseStatus` reads `tracking` and `active_project.tracked_today` from the JSON.
- `tickTimer` fires once per second while `isRunning` and just bumps `_now = Date.now()`.
- `elapsedSeconds` = `_baseSeconds + floor((_now - _baseEpoch) / 1000)`. The bar/panel bind to `formattedTime`, which derives from this — so the display ticks live without waiting on the CLI.
- After each poll, the projection re-anchors **only** on first load, state change, when stopped, or when projection drifts more than 2 s from the server value. Re-anchoring on every poll causes visible "1s tick stalls" (see commit `67b83dc`). Preserve this guard if you touch `parseStatus`.

CLI invocations:

- `HubstaffCLI status` — reads timer state.
- `HubstaffCLI --autostart resume` — start/resume; also launches the Hubstaff helper if it isn't running.
- `HubstaffCLI stop` — stop tracking.

All three return JSON. `parseStatus` / `parseAction` set `lastError` from `r.error` when present; failures to parse set `lastError = "Parse error: ..."`. The plugin never bypasses or modifies what Hubstaff reports — only the supported CLI is used.

# noctalia-hubstaff

A [Noctalia](https://noctalia.dev) bar plugin that surfaces the running [Hubstaff](https://hubstaff.com) timer and exposes Start/Stop controls in your top bar — covering for the fact that the official Hubstaff Linux client's tray icon doesn't render on Wayland.

## Features (v0.1)

- Bar capsule with play/pause icon and today's tracked time (`H:MM:SS`).
- Click → popup with Start / Stop buttons.
- Right-click → quick context menu (Refresh, Stop).
- Configurable poll interval and CLI path.

## Requirements

- Noctalia ≥ 4.4.3
- The official Hubstaff Linux client installed; the plugin shells out to `HubstaffCLI.bin.x86_64` (default path: `/home/<you>/Hubstaff/HubstaffCLI.bin.x86_64`).

## Install

Clone into your Noctalia plugins folder (or symlink from elsewhere):

```sh
git clone https://github.com/realgh/noctalia-hubstaff ~/.config/noctalia/plugins/hubstaff
```

Enable in `~/.config/noctalia/plugins.json` under `states`:

```json
"hubstaff": { "enabled": true, "sourceUrl": "https://github.com/realgh/noctalia-hubstaff" }
```

Add to your bar in `~/.config/noctalia/settings.json` (under `bar.widgets.right`, `.center`, or `.left`):

```json
{ "id": "plugin:hubstaff" }
```

Restart Quickshell:

```sh
pkill -f "qs -c noctalia-shell"
```

Niri/your compositor's autostart should respawn it.

## Settings

- **CLI path** — full path to `HubstaffCLI.bin.x86_64`. Default: `/home/realgh/Hubstaff/HubstaffCLI.bin.x86_64`.
- **Refresh interval (seconds)** — how often to poll for timer state. Default: `5`.

## Notes

- The plugin only controls Hubstaff via its supported CLI; it does not bypass any tracking, modify activity data, or alter how Hubstaff reports work to your team.
- "Start" calls `HubstaffCLI resume --autostart`, which resumes the last active project (and launches the Hubstaff GUI/helper if it isn't already running).

## License

MIT

#!/bin/sh
# Hubstaff window helper for the noctalia-hubstaff plugin.
#
# Usage:
#   hubstaff-window.sh hide
#   hubstaff-window.sh open <client-binary-path>
#   hubstaff-window.sh state    # prints "tiling" / "floating" / "absent"
#
# Both subcommands look up Hubstaff windows in niri by app_id substring or
# title prefix (case-insensitive). The matcher catches Hubstaff's actual
# wayland app_id "Netsoft-com.netsoft.hubstaff" and similar variants.
#
# `hide` moves every match to the floating layout. A niri window-rule pinned
# to that app-id sets `default-floating-position x=65000 y=65000`, so the
# window lands far off-screen — fully invisible without polluting any
# workspace pip. The daemon is untouched (no XDG close request is sent).
#
# `open` moves every match back to the tiling layout, where niri renders it
# on the focused workspace as part of the normal scrolling tile flow. Falls
# back to launching the client binary if no Hubstaff window is in niri.
#
# Why the tiling-then-floating dance in `hide`: niri's
# `move-window-to-floating` is a no-op on a window that's already floating,
# so its default-floating-position rule wouldn't reapply. Moving to tiling
# first guarantees the next floating transition triggers the rule and resets
# the position off-screen, even if the user previously dragged it somewhere
# visible.

set -eu

action="${1:-}"

match_ids() {
    niri msg --json windows | jq -r '
        .[]
        | select(
            ((.app_id // "") | ascii_downcase | contains("hubstaff"))
            or ((.title // "") | ascii_downcase | startswith("hubstaff"))
          )
        | .id
    '
}

case "$action" in
    hide)
        ids=$(match_ids)
        if [ -z "$ids" ]; then
            echo "No Hubstaff window found in niri" >&2
            exit 1
        fi
        echo "$ids" | while read -r id; do
            [ -n "$id" ] || continue
            niri msg action move-window-to-tiling --id "$id" >/dev/null 2>&1 || true
            niri msg action move-window-to-floating --id "$id"
        done
        ;;
    open)
        client="${2:-}"
        ids=$(match_ids)
        if [ -z "$ids" ]; then
            if [ -z "$client" ] || [ ! -x "$client" ]; then
                echo "No Hubstaff window in niri and no usable client binary" >&2
                exit 1
            fi
            "$client" >/dev/null 2>&1 &
            exit 0
        fi
        echo "$ids" | while read -r id; do
            [ -n "$id" ] || continue
            niri msg action move-window-to-tiling --id "$id"
        done
        ;;
    state)
        # Print the first matched Hubstaff window's state. The plugin uses
        # this to decide whether the toggle button should say "Open" or "Hide".
        line=$(niri msg --json windows | jq -r '
            .[]
            | select(
                ((.app_id // "") | ascii_downcase | contains("hubstaff"))
                or ((.title // "") | ascii_downcase | startswith("hubstaff"))
              )
            | (if .is_floating then "floating" else "tiling" end)
        ' | head -n 1)
        echo "${line:-absent}"
        ;;
    *)
        echo "usage: $0 {hide|open <client-binary>|state}" >&2
        exit 64
        ;;
esac

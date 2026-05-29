#!/usr/bin/env bash
# Random wallpaper via awww (formerly swww) with a wave transition.
# Usage: wallpaper.sh init   -> start daemon, set initial only if freshly started (reload-safe)
#        wallpaper.sh         -> cycle to a new random wallpaper now (SUPER+B)
set -euo pipefail

WPDIR="$HOME/Ricelin/wallpapers"

ensure_daemon() {
    awww query >/dev/null 2>&1 && return 0
    local attempt i
    for attempt in 1 2 3 4 5; do
        awww-daemon >/dev/null 2>&1 &
        for i in $(seq 1 15); do
            awww query >/dev/null 2>&1 && return 0
            sleep 0.2
        done
    done
    return 1
}

daemon_was_running=true
awww query >/dev/null 2>&1 || daemon_was_running=false
ensure_daemon || exit 0

if [ "${1:-}" = "init" ] && [ "$daemon_was_running" = true ]; then
    exit 0
fi

pic=$(find "$WPDIR" -type f \( -iname '*.jpg' -o -iname '*.png' \) | shuf -n1)
[ -n "$pic" ] || exit 0

awww img "$pic" \
    --transition-type wave \
    --transition-angle 30 \
    --transition-wave "60,30" \
    --transition-fps 60 \
    --transition-step 90

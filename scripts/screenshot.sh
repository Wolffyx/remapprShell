#!/usr/bin/env bash
# Take a screenshot with whatever this machine already has.
#
#   status [--json]     which tool would be used, and for what
#   region              choose a rectangle and capture it
#   screen              the whole desktop
#   window              the active window
#
# Nothing here draws a region selector or writes a PNG of its own: this is a
# chooser. Plasma ships Spectacle and Spectacle is what a KDE user expects --
# its selector, its save location, its notification, its "Open with". So when
# Spectacle is installed it is what runs, and this script is a shortcut target
# that happens to know how to call it.
#
# grim and slurp are the fallback, for a machine without Spectacle: the
# capture is saved under the pictures directory, copied to the clipboard, and
# announced with a notification carrying the file, so the popup shows the
# picture the same way Spectacle's does.
#
# Why a shell action at all, when Spectacle has global shortcuts of its own:
# binding a key to *this* means one key works on a machine with Spectacle and
# on one without, and the settings window lists it beside the shell's own
# actions rather than sending people to System Settings.
set -uo pipefail

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
source "$REPO_ROOT/scripts/lib/log.sh"
source "$REPO_ROOT/scripts/lib/brand.sh"

MODES=(region screen window)

# The tool this machine would use, or "" when it has none.
screenshot_tool() {
    if command -v spectacle >/dev/null 2>&1; then
        printf 'spectacle'
    elif command -v grim >/dev/null 2>&1; then
        printf 'grim'
    fi
}

# What a tool can actually do. grim alone cannot choose a rectangle (that is
# slurp) and knows nothing about windows, so a mode it cannot serve is said
# so rather than silently capturing the whole screen instead.
tool_can() {   # <tool> <mode>
    case "$1:$2" in
        spectacle:*) return 0 ;;
        grim:screen) return 0 ;;
        grim:region) command -v slurp >/dev/null 2>&1 ;;
        grim:window) command -v slurp >/dev/null 2>&1 ;;
        *) return 1 ;;
    esac
}

tool_note() {   # <tool> <mode>
    case "$1:$2" in
        grim:window) printf 'grim cannot pick a window; you choose the area' ;;
        *) printf '' ;;
    esac
}

# Where a capture goes when we are the one saving it. xdg-user-dir knows the
# localised name of the pictures directory; without it, Pictures.
pictures_dir() {
    local dir=""
    command -v xdg-user-dir >/dev/null 2>&1 && dir=$(xdg-user-dir PICTURES 2>/dev/null)
    [ -n "$dir" ] && [ "$dir" != "$HOME" ] || dir="$HOME/Pictures"
    printf '%s/Screenshots' "$dir"
}

notify_saved() {   # <file>
    command -v notify-send >/dev/null 2>&1 || return 0
    # image-path is the hint every notification daemon reads for the picture
    # beside the text, this shell's own included; x-kde-urls is what makes
    # Plasma's "open" and drag-out work. Both name the file on disk, so
    # nothing large travels over the bus.
    notify-send --app-name "$DISPLAY_NAME" \
        --icon "$1" \
        --hint "string:image-path:file://$1" \
        --hint "string:x-kde-urls:file://$1" \
        "Screenshot saved" "$1" 2>/dev/null || true
}

capture_spectacle() {   # <mode>
    local flag
    case "$1" in
        region) flag=--region ;;
        screen) flag=--fullscreen ;;
        window) flag=--activewindow ;;
    esac
    # --background: capture and exit rather than opening the editor. Spectacle
    # saves where its own settings say and posts its own notification, which
    # is the point of deferring to it.
    exec spectacle "$flag" --background
}

capture_grim() {   # <mode>
    local dir file geom
    dir=$(pictures_dir)
    mkdir -p "$dir" || die "could not write to $dir"
    file="$dir/Screenshot_$(date +%Y%m%d_%H%M%S).png"

    if [ "$1" = screen ]; then
        grim "$file" || die "grim failed"
    else
        geom=$(slurp 2>/dev/null) || exit 0   # cancelled: not a failure
        [ -n "$geom" ] || exit 0
        grim -g "$geom" "$file" || die "grim failed"
    fi

    command -v wl-copy >/dev/null 2>&1 && wl-copy --type image/png < "$file" 2>/dev/null &
    notify_saved "$file"
    printf '%s\n' "$file"
}

cmd=${1:-status}
[ $# -gt 0 ] && shift

case "$cmd" in
    status)
        tool=$(screenshot_tool)
        if [ "${1:-}" = "--json" ]; then
            modes=$(for m in "${MODES[@]}"; do
                jq -cn --arg mode "$m" \
                       --argjson ok "$(tool_can "${tool:-none}" "$m" && echo true || echo false)" \
                       --arg note "$(tool_note "${tool:-none}" "$m")" \
                       '{mode: $mode, supported: $ok, note: $note}'
            done | jq -sc '.')
            jq -n --arg tool "$tool" --argjson modes "$modes" '{tool: $tool, modes: $modes}'
            exit 0
        fi
        if [ -z "$tool" ]; then
            log_warn "no screenshot tool found -- install spectacle (or grim and slurp)"
            exit 1
        fi
        printf 'tool: %s\n\n' "$tool"
        for m in "${MODES[@]}"; do
            if tool_can "$tool" "$m"; then
                note=$(tool_note "$tool" "$m")
                printf '  %-8s yes%s\n' "$m" "${note:+  -- $note}"
            else
                printf '  %-8s no\n' "$m"
            fi
        done
        ;;

    region|screen|window)
        tool=$(screenshot_tool)
        [ -n "$tool" ] || die "no screenshot tool found -- install spectacle (or grim and slurp)"
        tool_can "$tool" "$cmd" || die "$tool cannot capture a $cmd on this machine"
        case "$tool" in
            spectacle) capture_spectacle "$cmd" ;;
            grim)      capture_grim "$cmd" ;;
        esac
        ;;

    *) die "unknown command: $cmd (one of: status ${MODES[*]})" ;;
esac

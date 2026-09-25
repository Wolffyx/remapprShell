#!/usr/bin/env bash
# Take a screenshot through the desktop portal.
#
#   status [--json]     whether a portal answers, and what each mode does
#   region              the portal's chooser, to pick an area
#   screen              the whole desktop, with no chooser
#   window              the portal's chooser, to pick a window
#
# The capture is `org.freedesktop.portal.Screenshot`'s, answered by whatever
# backend this desktop installs: nothing here names a program, draws a
# selector or writes the picture. `screen` asks for a capture with no
# questions. `region` and `window` ask for the portal's own chooser, and the
# portal decides what it offers -- whether a window can be picked there, and
# how an area is drawn, is its UI and not ours. So those two are one request,
# kept as two actions so a key bound to either goes on working.
#
# What happens after the capture is ours: the file is put under the pictures
# directory, copied to the clipboard, and announced with a notification
# carrying the file, so the popup shows the picture.
#
# Why a shell action at all, when a desktop has screenshot keys of its own:
# binding a key to *this* means one key works on any desktop with a portal,
# and the settings window lists it beside the shell's own actions rather than
# sending people to System Settings.
#
# The portal is part of the running desktop, so with the no-session switch
# set nothing is asked of it: `status` says so and a capture is refused.
set -uo pipefail

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
source "$REPO_ROOT/scripts/lib/log.sh"
source "$REPO_ROOT/scripts/lib/brand.sh"

MODES=(region screen window)

# One connection subscribes, calls and waits: see the helper for why that
# cannot be a `gdbus call`.
PORTAL_HELPER="$REPO_ROOT/scripts/lib/portal-screenshot.py"

# How long a capture may take to answer. With a chooser on screen that is a
# person deciding, and they are given time; with none it is the portal alone.
TIMEOUT_CHOOSER=300
TIMEOUT_DIRECT=30

# The Screenshot interface's version when a portal answers; nothing when none
# does, or when there is no session to ask.
portal_version() {
    session_available || return 1
    python3 "$PORTAL_HELPER" --check 2>/dev/null
}

mode_note() {   # <mode>
    case "$1" in
        region) printf "the portal's chooser: you pick the area there" ;;
        window) printf "the portal's chooser: pick the window there, if it offers one" ;;
        *)      printf '' ;;
    esac
}

# Where a capture goes. xdg-user-dir knows the localised name of the pictures
# directory; without it, Pictures.
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

capture() {   # <mode>
    local chooser=() timeout=$TIMEOUT_CHOOSER src rc dir file name ext stamp n
    session_available || die "no session: the desktop portal was not asked for a screenshot"
    if [ "$1" = screen ]; then timeout=$TIMEOUT_DIRECT; else chooser=(--interactive); fi

    src=$(python3 "$PORTAL_HELPER" "${chooser[@]}" --timeout "$timeout"); rc=$?
    case "$rc" in
        0) ;;
        1) exit 0 ;;   # closed in the portal's chooser: not a failure
        3) die "no desktop portal answers Screenshot -- this desktop's portal backend provides it" ;;
        4) die "the desktop portal did not answer in ${timeout}s" ;;
        *) die "the desktop portal could not take the screenshot" ;;
    esac
    [ -f "$src" ] || die "the desktop portal named a file that is not there: $src"

    # Where the portal writes is the portal's business -- a temporary file for
    # one backend, the pictures directory for another -- so the file is moved
    # to where ours have always gone. Copied instead when it cannot be moved,
    # which leaves the portal's copy where the portal put it.
    dir=$(pictures_dir)
    mkdir -p "$dir" || die "could not write to $dir"
    case "$src" in
        "$dir"/*) file=$src ;;
        *)
            name=$(basename -- "$src")
            case "$name" in *.*) ext=${name##*.} ;; *) ext=png ;; esac
            # Named to the second, so a second capture within it is numbered
            # rather than written over the first.
            stamp=$(date +%Y%m%d_%H%M%S)
            file="$dir/Screenshot_$stamp.$ext"; n=2
            while [ -e "$file" ]; do file="$dir/Screenshot_$stamp-$n.$ext"; n=$((n + 1)); done
            mv -f -- "$src" "$file" 2>/dev/null || cp -- "$src" "$file" \
                || die "could not save the screenshot to $file"
            ;;
    esac

    command -v wl-copy >/dev/null 2>&1 && wl-copy --type image/png < "$file" 2>/dev/null &
    notify_saved "$file"
    printf '%s\n' "$file"
}

cmd=${1:-status}
[ $# -gt 0 ] && shift

case "$cmd" in
    status)
        version=$(portal_version) || version=""
        if [ "${1:-}" = "--json" ]; then
            modes=$(for m in "${MODES[@]}"; do
                jq -cn --arg mode "$m" \
                       --argjson ok "$([ -n "$version" ] && echo true || echo false)" \
                       --arg note "$(mode_note "$m")" \
                       '{mode: $mode, supported: $ok, note: $note}'
            done | jq -sc '.')
            jq -n --arg tool "${version:+portal}" --arg version "$version" \
                  --argjson session "$(session_available && echo true || echo false)" \
                  --argjson modes "$modes" \
                  '{tool: $tool, version: ($version | tonumber? // null), session: $session, modes: $modes}'
            exit 0
        fi
        if ! session_available; then
            log_warn "no session: the desktop portal was not asked"
            exit 1
        fi
        if [ -z "$version" ]; then
            log_warn "no desktop portal answers Screenshot -- this desktop's portal backend provides it"
            exit 1
        fi
        printf 'desktop portal: Screenshot, version %s\n\n' "$version"
        for m in "${MODES[@]}"; do
            note=$(mode_note "$m")
            printf '  %-8s yes%s\n' "$m" "${note:+  -- $note}"
        done
        ;;

    region|screen|window)
        capture "$cmd"
        ;;

    *) die "unknown command: $cmd (one of: status ${MODES[*]})" ;;
esac

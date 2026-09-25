# shellcheck shell=bash
# KWin: what it has loaded, asking it to read its configuration again, and the
# scripts this project loads into it.
#
# Requires brand.sh, log.sh. Night Light needs busctl and jq; rendering a
# script needs render.sh.

# KWin reads kwinrc when asked to. The KWin is the user's own whatever HOME
# says, so a test must not be able to ask it.
kwin_reconfigure() {
    session_available || return 0
    qdbus6 org.kde.KWin /KWin reconfigure >/dev/null 2>&1 \
      || busctl --user call org.kde.KWin /KWin org.kde.KWin reconfigure >/dev/null 2>&1 \
      || log_warn "could not ask KWin to reload; changes apply at next login"
}

# Is the sun up, by KWin's reckoning? "true", "false", or empty for "there is
# no schedule" -- which is Night Light unsupported or switched off, or no
# session to ask.
#
# Fails, printing nothing, only when KWin gave no answer at all: the call did
# not get through, or what came back was not the shape it should be. The two
# empties have to stay apart. The first is an answer, and waiting for a better
# one is five seconds on every `theme status` of a machine with Night Light
# off; the second is KWin not up yet, which is worth the wait.
#
# The same three properties the shell reads, asked the same way: Plasma has no
# light/dark schedule of its own, and Night Light's is the one the user has
# already configured, so following it means the desktop and the shell cannot
# disagree about when night is.
night_light_daylight() {
    session_available || return 0
    local out values
    out=$(busctl --user --json=short get-property org.kde.KWin /org/kde/KWin/NightLight \
              org.kde.KWin.NightLight available enabled daylight 2>/dev/null) || return 1
    values=$(jq -r '.data' <<< "$out" 2>/dev/null) || return 1
    case "${values//$'\n'/ }" in
        "true true true")  printf 'true' ;;
        "true true false") printf 'false' ;;
        *) ;;   # unavailable, off, or an answer in a shape we do not know
    esac
}

# Night Light answers over the bus, and on the login path it is asked seconds
# after KWin started -- early enough to be told nothing at all. Answering
# "no schedule" then is not neutral, so wait briefly for the real answer. Only
# for an answer, though: "no schedule" is one, and is taken at once.
night_light_wait() {   # [seconds]
    local deadline=$(( SECONDS + ${1:-5} )) answer
    while :; do
        answer=$(night_light_daylight) && { printf '%s' "$answer"; return 0; }
        [ "$SECONDS" -ge "$deadline" ] && return 0
        sleep 0.25
    done
}

# Tiling scripts take a window dragged to a screen edge for themselves, and so
# does KWin's own snapping: with both on, which one gets the drag depends on
# timing. Only an *enabled* one is named. Installed is not the same thing --
# doctor used to warn about every script in the directory, which meant a
# krohnkite switched off for weeks, and this project's own window-list
# script.
KWIN_TILING_SCRIPTS=(krohnkite bismuth polonium kzones)

kwin_tiling_scripts() {
    local s
    for s in "${KWIN_TILING_SCRIPTS[@]}"; do
        kwin_plugin_enabled "$s" && printf '%s\n' "$s"
    done
    return 0
}

# A plugin's switch in kwinrc -- which is what makes KWin load a script at
# login -- as written, or the default when it is not. kwin_plugin_enabled is
# the yes-or-no of it.
kwin_plugin_state() {   # <plugin id> [default]
    kreadconfig6 --file kwinrc --group Plugins --key "${1}Enabled" --default "${2:-false}"
}
kwin_plugin_enabled() { [ "$(kwin_plugin_state "$1")" = true ]; }

# ---- scripts of our own ---------------------------------------------------
#
# Two scripts are this project's -- the window list and the screen edges --
# and two more are run once and taken away again. All of them go through
# KWin's /Scripting interface, and none of them may reach a KWin a test is
# not allowed to touch.

# One call on /Scripting. Fails, saying nothing, when there is no session.
kwin_scripting() {   # <method> [args...]
    session_available || return 1
    qdbus6 org.kde.KWin /Scripting "org.kde.kwin.Scripting.$1" "${@:2}" 2>/dev/null
}

kwin_script_loaded() { [ "$(kwin_scripting isScriptLoaded "$1")" = "true" ]; }

# Loads a script afresh. Unloaded first, because KWin ignores loading a script
# it already has -- so without this, a script re-rendered after a change goes
# on running the old one, which is a confusing thing to debug.
kwin_script_reload() {   # <id> <main.js>
    kwin_scripting unloadScript "$1" >/dev/null
    kwin_scripting loadScript "$2" "$1" >/dev/null
    kwin_scripting start >/dev/null
}

# Whether KWin says the script is loaded, and when it does not, what that
# means and where to look -- said the same way for every script.
kwin_script_check_loaded() {   # <id> <what, e.g. "the edge script">
    kwin_script_loaded "$1" && return 0
    log_warn "KWin did not report $2 as loaded"
    log_info "  it is enabled in kwinrc and will load at the next login"
    log_info "  see why: journalctl --user -u plasma-kwin_wayland.service -n 30"
    return 1
}

# Renders a script package from its templates -- metadata.json.in and
# contents/code/main.js.in -- into place. Anything its templates need beyond
# the usual names is set by the caller, for the call.
kwin_script_render() {   # <source dir> <destination dir> <what>
    local src=$1 dest=$2 what=$3
    mkdir -p "$dest/contents/code"
    render_template "$src/metadata.json.in" "$dest/metadata.json" \
        || { log_error "could not render $what metadata"; return 1; }
    render_template "$src/contents/code/main.js.in" "$dest/contents/code/main.js" \
        || { log_error "could not render $what"; return 1; }
    chmod 644 "$dest/metadata.json" "$dest/contents/code/main.js"
}

# Runs a script once, from stdin, and takes it away again. For what only KWin
# can answer or do and nothing needs to keep running for: a loaded script that
# has already run is a name in KWin's list and nothing more.
#
# Given long enough to leave KWin before it is unloaded, which is the caller's
# to judge: a call to the bus is quick, a window asked to close takes longer.
kwin_script_oneshot() {   # <name> <seconds to let it run>
    local name=$1 wait=$2 file
    file=$(mktemp --suffix=.js "${XDG_RUNTIME_DIR:-/tmp}/$name.XXXXXX") \
        || { log_error "could not write the script"; return 1; }
    cat > "$file"
    kwin_scripting unloadScript "$name" >/dev/null
    if ! kwin_scripting loadScript "$file" "$name" >/dev/null; then
        rm -f "$file"
        log_error "KWin did not load the script"
        return 1
    fi
    kwin_scripting start >/dev/null
    sleep "$wait"
    kwin_scripting unloadScript "$name" >/dev/null
    rm -f "$file"
}

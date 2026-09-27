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

# kwinrc_read <array> <group>...
#
# Every key of those groups into the named associative array, keyed
# "<group>:<key>", each as kreadconfig6 would read it. A key it would find
# unset is left out, so a lookup names its own default:
# ${rc[Windows:AutoRaise]-false}.
#
# One awk for them all, where each key was a kreadconfig6 of its own --
# nineteen for one refresh of the screen edges page. It reads what KConfig
# reads, in the same order: the kwinrc in each of XDG_CONFIG_DIRS (absolute
# ones only, as Qt takes them), the last first, then the user's own over them
# -- and on Plasma the first of those directories is the look and feel's
# ~/.config/kdedefaults, so the cascade is not academic. A key, a group or a
# whole file marked `[$i]` keeps its value from the files after it, and a key
# marked `[$d]` is taken away. What it would have to imitate beyond that -- an
# escape in a value, a value to expand (`[$e]`), one in the user's language
# (`Key[de]`) -- it leaves to kreadconfig6, key by key: nothing KWin or System
# Settings writes into these groups has one.
kwinrc_read() {
    local -n _kw_rc=$1
    shift
    local -a _kw_given=() _kw_dirs=() _kw_files=()
    local _kw_d _kw_i _kw_how _kw_name _kw_value _kw_absent="__rmpr_absent_1f8b__"
    _kw_rc=()
    IFS=: read -ra _kw_given <<< "${XDG_CONFIG_DIRS:-}"
    for _kw_d in "${_kw_given[@]}"; do
        [[ $_kw_d == /* ]] && _kw_dirs+=("$_kw_d")
    done
    [ ${#_kw_dirs[@]} -gt 0 ] || _kw_dirs=(/etc/xdg)
    for (( _kw_i = ${#_kw_dirs[@]} - 1; _kw_i >= 0; _kw_i-- )); do
        _kw_d=${_kw_dirs[_kw_i]}/kwinrc
        [ -f "$_kw_d" ] && [ -r "$_kw_d" ] && _kw_files+=("$_kw_d")
    done
    _kw_d=$XDG_CONFIG_HOME/kwinrc
    [ -f "$_kw_d" ] && [ -r "$_kw_d" ] && _kw_files+=("$_kw_d")
    [ ${#_kw_files[@]} -gt 0 ] || return 0

    while IFS=$'\t' read -r _kw_how _kw_name _kw_value; do
        [ "$_kw_how" = ask ] && _kw_value=$(kreadconfig6 --file kwinrc --group "${_kw_name%%:*}" \
                                                --key "${_kw_name#*:}" --default "$_kw_absent")
        [ "$_kw_value" = "$_kw_absent" ] || _kw_rc[$_kw_name]=$_kw_value
    done < <(IFS=$'\t'; LC_ALL=C awk -v groups="$*" '
        BEGIN {
            n = split(groups, g, "\t")
            for (k = 1; k <= n; k++) want[g[k]] = 1
        }
        # A group locked by the file before is locked from here on, and after
        # a file locked whole no file is read at all.
        FNR == 1 {
            if (sealed) exit
            for (k in locking) locked[k] = 1
            split("", locking)
            group = ""; filelock = 0
        }
        { sub(/^[ \t\r\f\v]+/, ""); sub(/[ \t\r\f\v]+$/, "") }
        $0 == "" || /^#/ { next }
        /^\[/ { header($0); next }
        group != "" && !(group in locked) { entry() }

        # "[A][B]" is B inside A, and after a "]" anything but another "[" is
        # dropped. A last "[$i]" locks the group, or on its own the file. A
        # header with no "]" is not one, and the group before it goes on.
        function header(line,    name, part, shut, lock) {
            name = ""; lock = filelock
            while (substr(line, 1, 1) == "[") {
                shut = index(line, "]")
                if (!shut) return
                part = substr(line, 2, shut - 2)
                line = substr(line, shut + 1)
                if (part != "$i" || line != "") name = name == "" ? part : name "\035" part
                else if (name == "") filelock = sealed = 1
                else lock = 1
            }
            grouplock = lock
            group = (name in want) ? name : ""
            if (group != "" && lock) locking[group] = 1
        }

        function entry(    eq, key, value, opts, lang, shut, name) {
            eq = index($0, "=")
            key = eq ? substr($0, 1, eq - 1) : $0
            value = eq ? substr($0, eq + 1) : ""
            sub(/[ \t\r\f\v]+$/, "", key)
            sub(/^[ \t\r\f\v]+/, "", value)
            # Markers and a language come off the end, as KConfig takes them.
            opts = ""; lang = 0
            while (match(key, /\[[^[]*$/)) {
                shut = index(substr(key, RSTART), "]")
                if (!shut) return
                if (substr(key, RSTART + 1, 1) == "$") opts = opts substr(key, RSTART + 2, shut - 3)
                else lang = 1
                key = substr(key, 1, RSTART - 1)
            }
            if (key == "") return
            name = group ":" key
            if (lang || opts ~ /e/ || index(value, "\\")) { ask[name] = 1; return }
            if (name in fixed) return
            if (opts ~ /d/) { delete val[name]; return }
            if (!eq) return
            val[name] = value
            if (grouplock || opts ~ /i/) fixed[name] = 1
        }

        END {
            for (name in ask) print "ask\t" name
            for (name in val) if (!(name in ask)) print "val\t" name "\t" val[name]
        }' "${_kw_files[@]}")
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
    local -A rc=()
    kwinrc_read rc Plugins
    for s in "${KWIN_TILING_SCRIPTS[@]}"; do
        [ "${rc[Plugins:${s}Enabled]-false}" = true ] && printf '%s\n' "$s"
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

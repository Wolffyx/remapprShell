# shellcheck shell=bash
# Snap layouts: kwin/snap, a KWin script that opens a panel of layouts at the
# top of a screen while a window is dragged there, and puts the window in the
# zone it is let go over -- as one of KWin's own tiles. Meta+Z opens the same
# panel for the active window, and Snap Assist offers the screen's other
# windows for the zones a snap left empty. What it draws and how it places is
# in kwin/snap/contents/ui/; this is the switch.
#
# Sourced by windows.sh, never executed. Requires brand.sh, log.sh,
# kconfig.sh, kwin.sh, render.sh and config.sh.
#
# Five settings. Three are in kwinrc and ledgered: the script's plugin switch,
# which is what makes KWin load it at login, in a scope of its own
# (windows-snap) so turning it off puts back exactly that; and how the panel
# opens (Reveal) and whether Snap Assist follows a snap (Assist), both in the
# script's own group, with the rest of the window behaviour
# (windows-behaviour). The script reads those two when it loads, so a change
# to either reloads it. The fourth is Meta+Z, which is a key of this
# project's like any other -- the `snap` action, `shortcuts.snap` in the
# profile -- and so is bound and unbound by shortcuts.sh, which `shortcuts
# revert` undoes. The fifth is the gap around a tiled window (Gap, in the
# script's group): see snap_gap_set.
SNAP_SCRIPT_SRC="$REPO_ROOT/kwin/snap"
SNAP_SCRIPT_DEST="$KWIN_SCRIPTS_DIR/$KWIN_SNAP_SCRIPT_ID"
SNAP_GROUP="Script-$KWIN_SNAP_SCRIPT_ID"
SNAP_MAIN="$SNAP_SCRIPT_DEST/contents/ui/main.qml"
# The KWin action the script registers for Meta+Z to reach it by: Picker.qml's
# pickAction, which says why there is one.
SNAP_PICK_ACTION="Snap Layouts: Active Window"

snap_enabled() { kwin_plugin_enabled "$KWIN_SNAP_SCRIPT_ID"; }

snap_reveal() {
    kreadconfig6 --file kwinrc --group "$SNAP_GROUP" --key Reveal --default top
}

snap_assist() {
    kreadconfig6 --file kwinrc --group "$SNAP_GROUP" --key Assist --default true
}

# On when the profile binds the `snap` action to a key: "none" is unbound, and
# an empty value leaves it to whatever KDE has, which is not this switch's.
snap_key() {
    local key
    key=$(config_get '.shortcuts.snap' '')
    [ -n "$key" ] && [ "$key" != none ] && echo true || echo false
}

snap_install() {
    kwin_package_render "$SNAP_SCRIPT_SRC" "$SNAP_SCRIPT_DEST" "the snap layouts script"
}

# Whether the installed package is what this checkout renders now: an update
# that changes the script reaches KWin only if something installs it again.
snap_current() {
    local tmp rc=1
    [ -d "$SNAP_SCRIPT_DEST" ] || return 1
    tmp=$(mktemp -d) || return 1
    if kwin_package_render "$SNAP_SCRIPT_SRC" "$tmp/pkg" "the snap layouts script" 2>/dev/null; then
        diff -rq "$tmp/pkg" "$SNAP_SCRIPT_DEST" >/dev/null 2>&1 && rc=0
    fi
    rm -rf "$tmp"
    return "$rc"
}

# Reloaded, not loaded: KWin ignores loading a script it already has, so a
# re-rendered one would otherwise go on running the old copy.
snap_load() {
    session_available || { log_info "not loading it now: no session"; return 0; }
    kwin_declarative_reload "$KWIN_SNAP_SCRIPT_ID" "$SNAP_MAIN"
    kwin_script_check_loaded "$KWIN_SNAP_SCRIPT_ID" "the snap layouts script"
}

snap_on() {
    snap_install || return 1
    kconfig_set windows-snap kwinrc Plugins "${KWIN_SNAP_SCRIPT_ID}Enabled" true
    snap_load
}

snap_off() {
    kwin_scripting unloadScript "$KWIN_SNAP_SCRIPT_ID" >/dev/null
    kconfig_revert windows-snap >/dev/null
    # The ledger puts back what was there; a key it never saw set stays
    # set, and false is what makes KWin skip the script at the next login.
    snap_enabled && kwriteconfig6 --file kwinrc --group Plugins --key "${KWIN_SNAP_SCRIPT_ID}Enabled" false
    rm -rf "$KWIN_LOAD_DIR/$KWIN_SNAP_SCRIPT_ID"-*
    [ -d "$SNAP_SCRIPT_DEST" ] || return 0
    rm -rf "$SNAP_SCRIPT_DEST"
    log_step "removed $SNAP_SCRIPT_DEST"
}

snap_set() {   # true|false
    case "$1" in
        true)  snap_on ;;
        false) snap_off ;;
    esac
}

snap_reveal_set() {   # top|drag
    kconfig_set windows-behaviour kwinrc "$SNAP_GROUP" Reveal "$1"
    snap_enabled || return 0
    snap_load
}

snap_assist_set() {   # true|false
    kconfig_set windows-behaviour kwinrc "$SNAP_GROUP" Assist "$1"
    snap_enabled || return 0
    snap_load
}

# The gap around a tiled window: KWin's tile padding, which KWin keeps per
# screen and desktop with no one setting for them all. Given to every root
# tile at once by a one-shot script -- setting a root's padding sets its
# tiles', and KWin saves it with the layout -- so it holds with the snap
# script off too; the snap script gives it again to a screen or a desktop
# added later, which comes with KWin's 4. Unset is KWin's 4.
SNAP_GAP_KWIN=4

snap_gap() {
    kreadconfig6 --file kwinrc --group "$SNAP_GROUP" --key Gap --default "$SNAP_GAP_KWIN"
}

snap_gap_apply() {   # <pixels>
    session_available || { log_info "not applying it now: no session"; return 0; }
    kwin_script_oneshot "$KWIN_SNAP_SCRIPT_ID-gap" 0.3 <<JS
if (typeof workspace.rootTile === "function") {
    for (const output of workspace.screens)
        for (const desktop of workspace.desktops) {
            const top = workspace.rootTile(output, desktop);
            if (top)
                top.padding = $1;
        }
}
JS
}

snap_gap_set() {   # <pixels>
    kconfig_set windows-behaviour kwinrc "$SNAP_GROUP" Gap "$1"
    snap_gap_apply "$1" || return 1
    tile_gap_follow "$1" || return 1
    snap_enabled || return 0
    snap_load
}

# On binds the key the defaults ship for the action, Meta+Z; off unbinds it.
# A key chosen on the Shortcuts page instead stays until this is turned off.
snap_key_set() {   # true|false
    if [ "$1" = false ]; then
        "$REPO_ROOT/scripts/shortcuts.sh" clear snap
        return
    fi
    "$REPO_ROOT/scripts/shortcuts.sh" set snap "$(jq -r '.shortcuts.snap' "$(config_defaults_file)")"
}

snap_enabled_value() { snap_enabled && echo true || echo false; }

# The five settings, as `windows behaviour` names them in its table: how each
# is read, and how each is written.
declare -A SNAP_GET=([enabled]=snap_enabled_value [reveal]=snap_reveal [assist]=snap_assist [key]=snap_key [gap]=snap_gap)
declare -A SNAP_SET=([enabled]=snap_set [reveal]=snap_reveal_set [assist]=snap_assist_set [key]=snap_key_set [gap]=snap_gap_set)

snap_value() { "${SNAP_GET[$1]}"; }        # <setting>
snap_apply() { "${SNAP_SET[$1]}" "$2"; }   # <setting> <value>

# What Meta+Z runs: the panel for the active window. A KWin script can call
# D-Bus and never be called, so the script registers an action of KWin's and
# kglobalaccel invokes it -- as a key bound to that action would.
snap_pick() {
    session_available || die "no session to open snap layouts in"
    kwin_script_loaded "$KWIN_SNAP_SCRIPT_ID" \
        || die "snap layouts are not loaded (turn them on: $ALIAS windows behaviour set snapLayouts true)"
    busctl --user call org.kde.kglobalaccel /component/kwin org.kde.kglobalaccel.Component \
        invokeShortcut s "$SNAP_PICK_ACTION" >/dev/null
}

# After an install or an update: the package again, if it is installed and
# no longer what the checkout renders, and KWin told.
snap_refresh() {
    [ -d "$SNAP_SCRIPT_DEST" ] || return 0
    snap_current && return 0
    snap_install || return 1
    log_step "snap layouts script updated"
    snap_enabled || return 0
    snap_load
}

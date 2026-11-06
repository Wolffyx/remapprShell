# shellcheck shell=bash
# Auto-tiling: kwin/tile, a KWin script that tiles every window as it opens,
# in Hyprland's dwindle layout -- each new window takes half of the focused
# one, split along its longer side -- per screen and desktop, in KWin's own
# tiles. What it does with windows is in kwin/tile/contents/ui/; this is the
# switch, and the keys.
#
# Sourced by windows.sh, never executed. Requires brand.sh, log.sh,
# kconfig.sh, kwin.sh, render.sh, config.sh and windows/snap.sh.
#
# One setting, autoTile, off unless it is turned on: it changes where every
# window goes, which is not a default this project chooses for anyone. On, it
# writes three things to kwinrc, all in a scope of its own (windows-tile) so
# turning it off puts back exactly what was there: the script's plugin
# switch; the gap -- tileGap, the one setting, copied into the script's group
# so it gives the same padding to the tiles it makes; and AutoTile=true in
# the snap layouts' group, which keeps them from snapping a window this
# script tiles. And it binds the keys below to the actions the script
# registers, through shortcuts.sh, for every one the profile leaves unbound.
#
# Refused while another tiling script is enabled: two scripts arranging the
# same windows undo each other at every window that opens.
TILE_SCRIPT_SRC="$REPO_ROOT/kwin/tile"
TILE_SCRIPT_DEST="$KWIN_SCRIPTS_DIR/$KWIN_TILE_SCRIPT_ID"
TILE_GROUP="Script-$KWIN_TILE_SCRIPT_ID"
TILE_MAIN="$TILE_SCRIPT_DEST/contents/ui/main.qml"

# Each key action of this project's (shortcut-actions.tsv) the KWin action
# the script registers for it -- main.qml's `actions`, which test-windows.sh
# checks against this -- and the key auto-tiling binds it to when it is
# turned on: Meta+Alt with the arrows, Shift to move and Ctrl to swap.
# Meta+Alt and an arrow is KWin's own "switch to the window" that way, which
# the focus keys do the same as, inside the tiles.
declare -A TILE_ACTION=(
    [tile-focus-left]="Auto Tile: Focus Left"    [tile-focus-right]="Auto Tile: Focus Right"
    [tile-focus-up]="Auto Tile: Focus Up"        [tile-focus-down]="Auto Tile: Focus Down"
    [tile-move-left]="Auto Tile: Move Left"      [tile-move-right]="Auto Tile: Move Right"
    [tile-move-up]="Auto Tile: Move Up"          [tile-move-down]="Auto Tile: Move Down"
    [tile-swap-left]="Auto Tile: Swap Left"      [tile-swap-right]="Auto Tile: Swap Right"
    [tile-swap-up]="Auto Tile: Swap Up"          [tile-swap-down]="Auto Tile: Swap Down"
    [tile-float]="Auto Tile: Toggle Floating"    [tile-desktop]="Auto Tile: Toggle Desktop"
)
declare -A TILE_KEY=(
    [tile-focus-left]=Meta+Alt+Left              [tile-focus-right]=Meta+Alt+Right
    [tile-focus-up]=Meta+Alt+Up                  [tile-focus-down]=Meta+Alt+Down
    [tile-move-left]=Meta+Alt+Shift+Left         [tile-move-right]=Meta+Alt+Shift+Right
    [tile-move-up]=Meta+Alt+Shift+Up             [tile-move-down]=Meta+Alt+Shift+Down
    [tile-swap-left]=Meta+Ctrl+Alt+Left          [tile-swap-right]=Meta+Ctrl+Alt+Right
    [tile-swap-up]=Meta+Ctrl+Alt+Up              [tile-swap-down]=Meta+Ctrl+Alt+Down
    [tile-float]=Meta+Alt+Space                  [tile-desktop]=Meta+Alt+T
)

tile_enabled() { kwin_plugin_enabled "$KWIN_TILE_SCRIPT_ID"; }
tile_enabled_value() { tile_enabled && echo true || echo false; }

tile_install() {
    kwin_package_render "$TILE_SCRIPT_SRC" "$TILE_SCRIPT_DEST" "the auto-tiling script"
}

# Reloaded, not loaded, and from a copy named by its content: see
# kwin_declarative_reload, and the snap layouts' snap_load.
tile_load() {
    session_available || { log_info "not loading it now: no session"; return 0; }
    kwin_declarative_reload "$KWIN_TILE_SCRIPT_ID" "$TILE_MAIN"
    kwin_script_check_loaded "$KWIN_TILE_SCRIPT_ID" "the auto-tiling script"
}

# The snap layouts read AutoTile when they load, so they are loaded again.
tile_tell_snap() {
    snap_enabled || return 0
    snap_load
}

# What the profile binds each key action of auto-tiling to, as
# "<action> <key>" lines -- "" or none for one it leaves unbound -- from one
# read of it.
tile_keys_held() {
    config_merged | jq -r --args '.shortcuts // {} as $s | $ARGS.positional[] | "\(.) \($s[.] // "")"' \
        "${!TILE_KEY[@]}"
}

# Every key action of auto-tiling the profile leaves unbound gets its key;
# one chosen on the Shortcuts page stays. Off unbinds every one bound. Each
# in one call of shortcuts.sh, for all fourteen: a call a key made turning
# auto-tiling on or off take seconds.
tile_keys_bind() {
    local action have pairs=()
    while read -r action have; do
        [ -z "$have" ] || [ "$have" = none ] || continue
        pairs+=("$action" "${TILE_KEY[$action]}")
    done < <(tile_keys_held)
    [ ${#pairs[@]} -gt 0 ] || return 0
    "$REPO_ROOT/scripts/shortcuts.sh" set "${pairs[@]}"
}

tile_keys_clear() {
    local action have bound=()
    while read -r action have; do
        [ -z "$have" ] || [ "$have" = none ] && continue
        bound+=("$action")
    done < <(tile_keys_held)
    [ ${#bound[@]} -gt 0 ] || return 0
    "$REPO_ROOT/scripts/shortcuts.sh" clear "${bound[@]}"
}

tile_on() {
    local tilers
    tilers=$(kwin_tiling_scripts | tr '\n' ' ')
    if [ -n "$tilers" ]; then
        log_error "auto-tiling stays off: ${tilers% } is enabled and tiles windows itself, and the two would undo each other"
        log_info "  turn it off first, in System Settings > Window Management > KWin Scripts"
        return 1
    fi
    tile_install || return 1
    kconfig_set windows-tile kwinrc Plugins "${KWIN_TILE_SCRIPT_ID}Enabled" true
    kconfig_set windows-tile kwinrc "$TILE_GROUP" Gap "$(snap_gap)"
    kconfig_set windows-tile kwinrc "$SNAP_GROUP" AutoTile true
    tile_tell_snap
    tile_load
    tile_keys_bind
}

# The windows are let go of where they are: the script does that as it is
# unloaded. Switched off in kwinrc first: letting the windows go changes the
# tiles, KWin saves them and reconfigures, and Scripting::start() then loads
# every enabled script that is not running -- this one, still enabled,
# which tiled every window again (measured in the rig).
tile_off() {
    kconfig_revert windows-tile >/dev/null
    tile_enabled && kwriteconfig6 --file kwinrc --group Plugins --key "${KWIN_TILE_SCRIPT_ID}Enabled" false
    kwin_scripting unloadScript "$KWIN_TILE_SCRIPT_ID" >/dev/null
    rm -rf "$KWIN_LOAD_DIR/$KWIN_TILE_SCRIPT_ID"-*
    tile_tell_snap
    tile_keys_clear
    [ -d "$TILE_SCRIPT_DEST" ] || return 0
    rm -rf "$TILE_SCRIPT_DEST"
    log_step "removed $TILE_SCRIPT_DEST"
}

tile_set() {   # true|false
    case "$1" in
        true)  tile_on ;;
        false) tile_off ;;
    esac
}

# How it tiles, in the script's group and ledgered with the rest of the window
# behaviour, so turning auto-tiling off keeps them for the next time: the
# layout (dwindle, or master and stack), the most windows tiled on a screen
# and desktop (0: as many as KWin's smallest tile allows), and a share in
# percent -- a new window's of the split it makes, or the master's of the
# width. The script reads them when it loads, so a change reloads it.
tile_option() {   # <key> <default>
    kreadconfig6 --file kwinrc --group "$TILE_GROUP" --key "$1" --default "$2"
}

tile_option_set() {   # <key> <value>
    kconfig_set windows-behaviour kwinrc "$TILE_GROUP" "$1" "$2"
    tile_enabled || return 0
    tile_load
}

tile_layout() { tile_option Layout dwindle; }
tile_max() { tile_option Max 0; }
tile_ratio() { tile_option Ratio 50; }
tile_layout_set() { tile_option_set Layout "$1"; }
tile_max_set() { tile_option_set Max "$1"; }
tile_ratio_set() { tile_option_set Ratio "$1"; }

# The settings, as `windows behaviour` names them in its table.
declare -A TILE_GET=([enabled]=tile_enabled_value [layout]=tile_layout [max]=tile_max [ratio]=tile_ratio)
declare -A TILE_SET=([enabled]=tile_set [layout]=tile_layout_set [max]=tile_max_set [ratio]=tile_ratio_set)

tile_value() { "${TILE_GET[$1]}"; }        # <setting>
tile_apply() { "${TILE_SET[$1]}" "$2"; }   # <setting> <value>

# The gap changed: the script's copy of it follows, if the script is on.
tile_gap_follow() {   # <pixels>
    tile_enabled || return 0
    kconfig_set windows-tile kwinrc "$TILE_GROUP" Gap "$1"
    tile_load
}

# What a key of auto-tiling runs: the script's action, through kglobalaccel,
# as the snap layouts' Meta+Z does (snap_pick says why).
tile_invoke() {   # <verb> [direction]
    local action="tile-$1${2:+-$2}"
    [ -n "${TILE_ACTION[$action]+x}" ] \
        || die "not an auto-tiling action: '$*' (focus|move|swap left|right|up|down, float, desktop)"
    session_available || die "no session to tile in"
    kwin_script_loaded "$KWIN_TILE_SCRIPT_ID" \
        || die "auto-tiling is not loaded (turn it on: $ALIAS windows behaviour set autoTile true)"
    busctl --user call org.kde.kglobalaccel /component/kwin org.kde.kglobalaccel.Component \
        invokeShortcut s "${TILE_ACTION[$action]}" >/dev/null
}

# KWin's own tile editor -- Meta+T -- for the screen under the pointer: the
# tiles themselves, which the snap layouts and auto-tiling both fill. KWin's
# action, invoked as a key bound to it would be.
tile_edit() {
    session_available || die "no session to edit tiles in"
    busctl --user call org.kde.kglobalaccel /component/kwin org.kde.kglobalaccel.Component \
        invokeShortcut s "Edit Tiles" >/dev/null
}

# After an install or an update: the package again, if it is installed and no
# longer what the checkout renders, and KWin told.
tile_refresh() {
    [ -d "$TILE_SCRIPT_DEST" ] || return 0
    kwin_package_current "$TILE_SCRIPT_SRC" "$TILE_SCRIPT_DEST" && return 0
    tile_install || return 1
    log_step "auto-tiling script updated"
    tile_enabled || return 0
    tile_load
}

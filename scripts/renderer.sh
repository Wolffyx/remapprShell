#!/usr/bin/env bash
# Chooses what draws the panel.
#
#   status              what is drawing the panel now, and what would change
#   list                every renderer, and whether it is usable here
#   set <renderer>      switch, with a restore point and a rollback
#   revert              put plasmashell's shell package back
#
# There is one `panel.renderer` key and one generator, so two panels at the
# same screen edge is not a state this can reach. That is the bug it exists to
# avoid: a shell package that ships a Plasma panel while a second shell also
# draws one leaves the user with both, stacked.
#
# Every mutating path is plan -> snapshot -> apply -> verify -> rollback. The
# generated applet layout is the riskiest write in the project, so the failure
# case is designed first: if the switch does not verify, the previous layout
# and every KDE key we touched go back before the command returns.
set -uo pipefail

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
source "$REPO_ROOT/scripts/lib/log.sh"
source "$REPO_ROOT/scripts/lib/brand.sh"
source "$REPO_ROOT/scripts/lib/render.sh"
source "$REPO_ROOT/scripts/lib/kconfig.sh"
source "$REPO_ROOT/scripts/lib/protected.sh"
source "$REPO_ROOT/scripts/lib/snapshot.sh"
source "$REPO_ROOT/scripts/lib/appletsrc.sh"

RENDERERS=(quickshell plasma caelestia none)
CAELESTIA_UNIT="app-caelestiashell@autostart.service"
BACKUP_DIR="$STATE_DIR/renderer-backups"

# --- what the shell is configured to do -----------------------------------

active_profile() {
    local state="$CONFIG_DIR/state.json"
    [ -f "$state" ] && jq -r '.profile // "default"' "$state" 2>/dev/null || echo default
}

profile_file() { printf '%s/profiles/%s/shell.json' "$CONFIG_DIR" "$(active_profile)"; }

defaults_file() {
    # The installed copy first: that is what the running shell reads, and a
    # renderer generated from a different description than the one on screen
    # would be a confusing thing to debug.
    local installed="$DATA_DIR/config/defaults/shell.json"
    [ -f "$installed" ] && { printf '%s' "$installed"; return; }
    printf '%s/config/defaults/shell.json' "$REPO_ROOT"
}

widget_index() {
    local installed="$QS_CONFIG_DIR/widgets/index.json"
    [ -f "$installed" ] && { printf '%s' "$installed"; return; }
    printf '%s/shell/widgets/index.json' "$REPO_ROOT"
}

# Defaults plus the user's sparse delta, which is what the shell itself draws
# from. Generating the Plasma panel from anything else would let the two
# renderers disagree about what the panel contains.
effective_config() {
    local defaults profile
    defaults=$(defaults_file)
    profile=$(profile_file)
    if [ -f "$profile" ] && jq -e . "$profile" >/dev/null 2>&1; then
        jq -s '.[0] * .[1]' "$defaults" "$profile"
    else
        [ -f "$profile" ] && log_warn "$profile does not parse; using the shipped defaults"
        cat "$defaults"
    fi
}

configured_renderer() { effective_config | jq -r '.panel.renderer // "quickshell"'; }

live_shell_package() {
    kreadconfig6 --file plasmashellrc --group Shell --key ShellPackage --default 'org.kde.plasma.desktop'
}

package_for() {
    case "$1" in
        plasma)             printf '%s' "$PLASMA_SHELL_PACKAGE_ID" ;;
        quickshell)         printf '%s' "$SHELL_PACKAGE_ID" ;;
        # Process-level only: caelestia draws its own bar from its own package,
        # and no code of ours is involved. Ours stays the shell package so the
        # desktop keeps the containment it already has.
        caelestia)          printf '%s' "$SHELL_PACKAGE_ID" ;;
        none)               printf 'org.kde.plasma.desktop' ;;
    esac
}

# Will anything of ours actually draw a panel?
#
# The quickshell renderer's shell package ships no Plasma panel *because our
# shell draws it*. If our shell is neither running nor installed, switching to
# it leaves plasmashell with no panel and nothing in its place -- a desktop with
# no panel at all, which is what this check exists to prevent. It cost a real
# desktop its panel once.
shell_will_draw() {
    # Matched on the installed path, not the slug: the slug appears in a
    # development run from a checkout too, and more importantly it makes this
    # answer depend on which HOME is in play -- which is what lets a test in a
    # throwaway HOME get a deterministic answer instead of inheriting whatever
    # the developer happens to be running.
    pgrep -f "$QS_CONFIG_DIR" >/dev/null 2>&1 && return 0
    session_available && systemctl --user is-active "$SYSTEMD_UNIT" >/dev/null 2>&1 && return 0
    session_available && systemctl --user is-enabled "$SYSTEMD_UNIT" >/dev/null 2>&1 && return 0
    return 1
}

caelestia_available() { session_available && systemctl --user cat "$CAELESTIA_UNIT" >/dev/null 2>&1; }

# Whether this run may touch the running desktop at all.
#
# A throwaway HOME does not give a throwaway session bus: plasmashell is still
# listening on the real one, and `changeShell` would switch the desktop the
# person is using while a test believed it was working in a sandbox. So the
# guard is explicit and the tests set it.
session_available() { [ -z "${!NO_SESSION_VAR:-}" ]; }

# --- package installation --------------------------------------------------

# Installs one shell package. Both are installed whenever either is needed:
# switching back must not depend on an install step that could fail at the
# worst moment, with the old layout already gone.
install_shell_package() {
    local src=$1 id=$2
    local dest="$PLASMA_SHELLS_DIR/$id"

    mkdir -p "$dest/contents"
    render_template "$src/metadata.json.in" "$dest/metadata.json" \
        || { log_error "could not render the metadata for $id"; return 1; }
    chmod 644 "$dest/metadata.json"

    cp -a "$src/contents/layouts" "$dest/contents/" || return 1
    cp -a "$src/contents/defaults" "$dest/contents/" || return 1
    log_debug "installed $dest"
}

install_packages() {
    install_shell_package "$REPO_ROOT/plasma/shells/quickshell" "$SHELL_PACKAGE_ID" || return 1
    install_shell_package "$REPO_ROOT/plasma/shells/plasma"     "$PLASMA_SHELL_PACKAGE_ID" || return 1
    # KDE caches installed packages; without this plasmashell cannot resolve
    # the package we are about to point it at until the next login.
    session_available && kbuildsycoca6 --noincremental >/dev/null 2>&1
    true
    log_step "installed both shell packages in $PLASMA_SHELLS_DIR"
}

# --- switching -------------------------------------------------------------

# Asks plasmashell to change shell live, then confirms it stuck. The DBus call
# is preferred because it needs no restart; the key write is the fallback, not
# the primary path, because a key write alone does nothing until the next login
# and the user would be left looking at the old panel wondering what happened.
CHANGESHELL_OK=0

# --- protecting the layout we are switching away from ----------------------
#
# Observed on a live desktop: switching ShellPackage away from a third-party
# package left that package's applet layout gutted -- every containment gone,
# the panel and desktop it described with them. plasmashell had written its own
# now-empty view of that package's config back to disk on the way out.
#
# It is not our write, but it happens because of our switch, and "it was
# plasmashell" is no comfort to someone whose panel layout has just been
# deleted. So the outgoing layout is copied out before the switch and put back
# if it comes out the other side with fewer containments than it went in with.
OUTGOING_PKG=""
OUTGOING_COPY=""
OUTGOING_COUNT=0

hold_outgoing_layout() {
    OUTGOING_PKG=$(live_shell_package)
    OUTGOING_COPY=""
    OUTGOING_COUNT=0

    # Our own layouts are regenerated by this command anyway, and the stock
    # package is never modified by anyone here.
    case "$OUTGOING_PKG" in
        "$SHELL_PACKAGE_ID"|"$PLASMA_SHELL_PACKAGE_ID"|org.kde.plasma.desktop) return 0 ;;
    esac

    local held
    held=$(appletsrc_hold "$OUTGOING_PKG" "$BACKUP_DIR/outgoing") || return 0
    [ -n "$held" ] || return 0
    OUTGOING_COUNT=${held%% *}
    OUTGOING_COPY=${held#* }
    log_debug "holding $OUTGOING_PKG's layout ($OUTGOING_COUNT containment(s))"
}

restore_outgoing_layout() {
    appletsrc_restore_if_gutted "$OUTGOING_PKG" "$OUTGOING_COPY" "$OUTGOING_COUNT"
}

apply_shell_package() {
    local pkg=$1

    if session_available \
       && qdbus6 org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.changeShell "$pkg" >/dev/null 2>&1; then
        CHANGESHELL_OK=1
        log_debug "changeShell($pkg) accepted"
    else
        log_debug "changeShell is unavailable (plasmashell may not be running)"
    fi

    # Written either way: changeShell does not always persist the choice, and
    # the ledger is what makes it undoable.
    kconfig_set backend plasmashellrc Shell ShellPackage "$pkg"

    local live
    live=$(live_shell_package)
    if [ "$live" != "$pkg" ]; then
        log_error "plasmashell's shell package is '$live', expected '$pkg'"
        return 1
    fi
}

# The panel view's geometry lives in plasmashellrc, keyed by the containment id
# we allocate, not in the applet layout. Writing it means a thickness set in our
# settings window reaches the Plasma panel too.
#
# It happens AFTER the switch, and through the running plasmashell as well as
# the key. plasmashell creates the panel view when it loads the package and
# holds its geometry in memory, so a key written beforehand is not what ends up
# on screen and a thickness change would appear to do nothing until the next
# start.
apply_panel_geometry() {
    local pkg=$1 thickness=$2 position=$3
    local group="PlasmaViews/Panel $APPLETSRC_PANEL_ID"
    kconfig_set backend plasmashellrc "$group" shell "$pkg"
    kconfig_set backend plasmashellrc "$group/Defaults" thickness "$thickness"

    session_available || return 0

    # And tell the running plasmashell, which holds the view in memory and
    # writes its own value back over ours otherwise.
    #
    # changeShell returns before the new package's panel exists, so this waits
    # for it. Without the wait the assignment lands on an empty list and does
    # nothing at all -- which looks exactly like the key write being ignored.
    # Break only on a positive count. An empty answer -- plasmashell still
    # starting, or the call failing outright -- is not "the panel is ready",
    # and treating it as one is exactly how the assignment landed on an empty
    # list and did nothing.
    local waited=0 count
    while [ "$waited" -lt 20 ]; do
        count=$(_plasma_script 'print(panels().length)')
        case "$count" in ''|*[!0-9]*) count=0 ;; esac
        [ "$count" -gt 0 ] && break
        sleep 0.25
        waited=$((waited + 1))
    done
    # The containment exists a moment before the view that draws it does.
    sleep 0.5

    # A vertical panel's thickness is its width; a horizontal one's is its
    # height, and the scripting API has no single name for it.
    local prop=height
    case "$position" in left|right) prop=width ;; esac

    if ! _plasma_script "panels().forEach(function (p) { p.$prop = $thickness; })" >/dev/null; then
        log_warn "could not set the panel thickness through plasmashell"
        log_info "  it will be $thickness after the next plasmashell start"
    fi
}

# plasmashell's own scripting console, over DBus. Returns whatever the script
# printed.
_plasma_script() {
    qdbus6 org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript "$1" 2>/dev/null
}

restart_plasmashell() {
    session_available || { log_debug "not touching the session"; return 0; }
    # kquitapp6 is wrong here: the unit is Restart=on-failure, so a clean exit
    # leaves plasmashell dead and the user with no desktop at all.
    if systemctl --user restart plasma-plasmashell.service >/dev/null 2>&1; then
        log_step "restarted plasmashell"
    else
        log_warn "could not restart plasmashell; log out and back in to see the change"
    fi
}

# Writes panel.renderer into the active profile, sparsely: the profile holds
# what the user changed, not a materialised copy of today's defaults.
write_renderer_setting() {
    local target=$1 file
    file=$(profile_file)
    mkdir -p "$(dirname "$file")"

    if [ -f "$file" ] && ! jq -e . "$file" >/dev/null 2>&1; then
        log_error "$file does not parse; refusing to write over it"
        log_info "  fix it first: jq . $file"
        return 1
    fi

    local tmp
    tmp=$(mktemp)
    if [ -f "$file" ]; then
        jq --arg r "$target" '.panel = ((.panel // {}) + {renderer: $r})' "$file" > "$tmp" || return 1
    else
        jq -n --arg r "$target" '{panel: {renderer: $r}}' > "$tmp" || return 1
    fi
    mv "$tmp" "$file"
    log_debug "set panel.renderer=$target in $file"
}

# --- reporting -------------------------------------------------------------

compat_report() {
    local target=$1 config index unsupported folded
    config=$(mktemp); effective_config > "$config"
    index=$(widget_index)

    if [ "$target" != "plasma" ]; then
        rm -f "$config"
        return 0
    fi

    unsupported=$(appletsrc_unsupported "$index" "$config")
    folded=$(appletsrc_folded_into_tray "$index" "$config")
    rm -f "$config"

    # Not a loss, so not a warning: the same icons, drawn by Plasma's tray.
    if [ -n "$folded" ]; then
        log_info "Plasma's system tray shows these itself, so they are not added beside it:"
        printf '%s\n' "$folded" | sed 's/^/        /' >&2
    fi

    [ -n "$unsupported" ] || { log_info "every enabled widget has a Plasma applet"; return 0; }

    log_warn "the Plasma renderer cannot draw these enabled widgets:"
    printf '%s\n' "$unsupported" | sed 's/^/        /' >&2
    log_info "  they will be left out of the panel until you switch back"
    return 0
}

cmd=${1:-status}
[ $# -gt 0 ] && shift

ASSUME_YES=0
DRY_RUN=0
FORCE=0
args=()
while [ $# -gt 0 ]; do
    case "$1" in
        -y|--yes)   ASSUME_YES=1 ;;
        --force)    FORCE=1 ;;
        --dry-run)  DRY_RUN=1 ;;
        -*)         die "unknown option: $1" ;;
        *)          args+=("$1") ;;
    esac
    shift
done

case "$cmd" in
    list)
        current=$(configured_renderer)
        for r in "${RENDERERS[@]}"; do
            mark=' '; [ "$r" = "$current" ] && mark='*'
            case "$r" in
                quickshell) note="our layer-shell panel; every widget, full visual freedom" ;;
                plasma)     note="drawn by plasmashell from the same configuration; stock applets only" ;;
                caelestia)  if caelestia_available; then note="caelestia's own bar, started as a service"
                            else note="not available here ($CAELESTIA_UNIT is not installed)"; fi ;;
                none)       note="stock Plasma panels, untouched" ;;
            esac
            printf '%s %-12s %s\n' "$mark" "$r" "$note"
        done
        ;;

    status)
        configured=$(configured_renderer)
        printf 'configured:     %s\n' "$configured"
        printf 'shell package:  %s\n' "$(live_shell_package)"
        printf 'expected:       %s\n' "$(package_for "$configured")"
        printf 'packages:       %s\n' \
            "$([ -d "$PLASMA_SHELLS_DIR/$SHELL_PACKAGE_ID" ] && echo "installed" || echo "not installed")"
        printf 'applet layout:  %s\n' "$(appletsrc_path "$(package_for "$configured")")"
        if [ "$configured" = "plasma" ]; then
            f=$(appletsrc_path "$PLASMA_SHELL_PACKAGE_ID")
            if [ -f "$f" ]; then
                printf 'panel applets:  %s\n' "$(sed -n 's/^AppletOrder=//p' "$f" | tr ';' ' ')"
            else
                printf 'panel applets:  not generated yet\n'
            fi
        fi
        echo
        echo 'ledger (what revert would undo):'
        kconfig_ledger_summary backend
        ;;

    set)
        target=${args[0]:-}
        [ -n "$target" ] || die "usage: $ALIAS renderer set <$(IFS='|'; printf '%s' "${RENDERERS[*]}")>"

        valid=0
        for r in "${RENDERERS[@]}"; do [ "$r" = "$target" ] && valid=1; done
        [ "$valid" = 1 ] || die "unknown renderer: $target (expected one of: ${RENDERERS[*]})"

        [ "$target" = caelestia ] && ! caelestia_available \
            && die "caelestia is not installed here ($CAELESTIA_UNIT not found)"

        # The one switch that can leave a desktop with nothing.
        if [ "$target" = quickshell ] && [ "$FORCE" != 1 ] && ! shell_will_draw; then
            log_error "$DISPLAY_NAME is not running, and the quickshell renderer expects it to draw the panel"
            log_error "switching now would leave you with no panel at all"
            echo >&2
            log_info "either start the shell first:"
            log_info "    make link && $ALIAS start"
            log_info "or pick a renderer that draws without it:"
            log_info "    $ALIAS renderer set plasma   # plasmashell draws our panel"
            log_info "    $ALIAS renderer set none     # your stock Plasma panels"
            log_info "or, if you know what you are doing: --force"
            exit 1
        fi

        pkg=$(package_for "$target")
        log_step "switching to the $target renderer (shell package: $pkg)"

        # Told before anything is written, and named individually. "Some
        # widgets may not work" is not information a person can act on.
        compat_report "$target"

        if [ "$DRY_RUN" = 1 ]; then
            tmp=$(mktemp); config=$(mktemp)
            effective_config > "$config"
            appletsrc_generate "$tmp" "$config" "$(widget_index)" "$target" \
                "$(appletsrc_wallpaper "$(appletsrc_path "$(live_shell_package)")")" \
                || die "generation failed"
            expect=no; [ "$target" = plasma ] && expect=yes
            appletsrc_validate "$tmp" "$expect" || die "the generated layout does not validate"
            log_step "this is what would be installed at $(appletsrc_path "$pkg"):"
            cat "$tmp"
            rm -f "$tmp" "$config"
            exit 0
        fi

        if [ "$ASSUME_YES" != 1 ] && [ -t 0 ]; then
            printf 'switch to the %s renderer? [y/N] ' "$target" >&2
            read -r reply
            case "$reply" in y|Y|yes) : ;; *) die "cancelled" ;; esac
        fi

        snapshot_create "before-renderer-$target" >/dev/null \
            || die "could not take a restore point; refusing to switch"

        hold_outgoing_layout

        install_packages || die "could not install the shell packages; nothing was switched"

        # Both layouts are regenerated, not only the target's. The one we are
        # switching away from must not keep a panel it is no longer allowed to
        # draw, or switching back and forth would accumulate panels.
        config=$(mktemp); effective_config > "$config"
        index=$(widget_index)
        failed=0

        # Taken from whatever package plasmashell is using right now, which is
        # the desktop the user is looking at.
        wallpaper=$(appletsrc_wallpaper "$(appletsrc_path "$(live_shell_package)")")
        [ -n "$wallpaper" ] && log_debug "carrying the wallpaper across: $wallpaper"

        for pair in "quickshell:$SHELL_PACKAGE_ID" "plasma:$PLASMA_SHELL_PACKAGE_ID"; do
            r=${pair%%:*}; p=${pair#*:}
            # Only the target renderer gets a panel; the other package is
            # written panel-free regardless of which one it is.
            want=none
            [ "$r" = "$target" ] && want=$target

            gen=$(mktemp)
            appletsrc_generate "$gen" "$config" "$index" "$want" "$wallpaper" || { failed=1; rm -f "$gen"; break; }
            expect=no; [ "$want" = plasma ] && expect=yes
            appletsrc_validate "$gen" "$expect" || { failed=1; rm -f "$gen"; break; }
            appletsrc_install "$gen" "$(appletsrc_path "$p")" "$BACKUP_DIR" || { failed=1; rm -f "$gen"; break; }
            rm -f "$gen"
        done

        if [ "$failed" = 1 ]; then
            rm -f "$config"
            log_error "the applet layout could not be generated; nothing was activated"
            log_info "  the previous layouts are in $BACKUP_DIR"
            exit 1
        fi

        thickness=$(jq -r '.panel.thickness // 40' "$config")
        position=$(jq -r '.panel.position // "bottom"' "$config")
        rm -f "$config"

        if ! apply_shell_package "$pkg"; then
            log_error "the switch did not take; rolling back"
            kconfig_revert backend
            for p in "$SHELL_PACKAGE_ID" "$PLASMA_SHELL_PACKAGE_ID"; do
                f=$(appletsrc_path "$p")
                [ -f "$BACKUP_DIR/$(basename "$f")" ] && cp -a "$BACKUP_DIR/$(basename "$f")" "$f"
            done
            die "rolled back; nothing changed"
        fi

        # After the switch, for the reason apply_panel_geometry explains.
        [ "$target" = plasma ] && apply_panel_geometry "$pkg" "$thickness" "$position"

        # Leaving the plasma renderer leaves our panel view's group behind,
        # for the same reason a revert does.
        [ "$target" = plasma ] || kconfig_purge_group plasmashellrc "PlasmaViews/Panel $APPLETSRC_PANEL_ID"

        # plasmashell writes the outgoing package's config on its way out, and
        # has been seen to write an empty one.
        session_available && sleep 1
        restore_outgoing_layout

        write_renderer_setting "$target" || {
            log_warn "the shell package was switched but panel.renderer was not written"
            log_warn "  the Quickshell panel may still draw; fix $(profile_file) by hand"
        }

        # Our own panel appears and disappears the moment the key is read,
        # because the shell watches its configuration. plasmashell only reloads
        # if changeShell reached it; a key write alone does nothing until the
        # next login, which would leave the old panel on screen with no
        # explanation.
        if [ "$CHANGESHELL_OK" = 1 ]; then
            log_debug "plasmashell switched live; no restart needed"
        else
            restart_plasmashell
        fi

        if [ "$target" = caelestia ]; then
            bound=$(jq '[.entries[] | select(.scope == "shortcuts")] | length' "$(kconfig_ledger)" 2>/dev/null || echo 0)
            if [ "${bound:-0}" -gt 0 ]; then
                log_warn "this project holds $bound global shortcut(s) that caelestia also wants"
                log_info "  release them first: $ALIAS shortcuts revert"
            fi
            session_available && systemctl --user start "$CAELESTIA_UNIT" >/dev/null 2>&1 \
                && log_step "started $CAELESTIA_UNIT" \
                || log_warn "could not start $CAELESTIA_UNIT"
        fi

        log_step "now drawing with: $target"
        log_info "undo with: $ALIAS renderer set quickshell"
        ;;

    revert)
        kconfig_revert backend
        # plasmashell adds its own keys to our panel view's group while the
        # panel exists, and the ledger can only put back the keys we wrote. The
        # group is named after a containment id we allocate, so nothing else
        # can own anything in it.
        kconfig_purge_group plasmashellrc "PlasmaViews/Panel $APPLETSRC_PANEL_ID"
        write_renderer_setting quickshell || true
        restart_plasmashell
        log_step "reverted to the shell package plasmashell had before"
        ;;

    *) die "unknown command: $cmd (expected status, list, set or revert)" ;;
esac

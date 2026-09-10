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
# we allocate, not in the applet layout. Writing it here means a thickness set
# in our settings window reaches the Plasma panel too.
apply_panel_geometry() {
    local pkg=$1 thickness=$2
    local group="PlasmaViews/Panel $APPLETSRC_PANEL_ID"
    kconfig_set backend plasmashellrc "$group" shell "$pkg"
    kconfig_set backend plasmashellrc "$group/Defaults" thickness "$thickness"
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
    local target=$1 config index unsupported
    config=$(mktemp); effective_config > "$config"
    index=$(widget_index)

    if [ "$target" != "plasma" ]; then
        rm -f "$config"
        return 0
    fi

    unsupported=$(appletsrc_unsupported "$index" "$config")
    rm -f "$config"

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
args=()
while [ $# -gt 0 ]; do
    case "$1" in
        -y|--yes)   ASSUME_YES=1 ;;
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

        pkg=$(package_for "$target")
        log_step "switching to the $target renderer (shell package: $pkg)"

        # Told before anything is written, and named individually. "Some
        # widgets may not work" is not information a person can act on.
        compat_report "$target"

        if [ "$DRY_RUN" = 1 ]; then
            tmp=$(mktemp); config=$(mktemp)
            effective_config > "$config"
            appletsrc_generate "$tmp" "$config" "$(widget_index)" "$target" || die "generation failed"
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

        install_packages || die "could not install the shell packages; nothing was switched"

        # Both layouts are regenerated, not only the target's. The one we are
        # switching away from must not keep a panel it is no longer allowed to
        # draw, or switching back and forth would accumulate panels.
        config=$(mktemp); effective_config > "$config"
        index=$(widget_index)
        failed=0

        for pair in "quickshell:$SHELL_PACKAGE_ID" "plasma:$PLASMA_SHELL_PACKAGE_ID"; do
            r=${pair%%:*}; p=${pair#*:}
            # Only the target renderer gets a panel; the other package is
            # written panel-free regardless of which one it is.
            want=none
            [ "$r" = "$target" ] && want=$target

            gen=$(mktemp)
            appletsrc_generate "$gen" "$config" "$index" "$want" || { failed=1; rm -f "$gen"; break; }
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
        rm -f "$config"

        [ "$target" = plasma ] && apply_panel_geometry "$pkg" "$thickness"

        if ! apply_shell_package "$pkg"; then
            log_error "the switch did not take; rolling back"
            kconfig_revert backend
            for p in "$SHELL_PACKAGE_ID" "$PLASMA_SHELL_PACKAGE_ID"; do
                f=$(appletsrc_path "$p")
                [ -f "$BACKUP_DIR/$(basename "$f")" ] && cp -a "$BACKUP_DIR/$(basename "$f")" "$f"
            done
            die "rolled back; nothing changed"
        fi

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
        write_renderer_setting quickshell || true
        restart_plasmashell
        log_step "reverted to the shell package plasmashell had before"
        ;;

    *) die "unknown command: $cmd (expected status, list, set or revert)" ;;
esac

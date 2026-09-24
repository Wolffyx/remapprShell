#!/usr/bin/env bash
# Chooses what draws the panel.
#
#   status              what is drawing the panel now, and what would change
#   list [--json]       every renderer here, other Quickshell shells included
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
source "$REPO_ROOT/scripts/lib/lockscreen.sh"
source "$REPO_ROOT/scripts/lib/render.sh"
source "$REPO_ROOT/scripts/lib/kconfig.sh"
source "$REPO_ROOT/scripts/lib/protected.sh"
source "$REPO_ROOT/scripts/lib/snapshot.sh"
source "$REPO_ROOT/scripts/lib/appletsrc.sh"
source "$REPO_ROOT/scripts/lib/renderers.sh"
source "$REPO_ROOT/scripts/lib/config.sh"

BACKUP_DIR="$STATE_DIR/renderer-backups"

# --- what the shell is configured to do -----------------------------------

widget_index() {
    local installed="$QS_CONFIG_DIR/widgets/index.json"
    [ -f "$installed" ] && { printf '%s' "$installed"; return; }
    printf '%s/shell/widgets/index.json' "$REPO_ROOT"
}

# Defaults plus the user's sparse delta, which is what the shell itself draws
# from (lib/config.sh). Generating the Plasma panel from anything else would
# let the two renderers disagree about what the panel contains -- and the
# defaults are the installed copy first for the same reason: a renderer
# generated from a different description than the one on screen would be a
# confusing thing to debug.
effective_config() {
    config_profile_broken && log_warn "$(profile_file) does not parse; using the shipped defaults"
    config_merged
}

configured_renderer() { effective_config | jq -r '.panel.renderer // "quickshell"'; }

# live_shell_package and package_for are lib/renderers.sh's: doctor, the report
# and the lock screen ask the same two questions.

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
    shell_running && return 0
    session_available && systemctl --user is-active "$SYSTEMD_UNIT" >/dev/null 2>&1 && return 0
    session_available && systemctl --user is-enabled "$SYSTEMD_UNIT" >/dev/null 2>&1 && return 0
    return 1
}

# --- another Quickshell shell ----------------------------------------------

# Started under our unit template, enabled so the next login starts it too.
start_foreign() {
    local name=$1 unit entry
    unit=$(renderer_unit "$name")
    session_available || { log_debug "not starting $unit: no session"; return 0; }
    systemctl --user daemon-reload >/dev/null 2>&1
    if systemctl --user enable --now "$unit" >/dev/null 2>&1; then
        log_step "started the $name configuration ($unit), and it starts with the session now"
    else
        log_warn "could not start $unit"
        log_info "  is it installed? make link puts the template in place; then: systemctl --user status $unit"
        return 1
    fi
    # Its own installer may have given it an autostart entry too. -n makes the
    # second start a no-op, but switching away cannot stop what that entry
    # brings back at the next login, so it is named now rather than then.
    if entry=$(renderer_autostart_entry "$name"); then
        log_info "  $entry also starts it at login; switching away will not stop that one"
    fi
}

# Every one of them but `keep`: whatever our template runs, and any instance of
# the configuration being left that something else started.
stop_foreign() {
    local keep=${1:-} leaving=${2:-} unit inst
    session_available || return 0
    while read -r unit; do
        [ -n "$unit" ] || continue
        inst=${unit#"$RENDERER_UNIT_TEMPLATE"}; inst=$(systemd-escape --unescape -- "${inst%.service}")
        [ -n "$keep" ] && [ "$inst" = "$keep" ] && continue
        systemctl --user disable --now "$unit" >/dev/null 2>&1 \
            && log_step "stopped the $inst configuration ($unit)" \
            || log_warn "could not stop $unit"
    done < <({ systemctl --user list-units --all --plain --no-legend "${RENDERER_UNIT_TEMPLATE}*" 2>/dev/null
               systemctl --user list-unit-files --plain --no-legend --state=enabled "${RENDERER_UNIT_TEMPLATE}*" 2>/dev/null
             } | awk '$1 !~ /@\.service$/ {print $1}' | sort -u)
    if [ -n "$leaving" ] && [ "$leaving" != "$keep" ]; then
        quickshell kill -c "$leaving" >/dev/null 2>&1 && log_step "stopped the running $leaving instance"
        if renderer_autostart_entry "$leaving" >/dev/null; then
            log_warn "$(renderer_autostart_entry "$leaving") will start $leaving again at the next login"
        fi
    fi
    return 0
}

# Whether this run may touch the running desktop at all.
#
# A throwaway HOME does not give a throwaway session bus: plasmashell is still
# listening on the real one, and `changeShell` would switch the desktop the
# person is using while a test believed it was working in a sandbox. So the
# guard is explicit -- `session_available`, in brand.sh -- and the tests set it.

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

    # The lock screen, when it is on, lives inside the package, so one
    # installed afresh gets it back. See lockscreen.sh.
    if lockscreen_enabled && [ ! -e "$dest/contents/lockscreen" ]; then
        lockscreen_install_into "$id" || log_warn "could not put the lock screen back into $id"
    fi
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
    config_set_string '.panel.renderer' "$target"
    case $? in
        0) log_debug "set panel.renderer=$target in $file" ;;
        2) log_error "$file does not parse; refusing to write over it"
           log_info "  fix it first: jq . $file"
           return 1 ;;
        *) return 1 ;;
    esac
}

# --- Plasma's tray-only services -------------------------------------------

# Under the quickshell renderer the shell hosts Plasma's notifications and
# clipboard applets with plasmawindowed, because nothing else would provide
# them (shell/domain/backend/PlasmaServices.qml). Any other renderer has a
# Plasma tray that is about to provide the same services, and a hosted copy
# still holding org.freedesktop.Notifications -- or running a second Klipper
# beside Plasma's -- would win against it. So the host goes first.
#
# Only when it really is hosting one of them: plasmawindowed is also what a
# widget's "..." button opens Plasma's applets in, and a window the user
# opened is not ours to close.
stop_hosted_services() {
    session_available || return 0
    local pid name owner
    pid=$(bus_status_field org.kde.plasmawindowed PID)
    [ -n "$pid" ] || return 0
    local hosting=0 it id
    for name in org.freedesktop.Notifications org.kde.klipper; do
        owner=$(bus_status_field "$name" PID)
        [ "$owner" = "$pid" ] && hosting=1
    done
    # The device notifier holds no bus name; its tray item, which only
    # --statusnotifier creates, says it is there.
    if [ "$hosting" = 0 ]; then
        while read -r it; do
            [ -n "$it" ] || continue
            id=$(busctl --user get-property "${it%%/*}" "/${it#*/}" org.kde.StatusNotifierItem Id 2>/dev/null \
                 | sed -e 's/^s "//' -e 's/"$//')
            [ "$id" = plasmawindowed_org.kde.plasma.devicenotifier ] && hosting=1
        done < <(busctl --user get-property org.kde.StatusNotifierWatcher /StatusNotifierWatcher \
                   org.kde.StatusNotifierWatcher RegisteredStatusNotifierItems 2>/dev/null \
                 | grep -o '"[^"]*"' | tr -d '"')
    fi
    [ "$hosting" = 1 ] || return 0
    log_info "closing Plasma's applets hosted for the quickshell renderer (plasmawindowed, pid $pid);"
    log_info "  the new panel's tray provides notifications, the clipboard and the device notifier"
    kill "$pid" 2>/dev/null || true
}

# The same for this shell's own notification server (notifications.server
# "shell"): it holds the name the new panel's tray is about to want, and it
# lets go only when the shell reads the new renderer -- which is written after
# the switch. So it is asked to let go first, and given a moment to.
release_shell_notifications() {
    session_available || return 0
    ours() { shell_holds_bus_name org.freedesktop.Notifications; }
    ours || return 0
    quickshell ipc --path "$(shell_ipc_path)" call notifications release >/dev/null 2>&1 || true
    local i
    for i in 1 2 3 4 5 6 7 8 9 10; do
        ours || return 0
        sleep 0.2
    done
    log_warn "the shell did not let go of org.freedesktop.Notifications; the new tray may not get it"
}

# Whether plasmashell itself holds the notification or Klipper name -- which,
# once it is on our package, can only be a leftover from the previous one.
plasmashell_holds_tray_services() {
    session_available || return 1
    local shell name owner
    shell=$(bus_status_field org.kde.plasmashell PID)
    [ -n "$shell" ] || return 1
    for name in org.freedesktop.Notifications org.kde.klipper; do
        owner=$(bus_status_field "$name" PID)
        [ "$owner" = "$shell" ] && return 0
    done
    return 1
}

# The other direction: a switch to quickshell asks the running shell to look
# again at once, rather than wait for a bus name to change hands.
rehost_services() {
    session_available || return 0
    quickshell ipc --path "$(shell_ipc_path)" call services rehost >/dev/null 2>&1 || true
}

# --- reporting -------------------------------------------------------------

compat_report() {   # <target> <effective config file>
    local target=$1 config=$2 index unsupported folded
    [ "$target" = "plasma" ] || return 0
    index=$(widget_index)

    unsupported=$(appletsrc_unsupported "$index" "$config")
    folded=$(appletsrc_folded_into_tray "$index" "$config")

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
JSON=0
args=()
while [ $# -gt 0 ]; do
    case "$1" in
        -y|--yes)   ASSUME_YES=1 ;;
        --force)    FORCE=1 ;;
        --dry-run)  DRY_RUN=1 ;;
        --json)     JSON=1 ;;
        -*)         die "unknown option: $1" ;;
        *)          args+=("$1") ;;
    esac
    shift
done

case "$cmd" in
    list)
        current=$(configured_renderer)
        rows=()
        while read -r r; do
            case "$r" in
                quickshell) label="This shell"
                            note="Our own panel, drawn as a layer-shell surface. Every widget, and every visual effect." ;;
                plasma)     label="Plasma"
                            note="Drawn by plasmashell from this same configuration, using stock applets. No shaders, no blur, and any widget without a Plasma equivalent is left out." ;;
                none)       label="Nothing"
                            note="Your stock Plasma panels, exactly as they were. Nothing of ours is drawn." ;;
                *)          name=$(renderer_config_name "$r")
                            label=$name
                            dir=$(renderer_config_dir "$name"); dir=${dir/#"$HOME"/\~}
                            note="Another Quickshell shell, found in $dir. It draws its own bar from its own code; none of ours runs in it." ;;
            esac
            rows+=("$(jq -nc --arg id "$r" --arg label "$label" --arg note "$note" \
                        --argjson current "$([ "$r" = "$current" ] && echo true || echo false)" \
                        '{id: $id, label: $label, note: $note, current: $current}')")
        done < <(renderer_ids)
        # A profile can name a configuration that has since been removed. It
        # is still what is configured, so it is still listed -- as missing.
        if renderer_is_foreign "$current" && [ -z "$(renderer_config_dir "$(renderer_config_name "$current")")" ]; then
            rows+=("$(jq -nc --arg id "$current" --arg label "$(renderer_config_name "$current")" \
                        '{id: $id, label: $label, note: "Configured, but no Quickshell configuration of that name is on this machine any more.", current: true, absent: true}')")
        fi
        if [ "$JSON" = 1 ]; then
            printf '%s\n' "${rows[@]}" | jq -sc .
        else
            printf '%s\n' "${rows[@]}" | jq -r '"\(if .current then "*" else " " end) \(.id | . + " " * ([22 - length, 1] | max))\(.note)"'
        fi
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
        [ -n "$target" ] || die "usage: $ALIAS renderer set <$(renderer_ids | paste -sd'|')>"

        # The configuration, merged once for everything below: the report, the
        # generated layouts and the panel's geometry all read this one file.
        config=$(mktemp)
        trap 'rm -f "$config"' EXIT
        effective_config > "$config"

        # The one being left, read before anything writes the new one.
        previous=$(jq -r '.panel.renderer // "quickshell"' "$config")

        valid=0
        while read -r r; do [ "$r" = "$target" ] && valid=1; done < <(renderer_ids)
        if [ "$valid" != 1 ]; then
            renderer_is_foreign "$target" \
                && die "no Quickshell configuration named '$(renderer_config_name "$target")' here (looked for quickshell/<name>/shell.qml in each XDG config directory)"
            die "unknown renderer: $target (expected one of: $(renderer_ids | paste -sd' '))"
        fi

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
        compat_report "$target" "$config"

        if [ "$DRY_RUN" = 1 ]; then
            tmp=$(mktemp)
            appletsrc_generate "$tmp" "$config" "$(widget_index)" "$target" \
                "$(appletsrc_wallpaper "$(appletsrc_path "$(live_shell_package)")")" \
                || die "generation failed"
            expect=no; [ "$target" = plasma ] && expect=yes
            appletsrc_validate "$tmp" "$expect" || die "the generated layout does not validate"
            log_step "this is what would be installed at $(appletsrc_path "$pkg"):"
            cat "$tmp"
            rm -f "$tmp"
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

        [ "$target" != quickshell ] && stop_hosted_services
        [ "$target" != quickshell ] && release_shell_notifications

        install_packages || die "could not install the shell packages; nothing was switched"

        # Both layouts are regenerated, not only the target's. The one we are
        # switching away from must not keep a panel it is no longer allowed to
        # draw, or switching back and forth would accumulate panels.
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
            log_error "the applet layout could not be generated; nothing was activated"
            log_info "  the previous layouts are in $BACKUP_DIR"
            exit 1
        fi

        IFS=$'\x1f' read -r thickness position \
            < <(jq -r '"\(.panel.thickness // 40)\u001f\(.panel.position // "bottom")"' "$config")

        if ! apply_shell_package "$pkg"; then
            log_error "the switch did not take; rolling back"
            kconfig_revert backend
            for p in "$SHELL_PACKAGE_ID" "$PLASMA_SHELL_PACKAGE_ID"; do
                f=$(appletsrc_path "$p")
                [ -f "$BACKUP_DIR/$(basename "$f")" ] && cp -a "$BACKUP_DIR/$(basename "$f")" "$f"
            done
            # The hosted services were stopped for a switch that did not
            # happen; without them, notifications would now be dropped.
            rehost_services
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

        # A live switch does not restart plasmashell, and its notification
        # server and Klipper are process-wide singletons: created by the
        # previous package's tray, they outlive it. On our package nothing
        # draws their popups, and while plasmashell holds the names nothing
        # else can serve them -- notifications are accepted and never shown.
        # Seen on 2026-09-11 switching from caelestia's layout. Only a restart
        # lets go of them.
        if [ "$target" = quickshell ] && [ "$CHANGESHELL_OK" = 1 ] && plasmashell_holds_tray_services; then
            log_info "plasmashell still holds the previous panel's notification server and clipboard;"
            log_info "  restarting it so the shell can host Plasma's own in their place"
            restart_plasmashell
        fi

        # No Plasma tray from here on: the shell hosts its notifications and
        # clipboard now rather than whenever it next notices.
        [ "$target" = quickshell ] && rehost_services

        # Only one thing draws. Whatever other Quickshell shell was drawing
        # stops now, including one started outside our template.
        leaving=""
        renderer_is_foreign "$previous" && leaving=$(renderer_config_name "$previous")
        if renderer_is_foreign "$target"; then
            name=$(renderer_config_name "$target")
            stop_foreign "$name" "$leaving"
            bound=$(jq '[.entries[] | select(.scope == "shortcuts")] | length' "$(kconfig_ledger)" 2>/dev/null || echo 0)
            if [ "${bound:-0}" -gt 0 ]; then
                log_warn "this project holds $bound global shortcut(s); $name may want some of the same keys"
                log_info "  release them if it does: $ALIAS shortcuts revert"
            fi
            start_foreign "$name" || log_warn "the switch is made, but $name is not running: nothing draws a panel"
        else
            stop_foreign "" "$leaving"
        fi

        log_step "now drawing with: $target"
        # Not "set <whatever came before>": the ledger knows the shell package
        # that was really in use, which is not always the one the profile named.
        log_info "undo with: $ALIAS renderer revert"
        ;;

    revert)
        leaving=""
        current=$(configured_renderer)
        renderer_is_foreign "$current" && leaving=$(renderer_config_name "$current")
        stop_foreign "" "$leaving"
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

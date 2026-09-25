# shellcheck shell=bash
# The two commands that change what draws the panel: `set`, which is plan ->
# snapshot -> apply -> verify -> rollback, and `revert`.
#
# Sourced by renderer.sh, never executed. Requires everything renderer.sh
# sources, and the other files beside this one.

renderer_set() {   # <renderer>, and $ASSUME_YES, $DRY_RUN and $FORCE
    local target previous valid r pkg tmp expect reply index failed wallpaper
    local pair p want gen thickness position f leaving name bound
    target=${1:-}
    [ -n "$target" ] || die "usage: $ALIAS renderer set <$(renderer_ids | paste -sd'|')>"

    # The configuration, merged once for everything below: the report, the
    # generated layouts and the panel's geometry all read this one file.
    #
    # Not local: the trap that removes it runs on exit, after this function
    # has returned, and would find the name gone.
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
}

renderer_revert() {
    local leaving current
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
}

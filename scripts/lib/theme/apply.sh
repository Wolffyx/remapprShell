# shellcheck shell=bash
# `apply` and `revert`: the desktop themed from the package, every key through
# the ledger, and every key put back.
#
# Sourced by theme.sh, never executed. Requires everything theme.sh sources,
# and the other files beside this one.

theme_apply() {   # with $VARIANT_ARG, $PACKAGE_ONLY and $WITH_APPEARANCE
    local variant osd_was_ours
    # A restore point before the first write outside our own directories.
    snapshot_create "before-theme" >/dev/null || die "could not take a restore point; refusing to apply"

    # Light or dark, for the applications. `--variant` overrides; without
    # it the desktop is put in whatever the shell is in.
    case "$VARIANT_ARG" in
        ""|auto) variant=$(resolve_variant) ;;
        light|dark) variant=$VARIANT_ARG ;;
        *) die "unknown variant: $VARIANT_ARG (one of: light dark auto)" ;;
    esac

    # Installing copies Plasma's Osd.qml over the silenced one, so a
    # second apply -- to add parts written since the first -- would
    # quietly bring back Plasma's OSD beside ours. The choice is kept.
    osd_was_ours=0
    grep -q 'drawn as nothing' "$LNF_DEST/contents/osd/Osd.qml" 2>/dev/null && osd_was_ours=1

    install_package "$variant" || die "package installation failed; nothing was activated"

    if [ "$osd_was_ours" = 1 ]; then
        cp -a "$LNF_SRC/contents/osd/SilentOsd.qml" "$LNF_DEST/contents/osd/Osd.qml" \
            || die "could not keep Plasma's OSD silenced"
        chmod 644 "$LNF_DEST/contents/osd/Osd.qml"
    fi

    # The desktop is themed unless it is turned off. `theme.desktop` says
    # which parts, and `--package-only` overrides the lot for the case
    # where somebody wants the package installed and nothing else touched.
    if [ "$PACKAGE_ONLY" = 1 ]; then
        log_info "package only: colour scheme, icons, widget style and the rest left alone"
    elif [ "$WITH_APPEARANCE" = 1 ] || [ "$(config_get '.theme.desktop.enabled' true)" = "true" ]; then
        apply_defaults "$variant" || die "could not write the defaults; run '$ALIAS theme revert'"
        desktop_part_wanted colours && colors_apply_scheme "$variant"
        desktop_part_wanted gtk && gtk_apply_variant "$variant"
        material_you_wanted && material_you_apply_variant "$variant"
        log_info "the desktop is in $variant (theme.mode: $(config_get '.theme.mode' 'auto'))"
    else
        log_info "leaving the desktop alone (theme.desktop.enabled is off)"
        log_info "  the shell is themed either way; --appearance applies the rest once"
    fi

    # Activating the package is what makes our OSD, splash and logout QML
    # take effect -- the one that matches the variant in force.
    kconfig_set theme kdeglobals KDE LookAndFeelPackage "$(lnf_id_for "$variant")"

    # And the pair Plasma's own day/night switch uses. This is the fix for
    # the fault that made it necessary: `AutomaticLookAndFeel` swaps the
    # whole global theme at sunset, and with nothing of ours named there it
    # swapped to Breeze and Breeze Dark -- taking the colour scheme, the
    # icons and the decorations with it, which reads as "dark did not reach
    # everywhere" rather than as another writer.
    #
    # The switch itself is left exactly as the user has it: on, it now
    # moves between our two packages; off, `theme variant` does the same
    # job. Either way nobody else decides what our desktop looks like.
    lnf_pair_apply

    # KDE caches installed packages; without this the new one is invisible
    # until the next login.
    kbuildsycoca6 --noincremental >/dev/null 2>&1 || true

    # Writing the colours is not the same as the desktop wearing them.
    # Every application already open -- KWin's titlebars included -- holds
    # the palette it read at startup and repaints only when told, which is
    # what `theme variant` has always done and this never did. Without it
    # an apply looked like it had half worked: new windows were right,
    # every window already open kept the old colours until somebody
    # clicked a scheme in System Settings, which sends this same signal.
    notify_palette_changed
    notify_style_changed

    log_step "applied"
    log_info "restart plasmashell to see it: systemctl --user restart plasma-plasmashell.service"
    log_info "undo with: $ALIAS theme revert"
}

theme_revert() {
    # The style first: its record holds what the style was after the
    # theme's own defaults, and the theme's is what gets back to the
    # user's.
    if jq -e '[.entries[] | select(.scope == "style")] | length > 0' "$(kconfig_ledger)" >/dev/null 2>&1; then
        kconfig_revert style
        notify_style_changed
    fi
    kconfig_revert theme
    colors_revert_scheme
    gtk_revert
    remove_colors

    # The colours that were put back reach the open windows the same way
    # the ones taken away did.
    notify_palette_changed
    remove_packages
    kbuildsycoca6 --noincremental >/dev/null 2>&1 || true
    log_step "reverted"
    log_info "restart plasmashell: systemctl --user restart plasma-plasmashell.service"
}

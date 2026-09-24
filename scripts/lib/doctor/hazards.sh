# shellcheck shell=bash
# Known hazards: two panels drawn at once, or none at all, another Quickshell
# drawing beside ours, shortcuts filed and never grabbed, and a tiling script
# beside KWin's snapping.
#
# A section of doctor.sh, which sources it and supplies ok, warn, bad, fix and
# section. Requires brand.sh, config.sh, renderers.sh, accel.sh and kwin.sh.

doctor_hazards() {
    local shell_pkg configured_renderer expected_pkg our_panels pkg f n foreign funit
    local others bound k legacy v tilers
    section "known hazards"

    shell_pkg=$(live_shell_package)
    if [ "$shell_pkg" = "org.kde.plasma.desktop" ] \
       || [ -d "$XDG_DATA_HOME/plasma/shells/$shell_pkg" ] \
       || [ -d "/usr/share/plasma/shells/$shell_pkg" ]; then
        ok "plasmashell's shell package '$shell_pkg' exists"
    else
        bad "plasmashell is set to '$shell_pkg', which is not installed"
        fix "on the next login plasmashell falls back to the default layout"
        fix "reinstall that package, or: kwriteconfig6 --file plasmashellrc --group Shell --key ShellPackage org.kde.plasma.desktop"
    fi

    # The headline failure mode of having two renderers: both drawing at once.
    # Counted rather than assumed, because the case that matters is the one where
    # the configuration and what is on screen have come apart.
    configured_renderer=$(config_get '.panel.renderer' quickshell)

    # A value no renderer answers to is read as ours, as it always has been here.
    expected_pkg=$(package_for "$configured_renderer")
    [ -n "$expected_pkg" ] || expected_pkg=$SHELL_PACKAGE_ID

    if [ "$shell_pkg" = "$expected_pkg" ]; then
        ok "renderer '$configured_renderer' matches plasmashell's package"
    else
        warn "configured renderer is '$configured_renderer' but plasmashell uses '$shell_pkg'"
        fix "the panel you see may not be the one configured"
        fix "re-apply it: $ALIAS renderer set $configured_renderer"
    fi

    # Every panel containment in every layout we own. More than one, or one while
    # the Quickshell panel is also drawing, is the stacked-panels bug.
    our_panels=0
    for pkg in "$SHELL_PACKAGE_ID" "$PLASMA_SHELL_PACKAGE_ID"; do
        f="$XDG_CONFIG_HOME/plasma-$pkg-appletsrc"
        [ -f "$f" ] || continue
        n=$(grep -c '^plugin=org.kde.panel$' "$f" 2>/dev/null || true)
        our_panels=$((our_panels + n))
        if [ "$pkg" = "$shell_pkg" ] && [ "$n" -gt 0 ] && [ "$configured_renderer" != "plasma" ]; then
            bad "the active layout for '$pkg' has a Plasma panel, but the renderer is '$configured_renderer'"
            fix "two panels will be drawn at the same edge"
            fix "regenerate it: $ALIAS renderer set $configured_renderer"
        fi
    done
    if [ "$our_panels" -le 1 ]; then
        ok "$our_panels panel containment(s) in the layouts we generate"
    else
        bad "$our_panels panel containments across our layouts; at most one may exist"
        fix "regenerate them: $ALIAS renderer set $configured_renderer"
    fi

    # The state a real desktop was left in: the renderer says we draw the panel,
    # and we are not running, so nothing does. plasmashell is behaving correctly
    # and the screen is empty, which is the hardest kind of fault to place.
    # Only when the quickshell renderer is actually in effect. With plasmashell on
    # some other package, something else is drawing and the mismatch warning above
    # is the finding -- reporting "no panel at all" while one is plainly on screen
    # teaches people to ignore this output.
    if [ "$configured_renderer" = "quickshell" ] && [ "$shell_pkg" = "$SHELL_PACKAGE_ID" ]; then
        if shell_running; then
            ok "the shell is running and drawing the panel"
        elif systemctl --user is-enabled "$SYSTEMD_UNIT" >/dev/null 2>&1; then
            warn "the shell is not running, so nothing is drawing a panel"
            fix "start it: $ALIAS start"
        else
            bad "the renderer is 'quickshell' but the shell is neither running nor enabled"
            fix "nothing is drawing a panel at all"
            fix "start it:            make link && $ALIAS start"
            fix "or hand it back:     $ALIAS renderer set plasma   (plasmashell draws our panel)"
            fix "or use your own:     $ALIAS renderer set none     (your stock Plasma panels)"
        fi
    fi

    # Another Quickshell shell drawing is the configuration, not a competitor, when
    # it is the one the renderer names -- and nothing at all when it is gone.
    foreign=""
    if renderer_is_foreign "$configured_renderer"; then
        foreign=$(renderer_config_name "$configured_renderer")
        funit=$(renderer_unit "$foreign")
        if [ -z "$(renderer_config_dir "$foreign")" ]; then
            bad "the renderer is '$configured_renderer', but no Quickshell configuration named $foreign is here any more"
            fix "nothing draws a panel; pick another: $ALIAS renderer list"
        elif [ "$(quickshell list -j -c "$foreign" 2>/dev/null | jq 'length' 2>/dev/null)" -gt 0 ] 2>/dev/null; then
            ok "the $foreign configuration is running and drawing the panel"
            systemctl --user is-enabled "$funit" >/dev/null 2>&1 \
                || { warn "$funit is not enabled, so $foreign will not start at the next login"
                     fix "re-apply it: $ALIAS renderer set $configured_renderer"; }
        else
            bad "the renderer is '$configured_renderer', but $foreign is not running: nothing draws a panel"
            fix "start it: systemctl --user enable --now $funit"
        fi
    fi

    others=$(other_quickshells)
    [ -n "$foreign" ] && others=$(printf '%s\n' "$others" | grep -vE -- "(-c|--config)[ =]$foreign( |\$)|/quickshell/$foreign/" || true)
    if [ -n "$others" ]; then
        warn "another Quickshell shell is running"
        printf '%s\n' "$others" | sed 's/^/        /'
        fix "both draw at once, and they compete for global shortcuts"
    else
        ok "no competing Quickshell instance"
    fi

    # A shortcut kglobalaccel has a record of but no running owner for is never
    # grabbed, and that is invisible from the file: the record is perfect. It is
    # the one failure this project spent a whole evening finding, so it is checked
    # by name.
    bound=""
    for k in "${ACCEL_ACTIONS[@]}"; do
        [ -n "$bound" ] && break
        bound=$(kreadconfig6 --file kglobalshortcutsrc --group "$SLUG" --key "$k" --default '' 2>/dev/null)
    done
    legacy=""
    for k in "${ACCEL_ACTIONS[@]}"; do
        v=$(kreadconfig6 --file kglobalshortcutsrc --group services --group "$SLUG-$k.desktop" --key _launch --default '' 2>/dev/null | cut -d, -f1)
        [ -n "$v" ] && [ "$v" != none ] && legacy="$legacy $k"
    done
    if [ -n "$legacy" ]; then
        warn "shortcuts still bound the old way:$legacy"
        fix "those are never grabbed after login; move them: $ALIAS shortcuts migrate"
    fi
    if [ -n "$bound" ] && [ "${bound%%,*}" != none ]; then
        case "$(accel_component_active "$SLUG")" in
            true)  ok "our global shortcuts have a running owner, so the keys are grabbed" ;;
            false) bad "our global shortcuts are filed but not grabbed: no owner is running"
                   fix "the session daemon owns them; start it: $ALIAS windows list" ;;
            *)     warn "kglobalaccel did not say whether our shortcuts are grabbed" ;;
        esac
    fi

    if command -v kreadconfig6 >/dev/null 2>&1; then
        tilers=$(kwin_tiling_scripts | tr '\n' ' ')
        if [ -n "$tilers" ]; then
            warn "tiling script enabled: $tilers"
            fix "it and KWin's edge snapping can both claim a window dragged to an edge;"
            fix "turn snapping off in: $ALIAS settings edges"
        else
            ok "no tiling script enabled"
        fi
    fi
}

# shellcheck shell=bash
# The lock screen: when ours is on, that it is installed, is the build that
# was tried, and still loads in Plasma's greeter.
#
# A section of doctor.sh, which sources it and supplies ok, warn, bad, fix and
# section. Requires brand.sh, lockscreen.sh and renderers.sh.

doctor_lockscreen() {
    local ls_hash p d greeter out live_pkg
    section "lock screen"

    if ! lockscreen_enabled; then
        ok "Plasma's lock screen draws; ours is off ($ALIAS lockscreen status)"
    else
        ls_hash=$(cat "$LOCKSCREEN_ENABLED")
        for p in "${LOCKSCREEN_PACKAGES[@]}"; do
            [ -d "$PLASMA_SHELLS_DIR/$p" ] || continue
            d=$(lockscreen_installed_dir "$p")
            if [ ! -f "$d/$LOCKSCREEN_MARKER" ]; then
                warn "ours is on, but not installed in $p"
                fix "put it back: $ALIAS lockscreen enable"
            elif [ "$(lockscreen_hash "$d")" != "$ls_hash" ]; then
                bad "the lock screen in $p is not the build that was tried"
                fix "take it out ($ALIAS lockscreen disable), then try and enable it again"
            fi
        done
        if greeter=$(lockscreen_greeter); then
            if [ "$(lockscreen_greeter_id "$greeter")" != "$(jq -r '.greeter // empty' "$LOCKSCREEN_MARK" 2>/dev/null)" ]; then
                warn "Plasma's greeter has changed since our lock screen was tried"
                fix "to be sure it still unlocks: $ALIAS lockscreen try"
            fi
            if out=$(lockscreen_check "$LOCKSCREEN_TRIED" 2>&1); then
                ok "ours is on, and loads in this greeter"
            else
                bad "ours is on, and does not load cleanly in this greeter:"
                printf '%s\n' "$out" | sed 's/^/        /'
                fix "the greeter draws its own when ours fails to load; to take ours out: $ALIAS lockscreen disable"
            fi
        else
            warn "ours is on, but Plasma's greeter was not found to check it with"
        fi
        live_pkg=$(live_shell_package)
        case " ${LOCKSCREEN_PACKAGES[*]} " in
            *" $live_pkg "*) ;;
            *) warn "plasmashell is on $live_pkg, so its lock screen is drawn rather than ours" ;;
        esac
    fi
}

# shellcheck shell=bash
# kde-material-you-colors: following it, when the settings ask to, by writing
# the one key it reads and restarting its unit.
#
# Sourced by theme.sh, never executed. Requires brand.sh, log.sh, kconfig.sh
# and config.sh.

# ---- kde-material-you-colors, which is not ours either --------------------
#
# A third-party service that derives a Material You colour scheme from the
# wallpaper (or a fixed seed) and applies it to the Plasma session. It has one
# `light` switch in its own config and applies MaterialYouLight or
# MaterialYouDark accordingly -- once at login, and again whenever the
# wallpaper changes.
#
# Left alone it is the last writer at every login, so `theme.mode: auto` reads
# its answer rather than the other way round: measured here on 2026-09-16,
# `light = False` applied MaterialYouDark at 09:31:16 and the whole desktop was
# dark by day with every one of this project's own settings reading light and
# correct.
#
# So following it means writing that one key and restarting the unit. Off by
# default and for the usual reason: it is somebody else's service, installed by
# somebody else's dotfiles, and a shell that quietly rewrote a config it does
# not own would be exactly the behaviour this project refuses elsewhere.
MATERIAL_YOU_CONF="kde-material-you-colors/config.conf"
MATERIAL_YOU_UNIT="kde-material-you-colors.service"

material_you_wanted() {
    [ "$(config_get '.theme.desktop.enabled' true)" = "true" ] || return 1
    [ "$(config_get '.theme.desktop.materialYou' false)" = "true" ] || return 1
    [ -f "$XDG_CONFIG_HOME/$MATERIAL_YOU_CONF" ]
}

material_you_apply_variant() {   # <light|dark>
    local variant=$1 want have

    want=$([ "$variant" = "light" ] && printf 'True' || printf 'False')
    have=$(kreadconfig6 --file "$XDG_CONFIG_HOME/$MATERIAL_YOU_CONF" \
                        --group CUSTOM --key light --default '' 2>/dev/null)

    # Its config is read by Python's configparser, which does not care that
    # kwriteconfig6 drops the spaces around the "=" the file was written with.
    # Nothing is restarted when nothing changed: a restart re-applies the
    # scheme, which wakes every Qt application on the machine.
    [ "$have" = "$want" ] && return 0

    kconfig_set theme "$MATERIAL_YOU_CONF" CUSTOM light "$want"
    log_step "kde-material-you-colors: light = $want"

    session_available || return 0
    systemctl --user cat "$MATERIAL_YOU_UNIT" >/dev/null 2>&1 || return 0
    systemctl --user restart "$MATERIAL_YOU_UNIT" >/dev/null 2>&1 \
        && log_step "restarted $MATERIAL_YOU_UNIT so it re-applies" \
        || log_warn "could not restart $MATERIAL_YOU_UNIT; its scheme follows at the next login"
}

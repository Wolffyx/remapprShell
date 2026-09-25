# shellcheck shell=bash
# Plasma's own day and night switch: naming our two packages as its halves,
# asking whether it is the one switching, and standing in when it has not
# switched, or has switched and left the colours behind.
#
# Sourced by theme.sh, never executed. Requires brand.sh, log.sh, kconfig.sh
# and config.sh -- and install.sh, defaults.sh and colours.sh.

# Names our two packages as the light and dark halves Plasma's own day/night
# switch moves between. Ledgered, so `theme revert` gives back whatever was
# there -- usually nothing, which is what makes Plasma fall back to Breeze.
lnf_pair_apply() {
    kconfig_set theme kdeglobals KDE DefaultLightLookAndFeel "$LNF_PACKAGE_ID"
    kconfig_set theme kdeglobals KDE DefaultDarkLookAndFeel "$LNF_DARK_PACKAGE_ID"
}

# Whether Plasma is the one switching light and dark, and whether it has been
# told to switch between ours. "ours", "breeze" or "off".
lnf_pair_state() {
    local auto light dark
    auto=$(kreadconfig6 --file kdeglobals --group KDE --key AutomaticLookAndFeel --default false)
    [ "$auto" = true ] || { printf 'off'; return 0; }
    light=$(kreadconfig6 --file kdeglobals --group KDE --key DefaultLightLookAndFeel --default '')
    dark=$(kreadconfig6 --file kdeglobals --group KDE --key DefaultDarkLookAndFeel --default '')
    if [ "$light" = "$LNF_PACKAGE_ID" ] && [ "$dark" = "$LNF_DARK_PACKAGE_ID" ]; then
        printf 'ours'
    else
        printf 'breeze'
    fi
}

# Plasma's day/night switch is a kded module with a timer, and a timer can
# miss. On the evening of 2026-09-22 it did: kded6 had been running since
# 09:56, a Frameworks upgrade at 10:56 replaced 130 of the libraries mapped
# into it, and sunset at 19:42 came and went with nothing written. The shell
# had turned dark at 19:13 and every application stayed light until somebody
# reloaded the module by hand.
#
# Handing the schedule to Plasma is still right -- one writer, no two clocks
# disagreeing by seconds and waking every Qt application twice for one sunset.
# What was wrong was never looking. So this looks, waits for Plasma to do its
# own job, and only writes when it is clear that nobody else will.
#
# What it writes goes through the ledger like everything else, `LookAndFeelPackage`
# included -- which is also what stops the next start from rescuing all over
# again, since that key is what Plasma's own switch compares against.
plasma_rescue() {   # plasma_rescue variant
    local variant=${1:-dark} want deadline

    if [ "$(config_get '.theme.desktop.rescuePlasmaSwitch' true)" != "true" ]; then
        log_info "Plasma's switch has not put the desktop in $variant, and rescuing it is off"
        return 0
    fi

    want=$(lnf_id_for "$variant")

    # This runs a second after the mode changed, which is the same second
    # Plasma's own switch is working in. Writing now would be a race with a
    # write that was already coming, so wait for it before concluding there
    # is none.
    deadline=$(( SECONDS + 20 ))
    while [ "$SECONDS" -lt "$deadline" ]; do
        [ "$(kreadconfig6 --file kdeglobals --group KDE --key LookAndFeelPackage --default '')" = "$want" ] \
            && { log_info "Plasma switched the desktop to $variant"; return 0; }
        sleep 1
    done

    log_warn "Plasma's own day and night switch did not fire; putting the desktop in $variant ourselves"
    apply_defaults "$variant" 1 || { log_error "could not write the $variant variant"; return 1; }
    desktop_part_wanted colours && colors_apply_scheme "$variant"
    kconfig_set theme kdeglobals KDE LookAndFeelPackage "$want"
}

# The other half of the same fault: Plasma switched, and its colours did not
# follow.
#
# `plasma_rescue` above is for Plasma not switching at all. This one is for
# Plasma switching and leaving the desktop half done -- `LookAndFeelPackage`
# and `ColorScheme` in this variant, the `[Colors:*]` groups still in the
# other. Found on the morning of 2026-09-23, on a machine started an hour after
# sunrise: every name in kdeglobals said light, every window was dark, and
# `theme variant` read the names, agreed with them and wrote nothing. Three
# separate checks -- this command's, the shell's and doctor's -- all called
# that desktop light, because all three asked the name.
#
# Which is the whole reason the colours are copied into kdeglobals at all: the
# name is a label, and `[Colors:*]` is what every Qt application reads.
#
# It costs one read when all is well. That is the price of never again calling
# a dark desktop light.
plasma_fill_colours() {   # plasma_fill_colours <light|dark>
    local variant=$1
    desktop_part_wanted colours || return 0
    # With kde-material-you-colors following, the colours on the desktop are
    # deliberately theirs and disagreeing with ours is the point.
    if material_you_wanted; then return 0; fi
    if colours_match "$variant"; then return 0; fi

    log_warn "Plasma put the $variant global theme on, but kdeglobals still holds the other variant's colours"
    colors_apply_scheme "$variant" || return 1

    # The name beside them, when it is the other variant's. Copying a scheme's
    # colours in under another scheme's name is the same fault upside down --
    # and it is one this function caused on 2026-09-23 before it did this.
    [ "$(kreadconfig6 --file kdeglobals --group General --key ColorScheme --default '')" \
        = "$SLUG-$variant" ] \
        || kconfig_set theme kdeglobals General ColorScheme "$SLUG-$variant"
}

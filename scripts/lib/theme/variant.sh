# shellcheck shell=bash
# Light or dark: which one the desktop should be in, and the `variant` command
# that puts it there.
#
# Sourced by theme.sh, never executed. Requires brand.sh, log.sh, kconfig.sh,
# config.sh and kwin.sh -- and the other files beside this one.

# `night_light_daylight`, `night_light_wait` and the rest of KWin's Night
# Light live in kwin.sh: doctor asks the same question, and one copy of it is
# one answer.

# Whether the colour scheme on the desktop right now is a dark one, by the
# luminance of the window background -- the same question `Scheme.resolveMode`
# asks of `PlasmaColors.background`.
scheme_darkness() {
    local bg r g b
    bg=$(kreadconfig6 --file kdeglobals --group "Colors:Window" --key BackgroundNormal --default '')
    IFS=, read -r r g b <<< "$bg"
    [ -n "$b" ] || { printf 'dark'; return 0; }
    if [ $(( (r * 299 + g * 587 + b * 114) / 1000 )) -lt 128 ]; then
        printf 'dark'
    else
        printf 'light'
    fi
}

# Light or dark, for the desktop. The shell answers this for itself in
# Scheme.resolveMode; this is the same question for the applications.
#
# `theme.mode` is the user's, and light and dark are answers in themselves.
# `auto` follows Night Light. With nothing to follow it answers whatever the
# desktop is already wearing -- which the caller's own "already in x" check
# then turns into doing nothing at all.
#
# It used to answer dark there, which is what the defaults file said before
# there was a light variant of it at all. That is the one guess that cannot be
# taken back: a dark written to the desktop is read back as the desktop's own
# darkness, and auto has latched on its own answer.
resolve_variant() {
    local mode
    mode=$(config_get '.theme.mode' 'auto')
    case "$mode" in
        light|dark) printf '%s' "$mode"; return 0 ;;
    esac
    case "$(night_light_wait)" in
        true)  printf 'light' ;;
        false) printf 'dark' ;;
        *)     scheme_darkness ;;
    esac
}

# Which of light and dark the applications are in.
#
# The shell recolours itself from `theme.mode` and needs nobody's
# permission; the applications read KDE's own configuration, so this
# writes the colour scheme and icon theme -- ledgered, like every other
# key this project writes -- and nothing else. The style, the Plasma
# theme, the decorations and Alt+Tab are the same either way.
theme_variant() {   # [light|dark|auto], and --if-following in $IF_FOLLOWING
    local nl variant plasma_owns colours_agree gtk_agrees want_gtk want_theme
    local material_agrees want_my plasma_named scheme_agrees
    [ -f "$LNF_DEST/contents/defaults" ] \
        || die "the look-and-feel package is not installed ($ALIAS theme apply)"

    case "${1:-}" in
        "")
            nl=$(night_light_daylight)
            printf 'theme.mode:   %s\n' "$(config_get '.theme.mode' 'auto')"
            printf 'night light:  %s\n' "$([ -n "$nl" ] && printf '%s' "$([ "$nl" = true ] && echo daylight || echo night)" || printf 'off or unavailable')"
            printf 'resolved:     %s\n' "$(resolve_variant)"
            case "$(lnf_pair_state)" in
                ours)   printf 'switched by:  Plasma, between our two packages\n' ;;
                breeze) printf 'switched by:  Plasma, but between packages that are not ours\n' ;;
                *)      printf 'switched by:  %s\n' "$([ "$(config_get '.theme.desktop.followMode' false)" = "true" ] && printf 'us (theme.desktop.followMode)' || printf 'nobody')" ;;
            esac
            printf 'colour scheme: %s\n' "$(kreadconfig6 --file kdeglobals --group General --key ColorScheme --default '<unset>')"
            printf 'icons:        %s\n' "$(kreadconfig6 --file kdeglobals --group Icons --key Theme --default '<unset>')"
            exit 0
            ;;
        auto)       variant=$(resolve_variant) ;;
        light|dark) variant=$1 ;;
        *) die "unknown variant: $1 (one of: light dark auto)" ;;
    esac

    # Who switches light and dark, and what is left for us.
    #
    # Plasma has a day/night switch of its own -- "Switch to Dark Mode at
    # Night" -- and when it is on and naming our two packages it swaps the
    # whole look-and-feel at sunset: the colour scheme, the icons, the
    # widget style, the decorations and Alt+Tab, every one of them read
    # from the package's own `defaults`. Writing those again from here is
    # a second hand on the same wheel -- the same keys, on a schedule that
    # can disagree with Plasma's by a few seconds, waking every Qt
    # application on the machine twice for one sunset.
    #
    # So when Plasma is switching, Plasma switches. This fills in only what
    # a look-and-feel package cannot carry: GTK's theme and its dark
    # preference, which live in gsettings and which Plasma never touches,
    # and our own Plasma desktop theme, whose colours are generated per
    # variant rather than shipped as two packages.
    #
    # The switch itself is never written here. It is the user's, set in
    # System Settings; `theme apply` only makes sure the two packages it
    # names are ours, so that turning it on does the right thing.
    case "$(lnf_pair_state)" in
        ours) plasma_owns=1 ;;
        *)    plasma_owns=0 ;;
    esac

    # `--if-following` is what the login unit passes. There are two reasons
    # to do anything at all: Plasma is switching and the gaps need filling,
    # or Plasma is not and the user has asked us to switch instead.
    if [ "$IF_FOLLOWING" = 1 ]; then
        if [ "$(config_get '.theme.desktop.enabled' true)" != "true" ]; then
            log_info "leaving the desktop alone (theme.desktop.enabled is off)"
            exit 0
        fi
        if [ "$plasma_owns" = 0 ] \
           && [ "$(config_get '.theme.desktop.followMode' false)" != "true" ]; then
            log_info "nothing switches light and dark here: Plasma's own switch is off and so is theme.desktop.followMode"
            exit 0
        fi
    fi

    # Called whenever night falls, and on every start, so doing nothing
    # when there is nothing to do matters: a write here wakes every Qt
    # application on the machine.
    colours_agree=1
    if desktop_part_wanted colours; then
        colours_match "$variant" || colours_agree=0
    fi

    gtk_agrees=1
    if desktop_part_wanted gtk && command -v gsettings >/dev/null 2>&1; then
        want_gtk=$([ "$variant" = "light" ] && printf 'prefer-light' || printf 'prefer-dark')
        [ "$(gsettings get "$GSETTINGS_SCHEMA" color-scheme 2>/dev/null | tr -d "'")" = "$want_gtk" ] || gtk_agrees=0

        # The theme name as well, when one is configured. Without this the
        # early exit below calls a desktop "already light" whose GTK theme
        # is the dark half of its pair -- which is the state this key was
        # added to end.
        want_theme=$(gtk_theme_for "$variant")
        if [ -n "$want_theme" ]; then
            [ "$(gsettings get "$GSETTINGS_SCHEMA" gtk-theme 2>/dev/null | tr -d "'")" = "$want_theme" ] \
                || gtk_agrees=0
        fi
    fi

    material_agrees=1
    if material_you_wanted; then
        want_my=$([ "$variant" = "light" ] && printf 'True' || printf 'False')
        [ "$(kreadconfig6 --file "$XDG_CONFIG_HOME/$MATERIAL_YOU_CONF" \
                          --group CUSTOM --key light --default '' 2>/dev/null)" = "$want_my" ] \
            || material_agrees=0
    fi
    # Whether Plasma has actually switched. This used to be assumed --
    # "Plasma writes the scheme, whether it has caught up is Plasma's
    # business" -- and the assumption held until the evening of 2026-09-22,
    # when the autoswitcher did not fire at all: kded had been running
    # since before a Frameworks upgrade replaced the libraries under it,
    # and its timer never went off at sunset. The shell turned dark, this
    # command said "the desktop is already in dark", and every application
    # stayed light. Noticing costs one read; see `plasma_rescue`.
    #
    # It is the package's *name*, and that is all it is. Whether the
    # variant's colours reached kdeglobals is a second question, asked
    # below -- on the morning of 2026-09-23 the first was yes and the
    # second no, and asking only this one is how a dark desktop was called
    # light three times over. See `plasma_fill_colours`.
    plasma_named=1
    if [ "$plasma_owns" = 1 ]; then
        [ "$(kreadconfig6 --file kdeglobals --group KDE --key LookAndFeelPackage --default '')" \
            = "$(lnf_id_for "$variant")" ] || plasma_named=0
    fi

    # Whose colour scheme is on the desktop, by name and by value. Normally
    # both must be ours; with kde-material-you-colors following, they are
    # deliberately theirs -- they apply MaterialYouLight or MaterialYouDark
    # after us and are meant to. Asking for our name there would make this
    # check fail for ever, and every start would re-apply the lot and
    # restart their unit, which wakes every Qt application on the machine.
    scheme_agrees=1
    if [ "$plasma_owns" = 1 ]; then
        [ "$plasma_named" = 1 ] || scheme_agrees=0
        if material_you_wanted; then
            [ "$material_agrees" = 1 ] || scheme_agrees=0
        else
            [ "$colours_agree" = 1 ] || scheme_agrees=0
        fi
    elif material_you_wanted; then
        scheme_agrees=$material_agrees
    else
        [ "$(kreadconfig6 --file kdeglobals --group General --key ColorScheme --default '')" \
            = "$SLUG-$variant" ] && [ "$colours_agree" = 1 ] || scheme_agrees=0
    fi

    if [ "$scheme_agrees" = 1 ] \
       && cmp -s "$REPO_ROOT/theme/colors/$SLUG-$variant.colors" "$DESKTOPTHEME_DEST/colors" 2>/dev/null \
       && [ "$gtk_agrees" = 1 ]; then
        log_info "the desktop is already in $variant"
        exit 0
    fi

    if [ "$plasma_owns" = 1 ]; then
        log_info "Plasma switches the global theme; filling in what its packages cannot carry"
        [ "$plasma_named" = 0 ] && plasma_rescue "$variant"
        # Whether Plasma switched by itself, was waited for, or was stood
        # in for above, the colours are read again here: they are the half
        # every Qt application actually draws from.
        plasma_fill_colours "$variant"
    else
        apply_defaults "$variant" 1 || die "could not write the $variant variant"

        # The scheme's own colours, not only its name.
        desktop_part_wanted colours && colors_apply_scheme "$variant"
    fi

    # And the applications that ask a portal rather than KDE.
    if desktop_part_wanted gtk; then
        gtk_apply_variant "$variant"
    else
        log_info "leaving GTK alone (theme.desktop.gtk is off)"
    fi

    material_you_wanted && material_you_apply_variant "$variant"

    # Plasma's own widgets read the desktop theme, not the colour scheme,
    # so the variant has to reach both or a light desktop keeps dark applet
    # popups. This one takes a plasmashell restart to show, which is not
    # something to do to somebody at sunset -- it is right from the next
    # start either way.
    install_desktoptheme "$variant" || die "could not recolour the desktop theme"

    # The active package follows the variant too: it is where the OSD, the
    # splash and the logout screen come from, and System Settings shows it
    # as the global theme in force. Plasma's switch writes this one itself.
    [ "$plasma_owns" = 1 ] \
        || kconfig_set theme kdeglobals KDE LookAndFeelPackage "$(lnf_id_for "$variant")"

    notify_palette_changed
    if [ "$plasma_owns" = 1 ]; then
        log_step "filled in $variant behind Plasma's switch"
    else
        log_step "the desktop is in $variant"
    fi
}

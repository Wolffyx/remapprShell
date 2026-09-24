# shellcheck shell=bash
# Light and dark: who has the last word on the colours, in KDE's configuration
# and outside it, and whether Plasma's day and night switch has done its job.
#
# A section of doctor.sh, which sources it and supplies ok, warn, bad, fix and
# section. Requires brand.sh, config.sh and kwin.sh.

# The names libadwaita and the Adwaita GTK themes actually paint with. A
# stylesheet that sets one of these decides the colour of every window; the
# `*_breeze` names kde-gtk-config generates are not among them, which is why
# `colors.css` is safe and `gtk.css` was not.
GTK_PALETTE_NAMES='window_bg_color|view_bg_color|theme_bg_color|theme_base_color|headerbar_bg_color|card_bg_color|popover_bg_color|sidebar_bg_color|accent_bg_color|dialog_bg_color'

doctor_light_dark() {
    local variant scheme_now theme_desktop theme_colours auto_lnf found dir want_bg
    local have_bg lnf_auto lnf_light lnf_dark lnf_now lnf_want want_icons have_icons
    local gtk_v gtk_css pinned imported f var val flags kd_scheme gtk_pref gtk_theme
    local named_light named_dark
    section "light and dark"

    # Who has the last word on the colour scheme. Nothing here is this project's
    # to own -- a second thing writing kdeglobals is allowed -- but it must be
    # said out loud, because the symptom is indistinguishable from this shell
    # being broken: every setting reads light and correct, and the desktop is
    # dark. Found on 2026-09-16 only by reading another service's journal.
    variant=$(config_get '.theme.mode' auto)
    scheme_now=$(kreadconfig6 --file kdeglobals --group General --key ColorScheme --default '')
    theme_desktop=$(config_get '.theme.desktop.enabled' true)
    theme_colours=$(config_get '.theme.desktop.colours' true)

    if [ "$theme_desktop" != "true" ] || [ "$theme_colours" != "true" ]; then
        ok "colour scheme left to you (theme.desktop.colours is off): $scheme_now"
    elif [ "$scheme_now" = "$SLUG-light" ] || [ "$scheme_now" = "$SLUG-dark" ]; then
        ok "colour scheme is ours: $scheme_now"
    else
        warn "the colour scheme is not ours: $scheme_now"
        fix "something else wrote it after we did, and theme.mode ($variant) reads its answer"
        if systemctl --user cat kde-material-you-colors.service >/dev/null 2>&1; then
            fix "kde-material-you-colors is installed here and applies a scheme at every login"
            fix "  it follows this shell:  turn on theme.desktop.materialYou"
            fix "  or leave it out of it:  systemctl --user disable --now kde-material-you-colors"
        fi
        fix "put ours back: $ALIAS theme variant $([ "$variant" = dark ] && echo dark || echo light)"
    fi

    # Whether light and dark are settled before the session's applications start.
    #
    # The shell settles them too, but it is late: quickshell has to load, the
    # profile has to be read and Night Light has to answer, which measured eight
    # seconds into the session. Everything XDG autostart brings up -- session
    # restore included -- starts inside that window and reads the desktop's
    # colours once. An Electron application asks the portal at startup and never
    # asks again, so one started in those eight seconds is dark for the rest of
    # the day on a desktop that is light everywhere else.
    auto_lnf=$(kreadconfig6 --file kdeglobals --group KDE --key AutomaticLookAndFeel --default false)
    if [ "$auto_lnf" != "true" ] \
       && [ "$(config_get '.theme.desktop.followMode' false)" != "true" ]; then
        ok "light and dark left where you put them (nothing switches them)"
    elif systemctl --user is-enabled "$SLUG-theme.service" >/dev/null 2>&1; then
        ok "light and dark are settled before the session's applications start"
    else
        warn "light and dark are settled eight seconds into the session, not before it"
        fix "applications started in that window -- Electron ones especially -- keep last night's colours all day"
        fix "settle it at login: systemctl --user enable $SLUG-theme.service"
    fi

    # A scheme KDE cannot resolve to a file. kdeglobals names a scheme by the base
    # name of its .colors file -- BreezeDark, not "Breeze Dark" -- and this project
    # wrote the display name there until 2026-09-16. The colours still reached
    # every application, because they are copied into kdeglobals as well, so the
    # desktop looked nearly right: System Settings said the scheme was not
    # installed and chose the default, and everything that resolves a scheme by
    # name rather than reading the copy stayed on whatever it had.
    #
    # Nearly right is the worst kind of wrong to find by eye, so it is checked.
    if [ -n "$scheme_now" ]; then
        found=""
        for dir in "$COLORS_DIR" "$XDG_DATA_HOME/color-schemes" /usr/share/color-schemes; do
            [ -f "$dir/$scheme_now.colors" ] && { found=$dir; break; }
        done
        if [ -n "$found" ]; then
            ok "the colour scheme resolves to a file: $found/$scheme_now.colors"

            # And holds that file's colours, which is a separate write again.
            #
            # kdeglobals carries both: the scheme's name under [General], and a
            # copy of its [Colors:*] groups, which is what every Qt application
            # reads. Found disagreeing on the morning of 2026-09-23 -- the name
            # said our light scheme, every group held our dark one, and every
            # window on the desktop was dark while this section said nothing.
            want_bg=$(sed -n '/^\[Colors:Window\]/,/^\[/ s/^BackgroundNormal=//p' \
                          "$found/$scheme_now.colors" 2>/dev/null | head -1 | tr -d ' ')
            have_bg=$(kreadconfig6 --file kdeglobals --group "Colors:Window" --key BackgroundNormal --default '' | tr -d ' ')
            if [ -z "$want_bg" ] || [ "$have_bg" = "$want_bg" ]; then
                :
            else
                bad "kdeglobals names '$scheme_now' and holds another scheme's colours"
                fix "the name is a label; the [Colors:*] groups copied beside it are what"
                fix "  every Qt application draws from -- so the desktop wears the copy"
                fix "'$scheme_now' paints windows $want_bg; kdeglobals says $have_bg"
                fix "put the named scheme's colours back: $ALIAS theme variant auto"
            fi
        else
            bad "kdeglobals names a colour scheme no file is called: '$scheme_now'"
            fix "KDE identifies a scheme by its file's base name, not the name it shows"
            fix "applications read the colours copied into kdeglobals and look right;"
            fix "  anything that resolves the scheme by name falls back to the default"
            fix "put ours back: $ALIAS theme apply"
        fi
    fi

    # Who switches light and dark. Plasma's own switch (kdeglobals [KDE]
    # AutomaticLookAndFeel) applies a whole *global theme* at sunset -- and with
    # nothing of ours named as its two halves it applies Breeze and Breeze Dark,
    # which replaces this project's look-and-feel package, colour scheme, icons and
    # decorations in one write. Found on 2026-09-16 with the desktop half ours and
    # half Breeze Dark, which looks exactly like a theme that did not finish
    # applying.
    lnf_auto=$(kreadconfig6 --file kdeglobals --group KDE --key AutomaticLookAndFeel --default false)
    lnf_light=$(kreadconfig6 --file kdeglobals --group KDE --key DefaultLightLookAndFeel --default '')
    lnf_dark=$(kreadconfig6 --file kdeglobals --group KDE --key DefaultDarkLookAndFeel --default '')
    lnf_now=$(kreadconfig6 --file kdeglobals --group KDE --key LookAndFeelPackage --default '')

    if [ "$theme_desktop" != "true" ]; then
        ok "day and night left to you (theme.desktop.enabled is off)"
    elif [ "$lnf_auto" != true ]; then
        ok "light and dark are ours to switch (Plasma's own switch is off)"
    elif [ "$lnf_light" = "$LNF_PACKAGE_ID" ] && [ "$lnf_dark" = "$LNF_DARK_PACKAGE_ID" ]; then
        ok "Plasma switches light and dark between our two packages"
    else
        bad "Plasma's 'Switch to Dark Mode at Night' is on and does not name ours"
        fix "at sunset it applies '${lnf_dark:-org.kde.breezedark.desktop}' over this theme -- the"
        fix "  colour scheme, the icons and the decorations go with it"
        fix "name ours as its two halves: $ALIAS theme apply"
        fix "or turn the switch off in System Settings -> Colors & Themes -> Global Theme"
    fi

    if [ "$lnf_now" = "$LNF_PACKAGE_ID" ] || [ "$lnf_now" = "$LNF_DARK_PACKAGE_ID" ]; then
        ok "the global theme in force is ours: $lnf_now"
    elif [ "$theme_desktop" = "true" ]; then
        warn "the global theme in force is not ours: ${lnf_now:-<unset>}"
        fix "put ours back: $ALIAS theme apply"
    fi

    # Plasma's switch is on, names ours, and is still wearing the wrong half. Found
    # on the evening of 2026-09-22: kded6 had been running since before a
    # Frameworks upgrade replaced the libraries mapped into it, its timer never
    # went off at sunset, and the desktop sat in light behind a dark shell for two
    # hours. Nothing in the configuration is wrong when this happens, which is why
    # it needs asking about rather than reading off a key.
    if [ "$theme_desktop" = "true" ] && [ "$lnf_auto" = true ] \
       && [ "$lnf_light" = "$LNF_PACKAGE_ID" ] && [ "$lnf_dark" = "$LNF_DARK_PACKAGE_ID" ]; then
        case "$(night_light_daylight)" in
            true)  lnf_want=$LNF_PACKAGE_ID ;;
            false) lnf_want=$LNF_DARK_PACKAGE_ID ;;
            *)     lnf_want='' ;;
        esac
        if [ -z "$lnf_want" ]; then
            :   # no schedule to check it against
        elif [ "$lnf_now" = "$lnf_want" ]; then
            ok "Plasma's switch names the right half for the hour: $lnf_now"
        else
            bad "Plasma's day and night switch has not fired: the desktop is in the wrong half"
            fix "it is a background module on a timer, and a Frameworks upgrade under a"
            fix "  running session is enough to stop it going off"
            fix "put it right now:   $ALIAS theme variant auto"
            fix "wake the module:    qdbus6 org.kde.kded6 /kded unloadModule lookandfeelautoswitcher"
            fix "                    qdbus6 org.kde.kded6 /kded loadModule lookandfeelautoswitcher"
            fix "or log out and back in, which starts it fresh"
        fi
    fi

    # The icon theme is in the package too, and a package is applied whole -- so
    # when Plasma is the one switching, the icons are Plasma's to write and not
    # ours. Checked rather than assumed, for the same reason the colours are: the
    # morning of 2026-09-23 showed that "Plasma applied the package" and "every
    # part of the package reached kdeglobals" are two different statements.
    if [ "$theme_desktop" = "true" ] && [ "$(config_get '.theme.desktop.icons' true)" = "true" ] \
       && [ -f "$PLASMA_LNF_DIR/$lnf_now/contents/defaults" ]; then
        want_icons=$(sed -n '/^\[kdeglobals\]\[Icons\]/,/^\[/ s/^Theme=//p' \
                         "$PLASMA_LNF_DIR/$lnf_now/contents/defaults" | head -1)
        have_icons=$(kreadconfig6 --file kdeglobals --group Icons --key Theme --default '')
        if [ -z "$want_icons" ] || [ "$have_icons" = "$want_icons" ]; then
            ok "the icon theme is the one the active package names: ${have_icons:-<unset>}"
        else
            warn "the icon theme is '$have_icons'; the global theme in force asks for '$want_icons'"
            fix "the package was applied and this part of it did not land"
            fix "put it right: $ALIAS theme variant auto"
        fi
    fi

    # A `gtk.css` that names the colours outright, which beats everyone.
    #
    # GTK loads `~/.config/gtk-N.0/gtk.css` last and an `@define-color` in it wins
    # over the theme, over the preference, over the portal and over us. Found on
    # 2026-09-23 with `window_bg_color #131317` in both files: every GTK 4 and
    # libadwaita application drew near-black on a light desktop, with libadwaita's
    # own dark flag reading `false` -- the application was not in dark mode, it was
    # merely painted that way, which is why nothing that asks about dark mode could
    # see it. Neither file is this project's to write; we write `settings.ini`.
    if [ "$(config_get '.theme.desktop.gtk' true)" = "true" ]; then
        for gtk_v in 3.0 4.0; do
            gtk_css="$XDG_CONFIG_HOME/gtk-$gtk_v/gtk.css"
            [ -f "$gtk_css" ] || continue
            pinned=$(grep -oE "^@define-color ($GTK_PALETTE_NAMES) +#[0-9a-fA-F]{6}" "$gtk_css" | head -1)
            [ -n "$pinned" ] || continue
            bad "gtk-$gtk_v/gtk.css paints every GTK window itself: ${pinned#@define-color }"
            fix "an \`@define-color\` there is loaded last and beats the theme, the"
            fix "  preference, the portal and this project -- the application is not in"
            fix "  dark mode, it is painted dark, so nothing that asks can tell"
            fix "this file is not ours; we write gtk-$gtk_v/settings.ini and nothing else"
            fix "take the colours out and keep the @import lines:"
            fix "  sed -i '/^@define-color /d' $gtk_css"
        done
    fi

    # The same fault one file further out: a stylesheet gtk.css pulls in.
    #
    # `colors.css`, which kde-gtk-config writes, is safe because every name in it
    # ends `_breeze` -- names only the Breeze GTK theme reads. A file that defines
    # the palette names themselves is the `gtk.css` fault wearing an @import.
    for gtk_v in 3.0 4.0; do
        gtk_css="$XDG_CONFIG_HOME/gtk-$gtk_v/gtk.css"
        [ -f "$gtk_css" ] || continue
        [ "$(config_get '.theme.desktop.gtk' true)" = "true" ] || continue
        while read -r imported; do
            [ -n "$imported" ] || continue
            case $imported in /*) f=$imported ;; *) f="$XDG_CONFIG_HOME/gtk-$gtk_v/$imported" ;; esac
            [ -f "$f" ] || continue
            pinned=$(grep -oE "^@define-color ($GTK_PALETTE_NAMES) +#[0-9a-fA-F]{6}" "$f" | head -1)
            [ -n "$pinned" ] || continue
            bad "gtk-$gtk_v/$imported sets the palette itself: ${pinned#@define-color }"
            fix "gtk.css imports it, so it lands in every GTK window the same way"
            fix "  an @define-color in gtk.css itself would -- see above"
            fix "stop importing it, or take that line out of $f"
        done <<< "$(sed -n "s/^@import *['\"]\\([^'\"]*\\)['\"].*/\\1/p" "$gtk_css")"
    done

    # Something in the session environment deciding it instead.
    #
    # These beat every file. `GTK_THEME` in particular is absolute: GTK takes it
    # over the theme name, the preference and the portal, and `GTK_THEME=x:dark`
    # is how a whole session ends up dark with nothing on disk to show for it.
    for var in GTK_THEME QT_STYLE_OVERRIDE; do
        val=$(systemctl --user show-environment 2>/dev/null | sed -n "s/^$var=//p")
        [ -n "$val" ] || continue
        bad "$var=$val is set for the whole session"
        fix "it beats every file this project writes, and every mode switch"
        fix "take it out of wherever it is set and log out and in:"
        fix "  grep -rn $var ~/.config/environment.d ~/.config/plasma-workspace/env /etc/environment"
    done

    # A browser or Electron application told to be dark on the command line.
    for flags in "$XDG_CONFIG_HOME"/*-flags.conf; do
        [ -f "$flags" ] || continue
        grep -q 'force-dark' "$flags" || continue
        warn "$(basename "$flags") forces dark mode on the command line"
        fix "that application will stay dark whatever the desktop does"
        fix "take the force-dark flag out of $flags"
    done

    # KDE keeps a second kdeglobals under `kdedefaults/`, written when a global
    # theme is applied and read *beneath* the real one. It is Plasma's, not ours,
    # and it is only reached for a key the real file does not have -- but when
    # those two disagree the desktop has two answers on disk, and the second one
    # is the one nobody thinks to look at.
    kd_scheme=$(kreadconfig6 --file "$XDG_CONFIG_HOME/kdedefaults/kdeglobals" --group General --key ColorScheme --default '')
    if [ -n "$kd_scheme" ] && [ -n "$scheme_now" ] && [ "$kd_scheme" != "$scheme_now" ]; then
        warn "kdedefaults/kdeglobals still falls back to '$kd_scheme'; the desktop is on '$scheme_now'"
        fix "Plasma writes that file when a global theme is applied; it is read beneath"
        fix "  the real kdeglobals, so it only shows when a key goes missing"
        fix "applying the theme again lines them up: $ALIAS theme apply"
    fi

    # A GTK theme whose *name* is the dark half of its pair ignores every
    # preference we write and stays dark in each mode. The preference agreeing is
    # not the same as the theme agreeing.
    if [ "$(config_get '.theme.desktop.gtk' true)" = "true" ] && command -v gsettings >/dev/null 2>&1; then
        gtk_pref=$(gsettings get org.gnome.desktop.interface color-scheme 2>/dev/null | tr -d "'")
        gtk_theme=$(gsettings get org.gnome.desktop.interface gtk-theme 2>/dev/null | tr -d "'")
        named_light=$(config_get '.theme.desktop.gtkThemeLight' "")
        named_dark=$(config_get '.theme.desktop.gtkThemeDark' "")

        if [ -n "$named_light" ] || [ -n "$named_dark" ]; then
            ok "GTK theme follows the mode: $gtk_theme ($gtk_pref)"
        elif [ "$gtk_pref" = "prefer-light" ] && printf '%s' "$gtk_theme" | grep -qi 'dark'; then
            warn "GTK prefers light but its theme is $gtk_theme"
            fix "a theme named for the dark half of its pair ignores the preference"
            fix "name both halves: theme.desktop.gtkThemeLight and .gtkThemeDark"
        else
            ok "GTK: $gtk_theme ($gtk_pref)"
        fi
    fi
}

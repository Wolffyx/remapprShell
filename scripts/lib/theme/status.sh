# shellcheck shell=bash
# `status`: what is installed and active, what an apply would write, and what
# a revert would undo -- as text, or as JSON for the settings window.
#
# Sourced by theme.sh, never executed. Requires everything theme.sh sources,
# and the other files beside this one.

theme_status() {   # --json in $WITH_JSON
    local styles part
    if [ "$WITH_JSON" = 1 ]; then
        styles=$(for s in "${STYLES[@]}"; do
                     IFS='|' read -r id key glob pkg label <<< "$s"
                     printf '%s\t%s\t%s\t%s\t%s\n' "$id" "$key" "$label" \
                         "$(style_installed "$id" && echo true || echo false)" "$(install_command "$pkg" || true)"
                 done | jq -R -s -c '[split("\n")[] | select(length > 0) | split("\t")
                                      | {id: .[0], key: .[1], label: .[2], installed: (.[3] == "true"), install: (.[4] // "")}]')
        has() { [ -e "$1" ] && echo true || echo false; }
        jq -n -c \
            --argjson package "$(has "$LNF_DEST/metadata.json")" \
            --arg active "$(kreadconfig6 --file kdeglobals --group KDE --key LookAndFeelPackage --default '')" \
            --arg lnf "$LNF_PACKAGE_ID" \
            --argjson schemes "$(ls -1 "$COLORS_DIR" 2>/dev/null | grep -c "^$SLUG-")" \
            --argjson switcher "$(has "$SWITCHER_DEST/metadata.json")" \
            --argjson desktoptheme "$(has "$DESKTOPTHEME_DEST/colors")" \
            --argjson splash "$(has "$LNF_DEST/contents/splash/Splash.qml")" \
            --arg style "$(style_active_id)" \
            --argjson styles "$styles" \
            --argjson desktop "$(for part in $(desktop_parts); do
                                    printf '%s\t%s\n' "$part" "$(desktop_part_wanted "$part" && echo true || echo false)"
                                done | jq -R -s -c 'split("\n")[] | select(length > 0) | split("\t")
                                                    | {(.[0]): (.[1] == "true")}' | jq -s -c 'add
                                                    + {enabled: '"$(config_get '.theme.desktop.enabled' true)"'}')" \
            --argjson styleCustomised "$(jq -e '[.entries[] | select(.scope == "style")] | length > 0' "$(kconfig_ledger)" >/dev/null 2>&1 && echo true || echo false)" \
            --arg variant "$(resolve_variant)" \
            --argjson followMode "$(config_get '.theme.desktop.followMode' false)" \
            --argjson gtkThemes "$(gtk_themes | jq -R -s -c 'split("\n") | map(select(length > 0))')" \
            --argjson materialYou "$([ -f "$XDG_CONFIG_HOME/$MATERIAL_YOU_CONF" ] && echo true || echo false)" \
            '{package: $package, active: ($active == $lnf),
              parts: {schemes: $schemes, switcher: $switcher, desktoptheme: $desktoptheme, splash: $splash},
              desktop: $desktop,
              variant: {resolved: $variant, follows: $followMode},
              style: $style, styles: $styles, styleCustomised: $styleCustomised,
              gtkThemes: $gtkThemes, materialYouInstalled: $materialYou}'
        exit 0
    fi
    printf 'packages:     %s\n' "$([ -d "$LNF_DEST" ] && echo "light installed" || echo "light MISSING"), $([ -d "$LNF_DARK_DEST" ] && echo "dark installed" || echo "dark MISSING")"
    printf 'active L&F:   %s\n' "$(kreadconfig6 --file kdeglobals --group KDE --key LookAndFeelPackage --default '<unset>')"
    printf 'day and night: %s\n' "$(case "$(lnf_pair_state)" in
        ours) printf "Plasma's own switch, between our two packages" ;;
        breeze) printf "Plasma's own switch, and NOT between ours -- it will replace this theme at sunset" ;;
        *) printf "ours (theme.mode), Plasma's switch is off" ;;
    esac)"
    printf 'colour:       %s\n' "$(kreadconfig6 --file kdeglobals --group General --key ColorScheme --default '<unset>')"
    printf 'our schemes:  %s installed\n' "$(ls -1 "$COLORS_DIR" 2>/dev/null | grep -c "^$SLUG-")"
    # In a subshell: without the package, osd_mode dies, and `|| true` does
    # not catch an exit -- status stopped after five lines instead of
    # carrying on without the OSD line.
    ( osd_mode status ) 2>/dev/null || true
    printf 'switcher:     %s\n' "$([ -d "$SWITCHER_DEST" ] && echo "installed" || echo "not installed")"
    printf 'active Alt+Tab: %s\n' "$(kreadconfig6 --file kwinrc --group TabBox --key LayoutName --default '<unset>')"
    printf 'icons:        %s\n' "$(kreadconfig6 --file kdeglobals --group Icons --key Theme --default '<unset>')"
    printf 'widget style: %s\n' "$(kreadconfig6 --file kdeglobals --group KDE --key widgetStyle --default '<unset>')"
    echo
    if [ "$(config_get '.theme.desktop.enabled' true)" = "true" ]; then
        echo 'themes the desktop: yes -- an apply writes these parts:'
    else
        echo 'themes the desktop: no (theme.desktop.enabled is off); an apply would write none of:'
    fi
    for part in $(desktop_parts); do
        printf '  %-12s %s\n' "$part" \
            "$(desktop_part_wanted "$part" && echo "applied" || echo "left as System Settings has it")"
    done
    printf 'light or dark: %s (theme.mode: %s)%s\n' \
        "$(resolve_variant)" "$(config_get '.theme.mode' 'auto')" \
        "$([ "$(config_get '.theme.desktop.followMode' false)" = "true" ] && printf ', and the desktop follows it' || printf '; the desktop follows it only when theme.desktop.followMode is on')"
    echo
    echo 'ledger (what revert would undo):'
    kconfig_ledger_summary theme
}

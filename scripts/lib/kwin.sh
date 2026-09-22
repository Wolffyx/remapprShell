# shellcheck shell=bash
# KWin: what it has loaded, and asking it to read its configuration again.
#
# Requires brand.sh, log.sh. Night Light needs busctl and jq.

# KWin reads kwinrc when asked to. The KWin is the user's own whatever HOME
# says, so a test must not be able to ask it.
kwin_reconfigure() {
    session_available || return 0
    qdbus6 org.kde.KWin /KWin reconfigure >/dev/null 2>&1 \
      || busctl --user call org.kde.KWin /KWin org.kde.KWin reconfigure >/dev/null 2>&1 \
      || log_warn "could not ask KWin to reload; changes apply at next login"
}

# Is the sun up, by KWin's reckoning? "true", "false", or empty for "nobody
# knows" -- which is Night Light missing, unsupported or switched off.
#
# The same three properties the shell reads, asked the same way: Plasma has no
# light/dark schedule of its own, and Night Light's is the one the user has
# already configured, so following it means the desktop and the shell cannot
# disagree about when night is.
night_light_daylight() {
    session_available || return 0
    local out
    out=$(busctl --user --json=short get-property org.kde.KWin /org/kde/KWin/NightLight \
              org.kde.KWin.NightLight available enabled daylight 2>/dev/null) || return 0
    local values
    values=$(printf '%s\n' "$out" | jq -r '.data' 2>/dev/null | paste -sd' ' -)
    case "$values" in
        "true true true")  printf 'true' ;;
        "true true false") printf 'false' ;;
        *) ;;   # unavailable, off, or an answer in a shape we do not know
    esac
}

# Tiling scripts take a window dragged to a screen edge for themselves, and so
# does KWin's own snapping: with both on, which one gets the drag depends on
# timing. Only an *enabled* one is named. Installed is not the same thing --
# doctor used to warn about every script in the directory, which meant a
# krohnkite switched off for weeks, and this project's own window-list
# script.
KWIN_TILING_SCRIPTS=(krohnkite bismuth polonium kzones)

kwin_tiling_scripts() {
    local s
    for s in "${KWIN_TILING_SCRIPTS[@]}"; do
        [ "$(kreadconfig6 --file kwinrc --group Plugins --key "${s}Enabled" --default false)" = true ] \
            && printf '%s\n' "$s"
    done
    return 0
}

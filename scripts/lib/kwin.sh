# shellcheck shell=bash
# KWin: what it has loaded, and asking it to read its configuration again.
#
# Requires brand.sh, log.sh.

# KWin reads kwinrc when asked to. The KWin is the user's own whatever HOME
# says, so a test must not be able to ask it.
kwin_reconfigure() {
    session_available || return 0
    qdbus6 org.kde.KWin /KWin reconfigure >/dev/null 2>&1 \
      || busctl --user call org.kde.KWin /KWin org.kde.KWin reconfigure >/dev/null 2>&1 \
      || log_warn "could not ask KWin to reload; changes apply at next login"
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

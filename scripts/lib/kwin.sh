# shellcheck shell=bash
# What KWin has loaded, read from its configuration.
#
# Requires brand.sh.

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

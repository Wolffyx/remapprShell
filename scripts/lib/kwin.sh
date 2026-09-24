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

# Is the sun up, by KWin's reckoning? "true", "false", or empty for "there is
# no schedule" -- which is Night Light unsupported or switched off, or no
# session to ask.
#
# Fails, printing nothing, only when KWin gave no answer at all: the call did
# not get through, or what came back was not the shape it should be. The two
# empties have to stay apart. The first is an answer, and waiting for a better
# one is five seconds on every `theme status` of a machine with Night Light
# off; the second is KWin not up yet, which is worth the wait.
#
# The same three properties the shell reads, asked the same way: Plasma has no
# light/dark schedule of its own, and Night Light's is the one the user has
# already configured, so following it means the desktop and the shell cannot
# disagree about when night is.
night_light_daylight() {
    session_available || return 0
    local out values
    out=$(busctl --user --json=short get-property org.kde.KWin /org/kde/KWin/NightLight \
              org.kde.KWin.NightLight available enabled daylight 2>/dev/null) || return 1
    values=$(jq -r '.data' <<< "$out" 2>/dev/null) || return 1
    case "${values//$'\n'/ }" in
        "true true true")  printf 'true' ;;
        "true true false") printf 'false' ;;
        *) ;;   # unavailable, off, or an answer in a shape we do not know
    esac
}

# Night Light answers over the bus, and on the login path it is asked seconds
# after KWin started -- early enough to be told nothing at all. Answering
# "no schedule" then is not neutral, so wait briefly for the real answer. Only
# for an answer, though: "no schedule" is one, and is taken at once.
night_light_wait() {   # [seconds]
    local deadline=$(( SECONDS + ${1:-5} )) answer
    while :; do
        answer=$(night_light_daylight) && { printf '%s' "$answer"; return 0; }
        [ "$SECONDS" -ge "$deadline" ] && return 0
        sleep 0.25
    done
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

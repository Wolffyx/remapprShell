#!/usr/bin/env bash
# Tests the CLI's window commands inside a throwaway HOME: KWin's window
# behaviour, and closing a window.
#
# The daemon that holds the window list is tested on its own, in
# tests/test-windowsd*.sh.
set -uo pipefail

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
source "$REPO_ROOT/tests/lib/harness.sh"
harness_init

# KWin's own window behaviour: kwinrc keys, written through the ledger. What
# matters is that a bad value never reaches kwinrc, that a write is recorded
# with what was there before, and that revert puts it back exactly -- an
# unset key deleted again rather than left empty.
echo "== KWin's window behaviour =="
BEHAVE=("$REPO_ROOT/scripts/windows.sh" behaviour)
behave() { env "$NO_SESSION_VAR=1" PATH="$FAKES:$PATH" "${BEHAVE[@]}" "$@" 2>&1; }
kwinrc_key() { kread kwinrc Windows "$1"; }

FAKES="$SANDBOX/fakes"
mkdir -p "$FAKES"
for cmd in qdbus6 busctl systemctl kquitapp6; do
    printf '#!/usr/bin/env bash\necho "$0 $*" >> %s/reached-kde.txt\nexit 0\n' "$SANDBOX" > "$FAKES/$cmd"
    chmod +x "$FAKES/$cmd"
done

check "an unknown setting is refused"    "$(behave set nosuch true >/dev/null 2>&1; echo $?)" "1"
check "a bool takes only true or false"  "$(behave set autoRaise sometimes >/dev/null 2>&1; echo $?)" "1"
check "an enum takes only its values"    "$(behave set focus Whatever >/dev/null 2>&1; echo $?)" "1"
check "a number outside the range"       "$(behave set focusDelay 99999 >/dev/null 2>&1; echo $?)" "1"
check "nothing was written by a refusal" "$(kwinrc_key FocusPolicy)" "<unset>"

behave set focus FocusFollowsMouse >/dev/null
check "focus policy written"             "$(kwinrc_key FocusPolicy)" "FocusFollowsMouse"
behave set borderlessMaximized true >/dev/null
check "borderless maximised written"     "$(kwinrc_key BorderlessMaximizedWindows)" "true"
check "status reads them back"           "$(behave status --json | jq -r '.settings[] | select(.id=="focus") | .value')" "FocusFollowsMouse"
check "and says what the default was"    "$(behave status --json | jq -r '.settings[] | select(.id=="focus") | .default')" "ClickToFocus"
check "the ledger has both"              "$(ledger_count windows-behaviour)" "2"

behave revert >/dev/null
check "revert deletes a key that was unset" "$(kwinrc_key FocusPolicy)" "<unset>"
check "and the other one too"               "$(kwinrc_key BorderlessMaximizedWindows)" "<unset>"
check "the ledger is empty again"           "$(ledger_count windows-behaviour)" "0"
check "nothing reached KDE"                 "$([ -f "$SANDBOX/reached-kde.txt" ] && cat "$SANDBOX/reached-kde.txt" || echo none)" "none"

# placeGames is a window rule, not a kwinrc key: a group of its own in
# kwinrulesrc and its id in [General] rules, beside whatever rules the person
# has made. Off and revert take out ours alone: putting the list back as it
# was before would take out a rule made since.
echo "== Steam games placed by KWin =="
GAMES="$SLUG-steam-games"
rules() { kread kwinrulesrc General rules; }
game_key() { kread kwinrulesrc "$GAMES" "$1"; }
games_status() { behave status --json | jq -r ".settings[] | select(.id==\"placeGames\") | .$1"; }

check "off until it is set"               "$(games_status value)" "false"
check "and on by default"                 "$(games_status default)" "true"
behave set placeGames true >/dev/null
check "on: the rule is listed"            "$(rules)" "$GAMES"
check "for Proton games, position ignored" \
    "$(game_key wmclass):$(game_key wmclassmatch):$(game_key ignoregeometry):$(game_key ignoregeometryrule)" \
    "steam_app_:2:true:2"
check "status reads it back"              "$(games_status value)" "true"
behave set placeGames false >/dev/null
check "off: the list is as it was"        "$(rules)" "<unset>"
check "and the group is gone"             "$(grep -c "^\[$GAMES\]" "$XDG_CONFIG_HOME/kwinrulesrc" 2>/dev/null)" "0"
check "and the ledger let go"             "$(ledger_count windows-games)" "0"

behave set placeGames true >/dev/null
kwriteconfig6 --file kwinrulesrc --group General --key rules "$GAMES,theirs"
kwriteconfig6 --file kwinrulesrc --group General --key count 2
kwriteconfig6 --file kwinrulesrc --group theirs --key Description "a rule of their own"
behave revert >/dev/null
check "revert takes out ours alone"       "$(rules)" "theirs"
check "and counts what is left"           "$(kread kwinrulesrc General count)" "1"
check "theirs is untouched"               "$(kread kwinrulesrc theirs Description)" "a rule of their own"
check "nothing of ours in the ledger"     "$(ledger_count windows-games)" "0"
check "still nothing reached KDE"         "$([ -f "$SANDBOX/reached-kde.txt" ] && cat "$SANDBOX/reached-kde.txt" || echo none)" "none"

# Snap layouts are a KWin script of ours, switched through the same table.
# On renders the whole package -- the QML and the layouts beside it -- and
# sets KWin's plugin switch through the ledger; off takes both away again.
# How the panel opens is a key in the script's own group, which stays as
# chosen when the script is turned off and goes back with a revert.
echo "== snap layouts =="
SNAP_DIR="$XDG_DATA_HOME/kwin/scripts/$SLUG-snap"
snap_status() { behave status --json | jq -r ".settings[] | select(.id==\"$1\") | .value"; }
snap_refresh() { env "$NO_SESSION_VAR=1" PATH="$FAKES:$PATH" "$REPO_ROOT/scripts/windows.sh" snap refresh 2>&1; }

check "off until it is set"               "$(snap_status snapLayouts)" "false"
check "opens near the top by default"     "$(snap_status snapReveal)" "top"
behave set snapLayouts true >/dev/null
check "on: the package is installed" \
    "$([ -f "$SNAP_DIR/contents/ui/main.qml" ] && [ -f "$SNAP_DIR/contents/ui/layouts.js" ] && echo yes)" "yes"
check "its metadata names a QML script"   "$(jq -r '.KPlugin.Id + " " + ."X-Plasma-API"' "$SNAP_DIR/metadata.json")" \
    "$SLUG-snap declarativescript"
check "no placeholder left in it"         "$(grep -rlE '@[A-Z_]+@' "$SNAP_DIR" | wc -l)" "0"
check "KWin loads it at login"            "$(kread kwinrc Plugins "$SLUG-snapEnabled")" "true"
check "status reads it back"              "$(snap_status snapLayouts)" "true"
check "a current package is left alone"   "$(snap_refresh)" ""
printf '// changed\n' >> "$SNAP_DIR/contents/ui/Flyout.qml"
snap_refresh >/dev/null
check "a stale one is installed again" \
    "$(cmp -s "$SNAP_DIR/contents/ui/Flyout.qml" "$REPO_ROOT/kwin/snap/contents/ui/Flyout.qml" && echo same)" "same"

check "a reveal it does not have is refused" "$(behave set snapReveal sideways >/dev/null 2>&1; echo $?)" "1"
behave set snapReveal drag >/dev/null
check "reveal written to its own group"   "$(kread kwinrc "Script-$SLUG-snap" Reveal)" "drag"

check "Snap Assist on until it is set"    "$(snap_status snapAssist)" "true"
check "and takes only true or false"      "$(behave set snapAssist maybe >/dev/null 2>&1; echo $?)" "1"
behave set snapAssist false >/dev/null
check "off, in the script's own group"    "$(kread kwinrc "Script-$SLUG-snap" Assist)" "false"
check "status reads Snap Assist back"     "$(snap_status snapAssist)" "false"

check "the gap is KWin's 4 until it is set" "$(snap_status tileGap)" "4"
check "and takes only 0..64"              "$(behave set tileGap 65 >/dev/null 2>&1; echo $?)" "1"
check "and no word"                       "$(behave set tileGap wide >/dev/null 2>&1; echo $?)" "1"
behave set tileGap 0 >/dev/null
check "a gap, in the script's own group"  "$(kread kwinrc "Script-$SLUG-snap" Gap)" "0"
check "status reads the gap back"         "$(snap_status tileGap)" "0"

# Meta+Z is a key of this project's, not a kwinrc key: the switch binds the
# key the defaults ship, or unbinds it, in the profile and in KDE's file, as
# `shortcuts set` and `clear` do.
SNAP_PROFILE="$XDG_CONFIG_HOME/$SLUG/profiles/default/shell.json"
check "Meta+Z on by default"              "$(snap_status snapKey)" "true"
behave set snapKey false >/dev/null
check "off: none in the profile"          "$(jq -r '.shortcuts.snap' "$SNAP_PROFILE")" "none"
check "status reads the key back"         "$(snap_status snapKey)" "false"
behave set snapKey true >/dev/null
check "on: the shipped key again"         "$(jq -r '.shortcuts.snap' "$SNAP_PROFILE")" "Meta+Z"
check "and in KDE's file, as ours"        "$(kread kglobalshortcutsrc "$SLUG" snap | cut -d, -f1)" "Meta+Z"
check "the key's command needs a session" \
    "$(env "$NO_SESSION_VAR=1" PATH="$FAKES:$PATH" "$REPO_ROOT/scripts/windows.sh" snap pick >/dev/null 2>&1; echo $?)" "1"
# The command reaches the script by the name of a KWin action the script
# registers: the two must agree, or the key does nothing and says nothing.
check "the CLI and the script name the same action" \
    "$(grep -oP '^SNAP_PICK_ACTION="\K[^"]+' "$REPO_ROOT/scripts/lib/windows/snap.sh")" \
    "$(grep -oP 'property string pickAction: "\K[^"]+' "$REPO_ROOT/kwin/snap/contents/ui/Picker.qml")"
behave set snapLayouts false >/dev/null
check "off: the package is gone"          "$([ -d "$SNAP_DIR" ] && echo there || echo gone)" "gone"
check "and KWin's switch is as it was"    "$(kread kwinrc Plugins "$SLUG-snapEnabled")" "<unset>"
check "the reveal stays as chosen"        "$(snap_status snapReveal)" "drag"
check "a refresh of nothing installed"    "$(snap_refresh; [ -d "$SNAP_DIR" ] && echo there || echo gone)" "gone"

behave set snapLayouts true >/dev/null
behave revert >/dev/null
check "revert turns it off" \
    "$([ -d "$SNAP_DIR" ] && echo there || echo gone):$(kread kwinrc Plugins "$SLUG-snapEnabled")" "gone:<unset>"
check "and puts the reveal back"          "$(kread kwinrc "Script-$SLUG-snap" Reveal)" "<unset>"
check "and Snap Assist"                   "$(kread kwinrc "Script-$SLUG-snap" Assist)" "<unset>"
check "and the gap"                       "$(kread kwinrc "Script-$SLUG-snap" Gap)" "<unset>"
check "nothing of it in the ledger"       "$(ledger_count windows-snap)" "0"
check "and still nothing reached KDE"     "$([ -f "$SANDBOX/reached-kde.txt" ] && cat "$SANDBOX/reached-kde.txt" || echo none)" "none"

# Closing a window writes the id into a KWin script's source, so anything
# that is not exactly a uuid must be refused before it gets that far -- and
# with no session, nothing may reach KWin at all.
echo "== closing a window =="
nosession() { env "$NO_SESSION_VAR=1" "$REPO_ROOT/scripts/windows.sh" "$@" 2>&1; }
out=$(nosession close 'a"); workspace.windowList().forEach(w => w.closeWindow()); ("'); status=$?
check "a script in place of an id is refused" "$status:$(printf '%s' "$out" | grep -c 'not a window id')" "1:1"
out=$(nosession close ''); status=$?
check "no id is refused"                      "$status" "1"
out=$(nosession close 1f46c057-675a-4d51-99e5-17aafdfb5b06); status=$?
check "no session, nothing closed"            "$status:$(printf '%s' "$out" | grep -c 'no session')" "1:1"

harness_done

#!/usr/bin/env bash
# Title-bar buttons, inside a throwaway HOME: what `windows titlebar` writes
# to kwinrc, that it is recorded with what was there before, and that every
# way back -- plasma, `behaviour revert`, `titlebar revert` -- puts it back
# exactly, a key that was unset deleted again rather than left empty. Then
# what a layout does with them, the switch that stops it, and how that meets
# the layout list.
#
# kwriteconfig6 and kreadconfig6 are stand-ins that write down every call and
# hand it to the real tool, which writes the sandbox's kwinrc; qdbus6, busctl
# and gdbus write down the call and make none. With the session switch off
# for the one check that asks KWin to reconfigure, so it is the stand-in
# that is asked.
set -uo pipefail

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
source "$REPO_ROOT/tests/lib/harness.sh"
harness_init

real_write=$(command -v kwriteconfig6) || { echo "  SKIP  kwriteconfig6 is not installed"; harness_done; }
real_read=$(command -v kreadconfig6) || { echo "  SKIP  kreadconfig6 is not installed"; harness_done; }

WRITES="$SANDBOX/kwriteconfig6.txt"
: > "$WRITES"
cat > "$FAKEBIN/kwriteconfig6" <<STUB
#!/usr/bin/env bash
printf '%s\n' "\$*" >> "$WRITES"
exec "$real_write" "\$@"
STUB
cat > "$FAKEBIN/kreadconfig6" <<STUB
#!/usr/bin/env bash
exec "$real_read" "\$@"
STUB
chmod +x "$FAKEBIN/kwriteconfig6" "$FAKEBIN/kreadconfig6"

KDE="$SANDBOX/reached-kde.txt"
fake_recorders "$KDE" qdbus6 busctl gdbus systemctl kquitapp6 quickshell

G=org.kde.kdecoration2
titlebar() { "$REPO_ROOT/scripts/windows.sh" titlebar "$@" 2>&1; }
preset() { "$REPO_ROOT/scripts/preset.sh" "$@" 2>&1; }
side() { kread kwinrc "$G" "ButtonsOn$1"; }
sides() { printf '%s|%s' "$(side Left)" "$(side Right)"; }
setting() { local v; v=$(jq -r "$1" "$profile" 2>/dev/null); printf '%s' "${v:-none}"; }
status() { titlebar status --json | jq -r "$1"; }
writes() { grep -c -- "--group $G" "$WRITES"; }
kwinrc="$XDG_CONFIG_HOME/kwinrc"

echo "== nothing until it is asked =="
check "plasma until it is set"              "$(status '.mode')"                     "plasma"
check "and layouts may change it"           "$(status '.fromLayouts')"              "true"
check "KWin's order unset is Breeze's"      "$(status '.kwin.left + "|" + .kwin.right')" "MS|HIAX"
titlebar apply >/dev/null
check "applying plasma writes nothing"      "$(writes)"                             "0"
check "kwinrc untouched"                    "$([ -e "$kwinrc" ] && echo there || echo absent)" "absent"

echo "== refusals =="
titlebar set sideways >/dev/null
check "an unknown choice is refused"        "$?"                                    "1"
titlebar set custom XQ "" >/dev/null
check "a letter KWin lacks is refused"      "$?"                                    "1"
titlebar set custom XI IA >/dev/null
check "a button on both sides is refused"   "$?"                                    "1"
check "and nothing was written"             "$(writes):$(setting '.windows.titleButtons // "none"')" "0:none"

echo "== left, from keys that were unset =="
titlebar set left >/dev/null
check "the setting says left"               "$(setting '.windows.titleButtons')"    "left"
check "close, minimise, maximise at left"   "$(sides)"                              "XIA|"
check "the right is written empty, not unset" "$(grep -cx 'ButtonsOnRight=' "$kwinrc")" "1"
check "both recorded as unset"              "$(jq -c '[.entries[] | select(.scope=="windows-titlebar") | .had] | unique' "$STATE_DIR/kconfig-ledger.json")" "[false]"
check "status says what was written"        "$(status '.written')"                  "true"
check "and what it wants"                   "$(status '.wanted.left + "|" + .wanted.right')" "XIA|"
n=$(writes)
titlebar set left >/dev/null
check "the same choice again writes nothing" "$(writes)"                            "$n"

echo "== right, then plasma: back to unset =="
titlebar set right >/dev/null
check "minimise, maximise, close at right"  "$(sides)"                              "|IAX"
check "the ledger still holds the first state" "$(ledger_count windows-titlebar)"  "2"
titlebar set plasma >/dev/null
check "plasma deletes both keys again"      "$(sides)"                              "<unset>|<unset>"
check "not written empty"                   "$(grep -c '^ButtonsOn' "$kwinrc")"     "0"
check "with --delete"                       "$(grep -c -- '--key ButtonsOnLeft --delete' "$WRITES")" "1"
check "the ledger let go"                   "$(ledger_count windows-titlebar)"      "0"
check "KWin was never reached"              "$(grep -c . "$KDE")"                   "0"

echo "== a custom order, over the person's own =="
"$real_write" --file kwinrc --group "$G" --key ButtonsOnLeft "M"
"$real_write" --file kwinrc --group "$G" --key ButtonsOnRight "SIAX"
titlebar set custom XAI "MF" >/dev/null
check "custom is written as given"          "$(sides)"                              "XAI|MF"
check "and kept in the profile"             "$(setting '.windows.titleButtonsLeft + "|" + .windows.titleButtonsRight')" "XAI|MF"
check "status reads the letters back"       "$(status '.left + "|" + .right')"      "XAI|MF"
titlebar set custom "" "IAX" >/dev/null
check "nothing on one side is allowed"      "$(sides)"                              "|IAX"
titlebar set plasma >/dev/null
check "plasma puts the person's own back"   "$(sides)"                              "M|SIAX"

echo "== every way back =="
titlebar set left >/dev/null
"$REPO_ROOT/scripts/windows.sh" behaviour revert >/dev/null 2>&1
check "behaviour revert puts it back"       "$(sides)"                              "M|SIAX"
check "and leaves the setting alone"        "$(setting '.windows.titleButtons')"    "left"
titlebar apply >/dev/null
check "apply writes it again from the profile" "$(sides)"                           "XIA|"
titlebar revert >/dev/null
check "titlebar revert, which an uninstall runs" "$(sides)"                         "M|SIAX"
check "nothing left in the ledger"          "$(ledger_count windows-titlebar)"      "0"

echo "== KWin is asked to reconfigure =="
: > "$KDE"
env -u "$NO_SESSION_VAR" "$REPO_ROOT/scripts/windows.sh" titlebar set right >/dev/null 2>&1
check "after a change"                      "$(cat "$KDE")"                         "qdbus6 org.kde.KWin /KWin reconfigure"
: > "$KDE"
env -u "$NO_SESSION_VAR" "$REPO_ROOT/scripts/windows.sh" titlebar set right >/dev/null 2>&1
check "and not when nothing changed"        "$(grep -c . "$KDE")"                   "0"
env -u "$NO_SESSION_VAR" "$REPO_ROOT/scripts/windows.sh" titlebar set plasma >/dev/null 2>&1
check "and after putting it back"           "$(cat "$KDE")"                         "qdbus6 org.kde.KWin /KWin reconfigure"
check "put back"                            "$(sides)"                              "M|SIAX"
: > "$KDE"

# Layouts. A shipped macOS-like one that puts the buttons on the left, one
# that says nothing about them, where the installed shell keeps them.
echo "== layouts =="
shipped="$DATA_DIR/config/presets"
mkdir -p "$shipped"
cp "$REPO_ROOT/config/presets/macos.json" "$shipped/macos.json"
printf '%s\n' '{ "name": "Bottom", "config": { "panel": { "position": "bottom" } } }' > "$shipped/bottom.json"
check "the macOS-like layout sets left"     "$(jq -r '.config.windows.titleButtons' "$shipped/macos.json")" "left"

titlebar set right >/dev/null
preset apply macos >/dev/null
check "a layout that sets them: left"       "$(setting '.windows.titleButtons')"    "left"
check "and KWin is told"                    "$(sides)"                              "XIA|"
check "the list knows the layout in use"    "$(preset list --json | jq -r '.current')" "macos"
check "what you had is kept"                "$(jq -r .titleButtons "$STATE_DIR/titlebar-before-layout.json")" "right"
preset apply bottom >/dev/null
check "the next layout puts back what you had" "$(setting '.windows.titleButtons')" "right"
check "and KWin follows"                    "$(sides)"                              "|IAX"
check "and lets go of it"                   "$([ -e "$STATE_DIR/titlebar-before-layout.json" ] && echo kept || echo gone)" "gone"
check "carried buttons are not a layout of their own" "$(preset list --json | jq -r '.state + " " + .current')" "saved bottom"
n=$(ls "$CONFIG_DIR/presets" 2>/dev/null | wc -l)
preset apply macos >/dev/null
check "so nothing was saved before the apply" "$(ls "$CONFIG_DIR/presets" 2>/dev/null | wc -l)" "$n"

echo "== a choice of your own after a layout =="
titlebar set custom X IA >/dev/null
check "your own choice"                     "$(sides)"                              "X|IA"
check "is yours now: nothing kept"          "$([ -e "$STATE_DIR/titlebar-before-layout.json" ] && echo kept || echo gone)" "gone"
preset apply bottom >/dev/null
check "and a layout that says nothing keeps it" "$(setting '.windows.titleButtons')" "custom"
check "KWin still has it"                   "$(sides)"                              "X|IA"

echo "== layouts may not change them =="
titlebar layouts false >/dev/null
check "the switch is off"                   "$(setting '.windows.titleButtonsFromLayouts')" "false"
check "the switch is no part of a layout"   "$(preset list --json | jq -r '.state + " " + .current')" "saved bottom"
before=$(sides)
preset apply macos >/dev/null
check "the macOS-like layout leaves them"   "$(setting '.windows.titleButtons')"    "custom"
check "and KWin's order"                    "$(sides)"                              "$before"
check "the switch survives the layout"      "$(setting '.windows.titleButtonsFromLayouts')" "false"
check "and nothing is kept for later"       "$([ -e "$STATE_DIR/titlebar-before-layout.json" ] && echo kept || echo gone)" "gone"
check "the rest of the layout is applied"   "$(setting '.panel.position')"          "top"
check "and, the buttons not being its to set, it is the layout in use" \
    "$(preset list --json | jq -r '.current')" "macos"
preset save "With my buttons" >/dev/null 2>&1
check "the layout is in the list already"   "$?"                                    "1"

echo "== saving a layout of your own =="
mkdir -p "$(dirname "$profile")"
printf '%s\n' '{ "schemaVersion": 2, "panel": { "thickness": 50 }, "windows": { "titleButtons": "left", "titleButtonsFromLayouts": false } }' > "$profile"
check "changed: custom"                     "$(preset list --json | jq -r '.state')" "custom"
preset save "Buttons left" >/dev/null 2>&1
saved="$CONFIG_DIR/presets/buttons-left.json"
check "keeps the buttons"                   "$(jq -r '.config.windows.titleButtons' "$saved")" "left"
check "not the switch"                      "$(jq -r '.config.windows | has("titleButtonsFromLayouts")' "$saved")" "false"
printf '%s\n' '{ "schemaVersion": 2, "windows": { "titleButtons": "left" } }' > "$profile"
check "only the buttons changed: the defaults" "$(preset list --json | jq -r '.state')" "defaults"

check "KWin was never reached outside the session checks" "$(grep -c . "$KDE")"  "0"
harness_done

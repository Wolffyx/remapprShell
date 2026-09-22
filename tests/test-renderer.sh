#!/usr/bin/env bash
# Tests the renderer switch inside a throwaway HOME.
#
# The gates this proves, all from the plan:
#
#   * switching quickshell -> plasma -> quickshell leaves `bar.entries`
#     untouched,
#   * KDE's own configuration files are byte-identical after a revert,
#   * at no point does more than one panel containment exist across the
#     layouts we generate,
#   * a widget with no Plasma applet is named before the switch, not silently
#     dropped.
#
# Nothing here may reach the live session: a throwaway HOME still shares the
# real session bus, so the no-session guard is set before anything runs. Without
# it this test would switch the shell package of the desktop it is running on.
set -uo pipefail

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)

SANDBOX=$(mktemp -d)
trap 'rm -rf "$SANDBOX"' EXIT

export HOME="$SANDBOX/home"
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_DATA_HOME="$HOME/.local/share"
export XDG_STATE_HOME="$HOME/.local/state"
# Discovery reads every XDG config directory, and /etc/xdg is the real one.
export XDG_CONFIG_DIRS="$SANDBOX/etc/xdg"
mkdir -p "$XDG_CONFIG_HOME" "$XDG_DATA_HOME" "$XDG_STATE_HOME"

source "$REPO_ROOT/scripts/lib/log.sh"
source "$REPO_ROOT/scripts/lib/brand.sh"
export "$NO_SESSION_VAR=1"

# The process list is the last piece of the live session that reached in here.
# The sandbox gives every script its own HOME, but `pgrep` still answered for
# the real machine, so "is the shell running?" depended on whether whoever ran
# the suite had `make run` going -- which is precisely when these tests are
# run. The suite says what is running, in this process and in the scripts it
# calls, and `FAKE_PROC` is the one place it says it.
export FAKE_PROC=""
mkdir -p "$SANDBOX/bin"
cat > "$SANDBOX/bin/pgrep" <<'STUB'
#!/usr/bin/env bash
[ -n "${FAKE_PROC:-}" ] && printf '%s\n' "$FAKE_PROC"
exit 0
STUB
chmod +x "$SANDBOX/bin/pgrep"
export PATH="$SANDBOX/bin:$PATH"

pass=0; fail=0
check() { if [ "$2" = "$3" ]; then printf '  PASS  %s\n' "$1"; pass=$((pass+1));
          else printf '  FAIL  %s (expected %q, got %q)\n' "$1" "$3" "$2" >&2; fail=$((fail+1)); fi; }

rmpr_renderer() { "$REPO_ROOT/scripts/renderer.sh" "$@"; }

# grep -c prints 0 and exits non-zero when it matches nothing, so the count is
# taken from its output rather than appended to by an || branch.
panels_in() { local n; n=$(grep -c '^plugin=org.kde.panel$' "$1" 2>/dev/null); printf '%s' "${n:-0}"; }
our_panels() {
    local total=0 p f
    for p in "$SHELL_PACKAGE_ID" "$PLASMA_SHELL_PACKAGE_ID"; do
        f="$XDG_CONFIG_HOME/plasma-$p-appletsrc"
        [ -f "$f" ] && total=$((total + $(panels_in "$f")))
    done
    printf '%s' "$total"
}

# --- a home that already has a Plasma desktop in it ------------------------

kwriteconfig6 --file plasmashellrc --group Shell --key ShellPackage "org.kde.plasma.desktop"
kwriteconfig6 --file plasmashellrc --group PlasmaViews --group "Panel 49" --key floating 1
kwriteconfig6 --file kdeglobals --group General --key ColorScheme "UserScheme"

# The user's own panel layout. It must come through every switch untouched:
# `org.kde.plasma.desktop` is never modified, which is what makes the switch
# non-destructive.
stock="$XDG_CONFIG_HOME/plasma-org.kde.plasma.desktop-appletsrc"
cat > "$stock" <<'STOCK'
[Containments][48]
plugin=org.kde.plasma.folder
wallpaperplugin=org.kde.image

[Containments][48][Wallpaper][org.kde.image][General]
Image=file:///home/testuser/Pictures/mine.png

[Containments][49]
plugin=org.kde.panel
location=4

[Containments][49][General]
AppletOrder=50
STOCK
stock_sum=$(sha256sum "$stock")

kde_files=(plasmashellrc kdeglobals plasma-org.kde.plasma.desktop-appletsrc)
kde_sums() { (cd "$XDG_CONFIG_HOME" && sha256sum "${kde_files[@]}" 2>/dev/null); }
before_sums=$(kde_sums)

# --- a widget index with one widget the Plasma renderer cannot draw --------

mkdir -p "$QS_CONFIG_DIR/widgets"
jq '.widgets += [{
        id: "unrenderable",
        apiVersion: 1,
        name: "Unrenderable (a widget no Plasma applet stands for)",
        zones: ["left"],
        renderers: { quickshell: { entry: "Widget.qml" } },
        config: {}
    }]' "$REPO_ROOT/shell/widgets/index.json" > "$QS_CONFIG_DIR/widgets/index.json"

# --- the user's configuration ---------------------------------------------

profile="$CONFIG_DIR/profiles/default/shell.json"
mkdir -p "$(dirname "$profile")"
cat > "$profile" <<'PROFILE'
{
    "panel": { "position": "top", "thickness": 44 },
    "bar": {
        "entries": [
            { "id": "launcher",     "zone": "left",   "enabled": true },
            { "id": "unrenderable", "zone": "left",   "enabled": true },
            { "id": "clock",        "zone": "middle", "enabled": true },
            { "id": "tray",         "zone": "right",  "enabled": true },
            { "id": "showdesktop",  "zone": "right",  "enabled": false }
        ]
    }
}
PROFILE
entries_before=$(jq -c '.bar.entries' "$profile")

echo "== before any switch =="
check "no layouts of ours yet" "$(our_panels)" "0"

echo "== set plasma =="
out=$(rmpr_renderer set plasma --yes 2>&1) || { printf '%s\n' "$out" >&2; echo "set plasma failed" >&2; exit 1; }

check "unsupported widget named"  "$(printf '%s' "$out" | grep -c 'unrenderable')" "1"
check "shell package switched"    "$(kreadconfig6 --file plasmashellrc --group Shell --key ShellPackage)" "$PLASMA_SHELL_PACKAGE_ID"
check "renderer written"          "$(jq -r '.panel.renderer' "$profile")" "plasma"
check "exactly one panel"         "$(our_panels)" "1"
check "the panel is the plasma one" "$(panels_in "$XDG_CONFIG_HOME/plasma-$PLASMA_SHELL_PACKAGE_ID-appletsrc")" "1"
check "our own package has none"  "$(panels_in "$XDG_CONFIG_HOME/plasma-$SHELL_PACKAGE_ID-appletsrc")" "0"
check "stock layout untouched"    "$(sha256sum "$stock")" "$stock_sum"

# The desktop is Plasma's in every renderer, so a switch must not redecorate
# it. The wallpaper comes from whichever package plasmashell was using.
check "wallpaper carried across"  "$(sed -n 's/^Image=//p' "$XDG_CONFIG_HOME/plasma-$PLASMA_SHELL_PACKAGE_ID-appletsrc")" "file:///home/testuser/Pictures/mine.png"

plasma_src="$XDG_CONFIG_HOME/plasma-$PLASMA_SHELL_PACKAGE_ID-appletsrc"
check "top edge"                  "$(grep -A6 '^\[Containments\]\[811\]$' "$plasma_src" | sed -n 's/^location=//p')" "3"
check "horizontal form factor"    "$(grep -A6 '^\[Containments\]\[811\]$' "$plasma_src" | sed -n 's/^formfactor=//p')" "2"
check "thickness reached the view" "$(kreadconfig6 --file plasmashellrc --group PlasmaViews --group "Panel 811" --group Defaults --key thickness)" "44"
check "panel is not immutable"    "$(grep -c '^immutability=1$' "$plasma_src")" "0"

# launcher, spacer, clock, spacer, tray -- unrenderable has no applet and
# showdesktop is disabled, so neither appears.
check "applets in zone order"     "$(sed -n 's/^AppletOrder=//p' "$plasma_src")" "820;821;822;823;824"
check "launcher first"            "$(grep -A2 '^\[Containments\]\[811\]\[Applets\]\[820\]$' "$plasma_src" | sed -n 's/^plugin=//p')" "org.kde.plasma.kickoff"
check "spacer centres the middle" "$(grep -c '^plugin=org.kde.plasma.panelspacer$' "$plasma_src")" "2"
check "clock between the spacers" "$(grep -A2 '^\[Containments\]\[811\]\[Applets\]\[822\]$' "$plasma_src" | sed -n 's/^plugin=//p')" "org.kde.plasma.digitalclock"
check "disabled widget left out"  "$(grep -c 'org.kde.plasma.showdesktop' "$plasma_src")" "0"
# What the launcher's availability check reads. Under our own renderer the
# package deliberately has no panel, so there is no launcher applet for
# plasmashell's `activateLauncherMenu` to attach a menu to -- and a start button
# that silently does nothing is what happens when something claims otherwise.
check "a launcher applet to open at" "$(grep -c '^plugin=org.kde.plasma.kickoff$' "$plasma_src")" "1"
check "and none under ours"          "$(grep -c '^plugin=org.kde.plasma.kickoff$' "$XDG_CONFIG_HOME/plasma-$SHELL_PACKAGE_ID-appletsrc")" "0"
check "both packages installed"   "$([ -f "$PLASMA_SHELLS_DIR/$SHELL_PACKAGE_ID/metadata.json" ] && [ -f "$PLASMA_SHELLS_DIR/$PLASMA_SHELL_PACKAGE_ID/metadata.json" ] && echo yes)" "yes"
# The comment in that file explains why it does not call loadTemplate, so the
# check has to look past the comments to mean anything.
check "no stock panel template"   "$(grep -vE '^\s*//' "$PLASMA_SHELLS_DIR/$PLASMA_SHELL_PACKAGE_ID/contents/layouts/org.kde.plasma.desktop-layout.js" | grep -c 'loadTemplate')" "0"

# The switch that once left a real desktop with no panel: the quickshell
# renderer's package ships no Plasma panel because our shell draws it, so
# switching to it with our shell absent leaves nothing at all.
echo "== what counts as the shell running =="
# `make run` starts the shell from a checkout, and its command line has none
# of the installed config directory in it. Matching only that directory made
# every check answer "not running" during exactly the session someone runs
# while working on the shell: status said no with a panel on screen, and
# `renderer set quickshell` refused because it believed nothing would draw.
# The replacement reads a plain variable: a local of the calling function is
# not reliably in scope by the time process substitution forks to run it.
_shell_processes() { [ -n "$FAKE_PROC" ] && printf '%s\n' "$FAKE_PROC"; return 0; }
running_with() { FAKE_PROC=$1; shell_running_from || echo none; }

check "the installed copy"    "$(running_with "42 /usr/bin/quickshell -n -p $QS_CONFIG_DIR/shell.qml")" "installed"
check "a run from a checkout" "$(running_with "42 /usr/bin/quickshell -n -p $REPO_ROOT/shell/shell.qml")" "working tree"
check "somebody else's shell" "$(running_with '42 /usr/bin/quickshell -n -p /home/other/.config/quickshell/caelestia/shell.qml')" "none"
check "nothing running"       "$(running_with '')" "none"

# The matcher above is only as true as the command line `make run` really
# execs. The first fix invented an absolute path for the test while the recipe
# still passed a relative one, so a shell started by `make run` went on
# counting as not running. Read the recipe.
run_cmd=$(grep -A2 '^\tquickshell\|quickshell -n -p' "$REPO_ROOT/Makefile" | grep -m1 'quickshell -n -p')
check "make run names the tree" "$(printf '%s' "$run_cmd" | grep -c 'CURDIR)/shell/shell.qml')" "1"
check "and not a relative path" "$(printf '%s' "$run_cmd" | grep -cE '\-p +"?shell/shell\.qml')" "0"

echo "== refusing to leave the desktop with no panel =="
FAKE_PROC=""
out=$(rmpr_renderer set quickshell --yes 2>&1)
check "refused"               "$?" "1"
check "said why"              "$(printf '%s' "$out" | grep -c 'no panel at all')" "1"
check "offered a way forward" "$(printf '%s' "$out" | grep -c 'renderer set plasma')" "1"
check "nothing was switched"  "$(kreadconfig6 --file plasmashellrc --group Shell --key ShellPackage)" "$PLASMA_SHELL_PACKAGE_ID"

# The other half of the same gate, through the script rather than the function:
# with a working-tree shell on the list it must not refuse. The fix for this
# was tested one function deep, and the command line `make run` really execs
# never reached it.
echo "== a working-tree shell satisfies the gate =="
FAKE_PROC="42 /usr/bin/quickshell -n -p $REPO_ROOT/shell/shell.qml"
out=$(rmpr_renderer set quickshell --yes 2>&1)
check "not refused"           "$(printf '%s' "$out" | grep -c 'no panel at all')" "0"
FAKE_PROC=""

echo "== back to quickshell =="
rmpr_renderer set quickshell --yes --force >/dev/null 2>&1 || { echo "set quickshell failed" >&2; exit 1; }

check "shell package back"        "$(kreadconfig6 --file plasmashellrc --group Shell --key ShellPackage)" "$SHELL_PACKAGE_ID"
check "renderer written"          "$(jq -r '.panel.renderer' "$profile")" "quickshell"
check "no panel containments"     "$(our_panels)" "0"
check "entries unchanged"         "$(jq -c '.bar.entries' "$profile")" "$entries_before"
check "stock layout still untouched" "$(sha256sum "$stock")" "$stock_sum"

echo "== a second round trip =="
rmpr_renderer set plasma --yes     >/dev/null 2>&1 || { echo "second set plasma failed" >&2; exit 1; }
check "still exactly one panel"   "$(our_panels)" "1"
rmpr_renderer set quickshell --yes --force >/dev/null 2>&1 || { echo "second set quickshell failed" >&2; exit 1; }
check "still none after"          "$(our_panels)" "0"
check "entries still unchanged"   "$(jq -c '.bar.entries' "$profile")" "$entries_before"

# Observed on a live desktop: plasmashell wrote an empty config for the package
# being switched away from, deleting a third-party shell's whole layout. The
# switch is what triggers it, so recovering from it is this project's problem
# whoever did the writing.
echo "== the outgoing layout is held and put back =="
source "$REPO_ROOT/scripts/lib/appletsrc.sh"

third_party="$XDG_CONFIG_HOME/plasma-someothershell.desktop-appletsrc"
cat > "$third_party" <<'OTHER'
[Containments][1]
plugin=org.kde.plasma.folder

[Containments][2]
plugin=org.kde.panel

[Containments][2][General]
AppletOrder=3
OTHER
before_count=$(appletsrc_containment_count "$third_party")
check "counts containments"   "$before_count" "2"

held=$(appletsrc_hold "someothershell.desktop" "$SANDBOX/held")
check "held with its count"    "${held%% *}" "2"
copy=${held#* }

# What plasmashell did: everything but the trailing section, gone.
printf '[ScreenMapping]\nitemsOnDisabledScreens=\n' > "$third_party"
check "gutted layout counted"  "$(appletsrc_containment_count "$third_party")" "0"

appletsrc_restore_if_gutted "someothershell.desktop" "$copy" "$before_count" >/dev/null 2>&1
check "layout put back"        "$(appletsrc_containment_count "$third_party")" "2"

# A layout that did not lose anything is left exactly as it is -- restoring
# unconditionally would undo a change the user made in the meantime.
printf '\n[Containments][9]\nplugin=org.kde.panel\n' >> "$third_party"
appletsrc_restore_if_gutted "someothershell.desktop" "$copy" 2 >/dev/null 2>&1
check "an intact layout is untouched" "$(appletsrc_containment_count "$third_party")" "3"

# Plasma's tray hosts volume, network, Bluetooth, battery and notifications
# inside itself. Our tray is only the StatusNotifierItems, so a panel with
# `tray` and `volume` is one volume icon to us -- and would be two under
# Plasma if both were written as applets.
echo "== applets the system tray already shows =="
index="$QS_CONFIG_DIR/widgets/index.json"
cfg="$SANDBOX/tray-panel.json"
cat > "$cfg" <<'PANEL'
{
    "panel": { "position": "bottom" },
    "bar": { "entries": [
        { "id": "volume",  "zone": "right" },
        { "id": "tray",    "zone": "right" },
        { "id": "network", "zone": "right", "enabled": false },
        { "id": "clock",   "zone": "right" }
    ] }
}
PANEL
appletsrc_generate "$SANDBOX/with-tray" "$cfg" "$index" plasma
check "not drawn beside the tray"   "$(grep -c '^plugin=org.kde.plasma.volume$' "$SANDBOX/with-tray")" "0"
check "the tray itself is there"    "$(grep -c '^plugin=org.kde.plasma.systemtray$' "$SANDBOX/with-tray")" "1"
check "named as left to the tray"   "$(appletsrc_folded_into_tray "$index" "$cfg")" "volume"
check "still a valid layout"        "$(appletsrc_validate "$SANDBOX/with-tray" yes >/dev/null 2>&1 && echo ok)" "ok"

jq '.bar.entries |= map(select(.id != "tray"))' "$cfg" > "$cfg.new" && mv "$cfg.new" "$cfg"
appletsrc_generate "$SANDBOX/no-tray" "$cfg" "$index" plasma
check "on its own without a tray"   "$(grep -c '^plugin=org.kde.plasma.volume$' "$SANDBOX/no-tray")" "1"
check "nothing left to a tray"      "$(appletsrc_folded_into_tray "$index" "$cfg")" ""

echo "== other Quickshell shells are found, not listed by hand =="
# Where quickshell itself looks: <xdg config dir>/quickshell/<name>/shell.qml,
# the user's directory first. Ours is not one of them, whatever it resolves to.
qs_user="$XDG_CONFIG_HOME/quickshell"; qs_sys="$XDG_CONFIG_DIRS/quickshell"
mkdir -p "$qs_user/fooshell" "$qs_user/notashell" "$qs_sys/barshell" "$qs_sys/fooshell"
touch "$qs_user/fooshell/shell.qml" "$qs_sys/barshell/shell.qml" "$qs_sys/fooshell/shell.qml"
ln -sfn "$REPO_ROOT/shell" "$qs_user/$(basename "$QS_CONFIG_DIR")"
ids=$(rmpr_renderer list --json | jq -r '[.[].id] | join(" ")')
check "every renderer, in order"     "$ids" "quickshell plasma quickshell:fooshell quickshell:barshell none"
check "the user's copy of a name wins" \
    "$(rmpr_renderer list --json | jq -r '.[] | select(.id == "quickshell:fooshell") | .note' | grep -c '~/.config/quickshell/fooshell')" "1"

out=$(rmpr_renderer set quickshell:nosuch --yes 2>&1)
check "an unknown one is refused"    "$?" "1"
check "and says where it looked"     "$(printf '%s' "$out" | grep -c 'no Quickshell configuration named')" "1"

rmpr_renderer set quickshell:barshell --yes >/dev/null 2>&1 || { echo "set quickshell:barshell failed" >&2; exit 1; }
check "renderer written"             "$(jq -r '.panel.renderer' "$profile")" "quickshell:barshell"
check "our package, holding no panel" "$(kreadconfig6 --file plasmashellrc --group Shell --key ShellPackage)" "$SHELL_PACKAGE_ID"
check "no panel containments"        "$(our_panels)" "0"
check "listed as in use"             "$(rmpr_renderer list --json | jq -r '.[] | select(.current) | .id')" "quickshell:barshell"

# A profile from before discovery says `caelestia`, which meant its Quickshell
# configuration. Gone from the machine, it is still what is configured.
jq '.panel.renderer = "caelestia"' "$profile" > "$profile.new" && mv "$profile.new" "$profile"
check "the old name is read as the config" "$(rmpr_renderer list --json | jq -r '.[] | select(.current) | .id')" "quickshell:caelestia"
check "and shown as gone"            "$(rmpr_renderer list --json | jq -r '.[] | select(.current) | .absent')" "true"
mkdir -p "$qs_user/caelestia" && touch "$qs_user/caelestia/shell.qml"
check "until it is back"             "$(rmpr_renderer list --json | jq -r '[.[] | select(.current)] | length, (.[0].absent // false)' | paste -sd' ')" "1 false"
rm -rf "$qs_user"/{fooshell,notashell,caelestia,"$(basename "$QS_CONFIG_DIR")"} "$SANDBOX/etc"

echo "== revert =="
rmpr_renderer revert >/dev/null 2>&1 || { echo "revert failed" >&2; exit 1; }
check "package back to stock"     "$(kreadconfig6 --file plasmashellrc --group Shell --key ShellPackage)" "org.kde.plasma.desktop"

after_sums=$(kde_sums)
if [ "$before_sums" = "$after_sums" ]; then
    printf "  PASS  KDE's own config files byte-identical after revert\n"; pass=$((pass+1))
else
    printf "  FAIL  KDE's config files differ after revert:\n" >&2
    diff <(printf '%s\n' "$before_sums") <(printf '%s\n' "$after_sums") | sed 's/^/        /' >&2
    fail=$((fail+1))
fi

echo
if [ "$fail" -gt 0 ]; then printf 'FAILED: %d passed, %d failed\n' "$pass" "$fail" >&2; exit 1; fi
printf 'OK: %d passed\n' "$pass"

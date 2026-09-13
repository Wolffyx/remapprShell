#!/usr/bin/env bash
# Tests theme apply/revert inside a throwaway HOME.
#
# The gate this proves: applying the theme and then reverting must leave every
# KDE config file byte-identical to how it started. Nothing runs against a real
# home directory.
set -uo pipefail

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)

SANDBOX=$(mktemp -d)
trap 'rm -rf "$SANDBOX"' EXIT

export HOME="$SANDBOX/home"
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_DATA_HOME="$HOME/.local/share"
export XDG_STATE_HOME="$HOME/.local/state"
mkdir -p "$XDG_CONFIG_HOME" "$XDG_DATA_HOME" "$XDG_STATE_HOME"

source "$REPO_ROOT/scripts/lib/log.sh"
source "$REPO_ROOT/scripts/lib/brand.sh"

pass=0; fail=0
check() { if [ "$2" = "$3" ]; then printf '  PASS  %s\n' "$1"; pass=$((pass+1));
          else printf '  FAIL  %s (expected %q, got %q)\n' "$1" "$3" "$2" >&2; fail=$((fail+1)); fi; }

# A home with settings already in it, including ones the theme will overwrite.
kwriteconfig6 --file kdeglobals --group General --key ColorScheme "UserScheme"
kwriteconfig6 --file kdeglobals --group Icons   --key Theme       "user-icons"
kwriteconfig6 --file kdeglobals --group KDE     --key widgetStyle "UserStyle"
kwriteconfig6 --file plasmarc   --group Theme   --key name        "user-theme"
kwriteconfig6 --file kwinrc     --group Windows --key Unrelated   "keepme"
kwriteconfig6 --file kwinrc     --group TabBox  --key LayoutName  "thumbnail_grid"

before=$(mktemp -d)
cp -a "$XDG_CONFIG_HOME/." "$before/"
# KDE's files, not ours. The gate is that reverting leaves the desktop
# byte-identical; this project's own configuration directory is ours to write
# and is removed by an uninstall, not by a theme revert.
kde_sums() { (cd "$XDG_CONFIG_HOME" && find . -type f -not -path "./$SLUG/*" | sort | xargs sha256sum); }
before_sums=$(kde_sums)

# Stand-ins for the session and for anything that installs a package: both
# must be reached by nothing here.
FAKEBIN="$SANDBOX/bin"; mkdir -p "$FAKEBIN"
CALLS="$SANDBOX/calls"; : > "$CALLS"
for t in busctl pacman sudo; do
    printf '#!/bin/sh\nprintf "%%s\\n" "%s $*" >> "%s"\n' "$t" "$CALLS" > "$FAKEBIN/$t"
    chmod +x "$FAKEBIN/$t"
done
export PATH="$FAKEBIN:$PATH"
export "$NO_SESSION_VAR=1"

# Two style plugins "installed", in a directory of the test's own.
mkdir -p "$SANDBOX/styles"
: > "$SANDBOX/styles/breeze6.so"
: > "$SANDBOX/styles/darkly6.so"
export "${ENV_PREFIX}_STYLE_DIRS=$SANDBOX/styles"

# A colour scheme of the user's own, sitting in the same directory. Our revert
# removes what we installed and nothing else -- the directory is KDE's, and
# only the files in it are ours.
mkdir -p "$COLORS_DIR"
printf '[General]\nName=Theirs\n' > "$COLORS_DIR/TheirScheme.colors"

# Choosing this shell's theme themes the desktop to match it: that is the
# default, so that the panel and the applications under it do not disagree.
# What it is allowed to touch is `theme.desktop`, part by part.
profile="$CONFIG_DIR/profiles/default/shell.json"
mkdir -p "$(dirname "$profile")"
desktop_parts_off() {   # desktop_parts_off <jq assignment>
    if [ -n "$1" ]; then printf '{ "theme": { "desktop": %s } }\n' "$1" > "$profile"
    else rm -f "$profile"; fi
}

echo "== apply (default: the desktop too) =="
desktop_parts_off ""
"$REPO_ROOT/scripts/theme.sh" apply >/dev/null 2>&1 || { echo "apply failed" >&2; exit 1; }

check "look and feel active"        "$(kreadconfig6 --file kdeglobals --group KDE --key LookAndFeelPackage)" "$LNF_PACKAGE_ID"
check "colour scheme is ours"       "$(kreadconfig6 --file kdeglobals --group General --key ColorScheme)" "$DISPLAY_NAME Dark"
check "icon theme is ours"          "$(kreadconfig6 --file kdeglobals --group Icons --key Theme)" "breeze-dark"

"$REPO_ROOT/scripts/theme.sh" revert >/dev/null 2>&1 || { echo "revert failed" >&2; exit 1; }
check "back to the user scheme"     "$(kreadconfig6 --file kdeglobals --group General --key ColorScheme)" "UserScheme"
check "and their icons"             "$(kreadconfig6 --file kdeglobals --group Icons --key Theme)" "user-icons"

echo "== a part left out keeps what System Settings says =="
desktop_parts_off '{ "colours": false }'
"$REPO_ROOT/scripts/theme.sh" apply >/dev/null 2>&1 || { echo "apply failed" >&2; exit 1; }

check "colour scheme left alone"    "$(kreadconfig6 --file kdeglobals --group General --key ColorScheme)" "UserScheme"
check "but the icons are ours"      "$(kreadconfig6 --file kdeglobals --group Icons --key Theme)" "breeze-dark"
check "and the decorations"         "$(kreadconfig6 --file kwinrc --group org.kde.kdecoration2 --key library)" "org.kde.breeze"
check "the package is still active" "$(kreadconfig6 --file kdeglobals --group KDE --key LookAndFeelPackage)" "$LNF_PACKAGE_ID"
check "status says which"           "$("$REPO_ROOT/scripts/theme.sh" status --json | jq -r '.desktop.colours')" "false"
check "and which are on"            "$("$REPO_ROOT/scripts/theme.sh" status --json | jq -r '.desktop.icons')" "true"
"$REPO_ROOT/scripts/theme.sh" revert >/dev/null 2>&1

echo "== the whole switch off writes nothing outside our own package =="
desktop_parts_off '{ "enabled": false }'
"$REPO_ROOT/scripts/theme.sh" apply >/dev/null 2>&1 || { echo "apply failed" >&2; exit 1; }

check "colour scheme untouched"     "$(kreadconfig6 --file kdeglobals --group General --key ColorScheme)" "UserScheme"
check "icons untouched"             "$(kreadconfig6 --file kdeglobals --group Icons --key Theme)" "user-icons"
check "Alt+Tab still theirs"        "$(kreadconfig6 --file kwinrc --group TabBox --key LayoutName)" "thumbnail_grid"
check "the shell is themed anyway"  "$(kreadconfig6 --file kdeglobals --group KDE --key LookAndFeelPackage)" "$LNF_PACKAGE_ID"
check "status says so"              "$("$REPO_ROOT/scripts/theme.sh" status --json | jq -r '.desktop.enabled')" "false"
"$REPO_ROOT/scripts/theme.sh" revert >/dev/null 2>&1

echo "== --package-only ignores the settings entirely =="
desktop_parts_off ""
"$REPO_ROOT/scripts/theme.sh" apply --package-only >/dev/null 2>&1 || { echo "apply failed" >&2; exit 1; }
check "nothing but the package"     "$(kreadconfig6 --file kdeglobals --group General --key ColorScheme)" "UserScheme"
check "the package is active"       "$(kreadconfig6 --file kdeglobals --group KDE --key LookAndFeelPackage)" "$LNF_PACKAGE_ID"
"$REPO_ROOT/scripts/theme.sh" revert >/dev/null 2>&1
desktop_parts_off ""

echo "== apply --appearance =="
"$REPO_ROOT/scripts/theme.sh" apply --appearance >/dev/null 2>&1 || { echo "apply failed" >&2; exit 1; }

check "package installed"     "$([ -f "$PLASMA_LNF_DIR/$LNF_PACKAGE_ID/metadata.json" ] && echo yes)" "yes"
check "our OSD shipped"       "$([ -f "$PLASMA_LNF_DIR/$LNF_PACKAGE_ID/contents/osd/Osd.qml" ] && echo yes)" "yes"
check "colour schemes shipped" "$(ls -1 "$COLORS_DIR" 2>/dev/null | grep -c "^$SLUG-")" "2"
check "switcher shipped"       "$([ -f "$KWIN_SWITCHER_DIR/$SLUG/contents/ui/main.qml" ] && echo yes)" "yes"
check "splash rendered"        "$(grep -c '@' "$PLASMA_LNF_DIR/$LNF_PACKAGE_ID/contents/splash/Splash.qml")" "0"
check "splash names the project" "$(grep -c "$DISPLAY_NAME" "$PLASMA_LNF_DIR/$LNF_PACKAGE_ID/contents/splash/Splash.qml")" "1"
check "desktop theme shipped"  "$([ -f "$PLASMA_DESKTOPTHEME_DIR/$SLUG/colors" ] && echo yes)" "yes"
check "one source of colours"  "$(cmp -s "$PLASMA_DESKTOPTHEME_DIR/$SLUG/colors" "$COLORS_DIR/$SLUG-dark.colors" && echo same)" "same"
check "desktop theme selected" "$(kreadconfig6 --file plasmarc --group Theme --key name)" "$SLUG"
check "switcher is selected"   "$(kreadconfig6 --file kwinrc --group TabBox --key LayoutName)" "$SLUG"
check "look and feel active"  "$(kreadconfig6 --file kdeglobals --group KDE --key LookAndFeelPackage)" "$LNF_PACKAGE_ID"
check "defaults applied"      "$(kreadconfig6 --file kdeglobals --group General --key ColorScheme)" "$DISPLAY_NAME Dark"
check "nested group applied"  "$(kreadconfig6 --file kwinrc --group org.kde.kdecoration2 --key library)" "org.kde.breeze"
check "unrelated key untouched" "$(kreadconfig6 --file kwinrc --group Windows --key Unrelated)" "keepme"

# Our package supplies the QML plasmashell draws for the OSD, so with it active
# there is no way to have both ours and Plasma's without seeing two. Swapping
# that one file is the whole mechanism.
echo "== which OSD draws =="
osd_file="$PLASMA_LNF_DIR/$LNF_PACKAGE_ID/contents/osd/Osd.qml"

check "Plasma's by default"    "$(grep -c 'drawn as nothing' "$osd_file")" "0"

"$REPO_ROOT/scripts/theme.sh" osd ours >/dev/null 2>&1
check "silenced for ours"      "$(grep -c 'drawn as nothing' "$osd_file")" "1"
check "the shell was told"     "$(jq -r '.osd.enabled' "$profile")" "true"
# plasmashell still drives every property on that window, so the interface has
# to survive the swap or every volume key fills the journal with errors.
check "interface kept"         "$(grep -c 'property alias osdValue' "$osd_file")" "1"

"$REPO_ROOT/scripts/theme.sh" osd plasma >/dev/null 2>&1
check "back to Plasma's"       "$(grep -c 'drawn as nothing' "$osd_file")" "0"
check "the shell was told too" "$(jq -r '.osd.enabled' "$profile")" "false"

echo "== a second apply keeps the OSD choice =="
"$REPO_ROOT/scripts/theme.sh" osd ours >/dev/null 2>&1
"$REPO_ROOT/scripts/theme.sh" apply >/dev/null 2>&1
check "still silenced after apply" "$(grep -c 'drawn as nothing' "$osd_file")" "1"
"$REPO_ROOT/scripts/theme.sh" osd plasma >/dev/null 2>&1

echo "== widget style =="
th() { "$REPO_ROOT/scripts/theme.sh" "$@"; }
tjs() { th status --json 2>/dev/null | jq -r "$1"; }
check "every part reported"          "$(tjs '[.package, .parts.switcher, .parts.desktoptheme, .parts.splash, .parts.schemes] | map(tostring) | join(",")')" "true,true,true,true,2"
check "an installed style offered"   "$(tjs '.styles[] | select(.id == "darkly") | .installed')" "true"
check "a missing one is not"         "$(tjs '.styles[] | select(.id == "union") | .installed')" "false"
check "Fusion is built into Qt"      "$(tjs '.styles[] | select(.id == "fusion") | .installed')" "true"
check "the theme's style read back"  "$(tjs .style)" "breeze"
th style darkly >/dev/null 2>&1
check "written as Qt's key"          "$(kreadconfig6 --file kdeglobals --group KDE --key widgetStyle)" "Darkly"
check "refuses one not installed"    "$(th style union >/dev/null 2>&1 && echo ran || echo refused)" "refused"
check "refuses an unknown one"       "$(th style nosuch >/dev/null 2>&1 && echo ran || echo refused)" "refused"
th style revert >/dev/null 2>&1
check "style revert keeps the theme" "$(kreadconfig6 --file kdeglobals --group KDE --key widgetStyle)" "Breeze"
check "install-style only prints"    "$(th install-style union 2>/dev/null)" "sudo pacman -S --needed union"
check "--run wants a terminal"       "$(th install-style union --run </dev/null >/dev/null 2>&1 && echo ran || echo refused)" "refused"
th style darkly >/dev/null 2>&1
check "nothing installed, nothing emitted" "$(wc -l < "$CALLS")" "0"
env -u "$NO_SESSION_VAR" "$REPO_ROOT/scripts/theme.sh" style fusion >/dev/null 2>&1
check "with a session, apps are told" "$(grep -c 'emit /KGlobalSettings' "$CALLS")" "1"

echo "== revert =="
"$REPO_ROOT/scripts/theme.sh" revert >/dev/null 2>&1 || { echo "revert failed" >&2; exit 1; }

check "package removed"            "$([ -d "$PLASMA_LNF_DIR/$LNF_PACKAGE_ID" ] && echo yes || echo no)" "no"
check "colour schemes removed"     "$(ls -1 "$COLORS_DIR" 2>/dev/null | grep -c "^$SLUG-")" "0"
check "switcher removed"           "$([ -d "$KWIN_SWITCHER_DIR/$SLUG" ] && echo yes || echo no)" "no"
check "desktop theme removed"      "$([ -d "$PLASMA_DESKTOPTHEME_DIR/$SLUG" ] && echo yes || echo no)" "no"
check "their Alt+Tab layout back"  "$(kreadconfig6 --file kwinrc --group TabBox --key LayoutName)" "thumbnail_grid"
check "user colour scheme back"    "$(kreadconfig6 --file kdeglobals --group General --key ColorScheme)" "UserScheme"
check "user icon theme back"       "$(kreadconfig6 --file kdeglobals --group Icons --key Theme)" "user-icons"
check "user widget style back"     "$(kreadconfig6 --file kdeglobals --group KDE --key widgetStyle)" "UserStyle"
check "user plasma theme back"     "$(kreadconfig6 --file plasmarc --group Theme --key name)" "user-theme"
check "their scheme untouched"     "$([ -f "$COLORS_DIR/TheirScheme.colors" ] && echo yes || echo no)" "yes"
check "L&F key removed (was unset)" "$(kreadconfig6 --file kdeglobals --group KDE --key LookAndFeelPackage --default '<unset>')" "<unset>"

# The gate: byte-identical, not merely equivalent.
after_sums=$(kde_sums)
if [ "$before_sums" = "$after_sums" ]; then
    printf '  PASS  every config file byte-identical after revert\n'; pass=$((pass+1))
else
    printf '  FAIL  config files differ after revert:\n' >&2
    diff <(printf '%s\n' "$before_sums") <(printf '%s\n' "$after_sums") | sed 's/^/        /' >&2
    fail=$((fail+1))
fi

rm -rf "$before"
echo
if [ "$fail" -gt 0 ]; then printf 'FAILED: %d passed, %d failed\n' "$pass" "$fail" >&2; exit 1; fi
printf 'OK: %d passed\n' "$pass"

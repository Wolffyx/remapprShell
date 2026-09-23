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
# GTK's preference lives in dconf, which no sandbox HOME contains, so
# gsettings is a stand-in that keeps its value in a file.
cat > "$FAKEBIN/gsettings" <<'STUB'
#!/usr/bin/env bash
store="$GSETTINGS_STORE"
case "$1" in
    get) [ -f "$store" ] && printf "'%s'\n" "$(cat "$store")" || printf "'prefer-dark'\n" ;;
    set) printf '%s' "$4" > "$store" ;;
esac
exit 0
STUB
chmod +x "$FAKEBIN/gsettings"
export GSETTINGS_STORE="$SANDBOX/gtk-color-scheme"
printf 'prefer-dark' > "$GSETTINGS_STORE"

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

check "look and feel active"        "$(kreadconfig6 --file kdeglobals --group KDE --key LookAndFeelPackage)" "$LNF_DARK_PACKAGE_ID"
check "colour scheme is ours"       "$(kreadconfig6 --file kdeglobals --group General --key ColorScheme)" "$SLUG-dark"
# KDE resolves a scheme by the base name of its file, never by the name it
# shows -- BreezeDark.colors is `Name=Breeze Dark` and `ColorScheme=BreezeDark`.
# Writing the display name into kdeglobals named a scheme no file was called:
# System Settings said it was not installed and chose the default, while the
# colours copied into kdeglobals kept most of the desktop looking right.
check "and names a file that exists"  "$([ -f "$COLORS_DIR/$(kreadconfig6 --file kdeglobals --group General --key ColorScheme).colors" ] && echo yes)" "yes"
check "the file's own id matches it"  "$(kreadconfig6 --file "$COLORS_DIR/$SLUG-dark.colors" --group General --key ColorScheme)" "$SLUG-dark"
check "and it shows a human name"     "$(kreadconfig6 --file "$COLORS_DIR/$SLUG-dark.colors" --group General --key Name)" "$DISPLAY_NAME Dark"
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
check "the package is still active" "$(kreadconfig6 --file kdeglobals --group KDE --key LookAndFeelPackage)" "$LNF_DARK_PACKAGE_ID"
check "status says which"           "$("$REPO_ROOT/scripts/theme.sh" status --json | jq -r '.desktop.colours')" "false"
check "and which are on"            "$("$REPO_ROOT/scripts/theme.sh" status --json | jq -r '.desktop.icons')" "true"
"$REPO_ROOT/scripts/theme.sh" revert >/dev/null 2>&1

echo "== the whole switch off writes nothing outside our own package =="
desktop_parts_off '{ "enabled": false }'
"$REPO_ROOT/scripts/theme.sh" apply >/dev/null 2>&1 || { echo "apply failed" >&2; exit 1; }

check "colour scheme untouched"     "$(kreadconfig6 --file kdeglobals --group General --key ColorScheme)" "UserScheme"
check "icons untouched"             "$(kreadconfig6 --file kdeglobals --group Icons --key Theme)" "user-icons"
check "Alt+Tab still theirs"        "$(kreadconfig6 --file kwinrc --group TabBox --key LayoutName)" "thumbnail_grid"
check "the shell is themed anyway"  "$(kreadconfig6 --file kdeglobals --group KDE --key LookAndFeelPackage)" "$LNF_DARK_PACKAGE_ID"
check "status says so"              "$("$REPO_ROOT/scripts/theme.sh" status --json | jq -r '.desktop.enabled')" "false"
"$REPO_ROOT/scripts/theme.sh" revert >/dev/null 2>&1

echo "== --package-only ignores the settings entirely =="
desktop_parts_off ""
"$REPO_ROOT/scripts/theme.sh" apply --package-only >/dev/null 2>&1 || { echo "apply failed" >&2; exit 1; }
check "nothing but the package"     "$(kreadconfig6 --file kdeglobals --group General --key ColorScheme)" "UserScheme"
check "the package is active"       "$(kreadconfig6 --file kdeglobals --group KDE --key LookAndFeelPackage)" "$LNF_DARK_PACKAGE_ID"
"$REPO_ROOT/scripts/theme.sh" revert >/dev/null 2>&1
desktop_parts_off ""

echo "== apply --appearance =="
"$REPO_ROOT/scripts/theme.sh" apply --appearance >/dev/null 2>&1 || { echo "apply failed" >&2; exit 1; }

check "package installed"     "$([ -f "$PLASMA_LNF_DIR/$LNF_PACKAGE_ID/metadata.json" ] && echo yes)" "yes"
check "our OSD shipped"       "$([ -f "$PLASMA_LNF_DIR/$LNF_PACKAGE_ID/contents/osd/Osd.qml" ] && echo yes)" "yes"
# Two packages, because Plasma's own day/night switch moves the whole global
# theme between two named ones -- and with ours not named there it moved to
# Breeze and Breeze Dark at sunset, taking the colour scheme and the icons with
# it. Each carries its own variant's lines and none of the other's: a defaults
# file with both in it ends with whichever comes last.
check "the dark package too"  "$([ -f "$PLASMA_LNF_DIR/$LNF_DARK_PACKAGE_ID/metadata.json" ] && echo yes)" "yes"
check "light package: light colours only" \
      "$(grep -c "ColorScheme=$SLUG-light" "$PLASMA_LNF_DIR/$LNF_PACKAGE_ID/contents/defaults")" "1"
check "and no dark line in it" \
      "$(grep -c "ColorScheme=$SLUG-dark" "$PLASMA_LNF_DIR/$LNF_PACKAGE_ID/contents/defaults")" "0"
check "dark package: dark colours only" \
      "$(grep -c "ColorScheme=$SLUG-dark" "$PLASMA_LNF_DIR/$LNF_DARK_PACKAGE_ID/contents/defaults")" "1"
check "each names itself"     "$(jq -r '.KPlugin.Id' "$PLASMA_LNF_DIR/$LNF_DARK_PACKAGE_ID/metadata.json")" "$LNF_DARK_PACKAGE_ID"
# The scheme inside the package, not only named in its defaults. Measured on
# Plasma 6.7: `plasma-apply-lookandfeel` writes every other line of the
# defaults and leaves the colour scheme alone unless the package carries a
# `contents/colors` -- which would leave the night switch moving the icons to
# dark and the colours to nothing.
check "the light package carries its colours" \
      "$(kreadconfig6 --file "$PLASMA_LNF_DIR/$LNF_PACKAGE_ID/contents/colors" --group General --key ColorScheme)" "$SLUG-light"
check "and the dark one carries its own" \
      "$(kreadconfig6 --file "$PLASMA_LNF_DIR/$LNF_DARK_PACKAGE_ID/contents/colors" --group General --key ColorScheme)" "$SLUG-dark"
check "and has a name of its own" \
      "$(jq -r '.KPlugin.Name' "$PLASMA_LNF_DIR/$LNF_DARK_PACKAGE_ID/metadata.json")" "$DISPLAY_NAME (dark)"

# Plasma's switch is told to move between ours rather than Breeze's.
check "the light half is ours" \
      "$(kreadconfig6 --file kdeglobals --group KDE --key DefaultLightLookAndFeel)" "$LNF_PACKAGE_ID"
check "the dark half is ours" \
      "$(kreadconfig6 --file kdeglobals --group KDE --key DefaultDarkLookAndFeel)" "$LNF_DARK_PACKAGE_ID"
check "colour schemes shipped" "$(ls -1 "$COLORS_DIR" 2>/dev/null | grep -c "^$SLUG-")" "2"
check "switcher shipped"       "$([ -f "$KWIN_SWITCHER_DIR/$SLUG/contents/ui/main.qml" ] && echo yes)" "yes"
# The design draws Alt+Tab three ways and a layout inside kwin_wayland cannot
# read our configuration, so each way is its own package and picking one is
# picking a package.
check "three layouts installed" "$(ls -1d "$KWIN_SWITCHER_DIR/$SLUG" "$KWIN_SWITCHER_DIR/$SLUG-grid" "$KWIN_SWITCHER_DIR/$SLUG-icons" 2>/dev/null | wc -l)" "3"
check "each says which it is"  "$(grep -l 'property string layout: "grid"' "$KWIN_SWITCHER_DIR/$SLUG-grid/contents/ui/main.qml" >/dev/null && echo yes)" "yes"
check "and none is a template" "$(grep -c '@SWITCHER' "$KWIN_SWITCHER_DIR/$SLUG-icons/contents/ui/main.qml")" "0"
check "named apart in KWin"    "$(jq -r '.KPlugin.Name' "$KWIN_SWITCHER_DIR/$SLUG-icons/metadata.json")" "$DISPLAY_NAME (icons)"
check "splash rendered"        "$(grep -c '@' "$PLASMA_LNF_DIR/$LNF_PACKAGE_ID/contents/splash/Splash.qml")" "0"
check "splash names the project" "$(grep -c "$DISPLAY_NAME" "$PLASMA_LNF_DIR/$LNF_PACKAGE_ID/contents/splash/Splash.qml")" "1"
check "desktop theme shipped"  "$([ -f "$PLASMA_DESKTOPTHEME_DIR/$SLUG/colors" ] && echo yes)" "yes"
check "one source of colours"  "$(cmp -s "$PLASMA_DESKTOPTHEME_DIR/$SLUG/colors" "$COLORS_DIR/$SLUG-dark.colors" && echo same)" "same"
check "desktop theme selected" "$(kreadconfig6 --file plasmarc --group Theme --key name)" "$SLUG"
check "switcher is selected"   "$(kreadconfig6 --file kwinrc --group TabBox --key LayoutName)" "$SLUG"
check "look and feel active"  "$(kreadconfig6 --file kdeglobals --group KDE --key LookAndFeelPackage)" "$LNF_DARK_PACKAGE_ID"
check "defaults applied"      "$(kreadconfig6 --file kdeglobals --group General --key ColorScheme)" "$SLUG-dark"
check "nested group applied"  "$(kreadconfig6 --file kwinrc --group org.kde.kdecoration2 --key library)" "org.kde.breeze"
check "unrelated key untouched" "$(kreadconfig6 --file kwinrc --group Windows --key Unrelated)" "keepme"

# Our package supplies the QML plasmashell draws for the OSD, so with it active
# there is no way to have both ours and Plasma's without seeing two. Swapping
# that one file is the whole mechanism.
# `theme.mode` decides which of light and dark the applications are put in,
# and with `auto` it is Night Light that decides -- absent in this sandbox, so
# dark, which is what the defaults file said before there was a light variant.
echo "== light and dark, for the applications =="
mode() {   # mode <jq value for theme.mode, or empty to remove>
    if [ -n "$1" ]; then printf '{ "theme": { "mode": %s } }\n' "$1" > "$profile"
    else rm -f "$profile"; fi
}

check "auto with no schedule is dark" "$("$REPO_ROOT/scripts/theme.sh" variant | sed -n 's/^resolved: *//p')" "dark"
mode '"light"'
check "the setting is the answer"     "$("$REPO_ROOT/scripts/theme.sh" variant | sed -n 's/^resolved: *//p')" "light"

"$REPO_ROOT/scripts/theme.sh" variant light >/dev/null 2>&1
check "the light scheme is written"   "$(kreadconfig6 --file kdeglobals --group General --key ColorScheme)" "$SLUG-light"
check "and light icons"               "$(kreadconfig6 --file kdeglobals --group Icons --key Theme)" "breeze"
check "Plasma's widgets too"          "$(cmp -s "$PLASMA_DESKTOPTHEME_DIR/$SLUG/colors" "$COLORS_DIR/$SLUG-light.colors" && echo same)" "same"
# The style, the Plasma theme, the decorations and Alt+Tab are the same either
# way, and a variant switch must not churn them.
check "the style is not rewritten"    "$(kreadconfig6 --file kdeglobals --group KDE --key widgetStyle)" "Breeze"
check "nor Alt+Tab"                   "$(kreadconfig6 --file kwinrc --group TabBox --key LayoutName)" "$SLUG"

check "asking again does nothing"     "$("$REPO_ROOT/scripts/theme.sh" variant light 2>&1 | grep -c 'already in light')" "1"

"$REPO_ROOT/scripts/theme.sh" variant dark >/dev/null 2>&1
check "and back to dark"              "$(kreadconfig6 --file kdeglobals --group General --key ColorScheme)" "$SLUG-dark"
check "with dark icons"               "$(kreadconfig6 --file kdeglobals --group Icons --key Theme)" "breeze-dark"

check "a variant nobody has"          "$("$REPO_ROOT/scripts/theme.sh" variant sideways >/dev/null 2>&1 && echo ran || echo refused)" "refused"
check "status carries it"             "$("$REPO_ROOT/scripts/theme.sh" status --json | jq -r '.variant.resolved')" "light"
check "and whether it follows"        "$("$REPO_ROOT/scripts/theme.sh" status --json | jq -r '.variant.follows')" "false"

# An apply in light leaves the desktop in light, not in whatever the file
# happens to list first.
mode '"light"'
"$REPO_ROOT/scripts/theme.sh" apply >/dev/null 2>&1
check "an apply follows the mode"     "$(kreadconfig6 --file kdeglobals --group General --key ColorScheme)" "$SLUG-light"
check "--variant overrides it"        "$("$REPO_ROOT/scripts/theme.sh" apply --variant dark >/dev/null 2>&1; kreadconfig6 --file kdeglobals --group General --key ColorScheme)" "$SLUG-dark"
mode ""
"$REPO_ROOT/scripts/theme.sh" apply >/dev/null 2>&1
check "back to dark by default"       "$(kreadconfig6 --file kdeglobals --group General --key ColorScheme)" "$SLUG-dark"

# Plasma's own day/night switch writes the global theme's *name*. The colours
# in kdeglobals are a second write, and on the morning of 2026-09-23 the
# desktop had the first without the second: `LookAndFeelPackage` and
# `ColorScheme` both said light, every `[Colors:*]` group still held the dark
# scheme's values, and every Qt application drew dark. The name was all this
# command asked, so it agreed with Plasma and wrote nothing at all.
echo "== Plasma switched the name and the colours did not follow =="
bg_of() { sed -n '/^\[Colors:Window\]/,/^\[/ s/^BackgroundNormal=//p' "$COLORS_DIR/$SLUG-$1.colors" | head -1; }
light_bg=$(bg_of light); dark_bg=$(bg_of dark)

"$REPO_ROOT/scripts/theme.sh" variant dark >/dev/null 2>&1
kwriteconfig6 --file kdeglobals --group KDE --key AutomaticLookAndFeel true
kwriteconfig6 --file kdeglobals --group KDE --key LookAndFeelPackage "$LNF_PACKAGE_ID"
check "the two halves are ours"      "$("$REPO_ROOT/scripts/theme.sh" variant | sed -n 's/^switched by: *//p')" "Plasma, between our two packages"
check "and the colours are the other half" "$(kreadconfig6 --file kdeglobals --group "Colors:Window" --key BackgroundNormal)" "$dark_bg"

half=$("$REPO_ROOT/scripts/theme.sh" variant light 2>&1)
check "a half-done switch is not 'already light'" "$(printf '%s\n' "$half" | grep -c 'already in light')" "0"
check "it says which half is missing"             "$(printf '%s\n' "$half" | grep -c 'still holds the other')" "1"
check "and the light colours land"                "$(kreadconfig6 --file kdeglobals --group "Colors:Window" --key BackgroundNormal)" "$light_bg"
check "once they have, it does nothing"           "$("$REPO_ROOT/scripts/theme.sh" variant light 2>&1 | grep -c 'already in light')" "1"

# The part's own switch still holds: colours off means colours left alone,
# whoever is switching.
desktop_parts_off '{ "colours": false }'
kwriteconfig6 --file kdeglobals --group KDE --key LookAndFeelPackage "$LNF_DARK_PACKAGE_ID"
"$REPO_ROOT/scripts/theme.sh" variant dark >/dev/null 2>&1
check "colours off leaves them alone"             "$(kreadconfig6 --file kdeglobals --group "Colors:Window" --key BackgroundNormal)" "$light_bg"
desktop_parts_off ""

kwriteconfig6 --file kdeglobals --group KDE --key AutomaticLookAndFeel --delete

# Chrome, Electron and GTK applications ask a portal rather than KDE, and the
# GTK portal answers from dconf. A light colour scheme with that left alone is
# what "dark mode is active globally" was.
echo "== GTK follows the variant too =="
mode '"light"'
"$REPO_ROOT/scripts/theme.sh" variant light >/dev/null 2>&1
check "GTK asked for light"       "$(cat "$GSETTINGS_STORE")" "prefer-light"
check "and the GTK 3 ini says so" "$(kreadconfig6 --file gtk-3.0/settings.ini --group Settings --key gtk-application-prefer-dark-theme)" "false"
check "and GTK 4's"               "$(kreadconfig6 --file gtk-4.0/settings.ini --group Settings --key gtk-application-prefer-dark-theme)" "false"

"$REPO_ROOT/scripts/theme.sh" variant dark >/dev/null 2>&1
check "and dark, when dark"       "$(cat "$GSETTINGS_STORE")" "prefer-dark"
check "the ini too"               "$(kreadconfig6 --file gtk-3.0/settings.ini --group Settings --key gtk-application-prefer-dark-theme)" "true"

# The part has a switch of its own, like every other part.
desktop_parts_off '{ "gtk": false }'
printf 'prefer-dark' > "$GSETTINGS_STORE"
"$REPO_ROOT/scripts/theme.sh" variant light >/dev/null 2>&1
check "off leaves GTK alone"      "$(cat "$GSETTINGS_STORE")" "prefer-dark"
desktop_parts_off ""
mode ""

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
check "and its other layouts"      "$(ls -1d "$KWIN_SWITCHER_DIR/$SLUG"* 2>/dev/null | wc -l)" "0"
check "desktop theme removed"      "$([ -d "$PLASMA_DESKTOPTHEME_DIR/$SLUG" ] && echo yes || echo no)" "no"
check "their Alt+Tab layout back"  "$(kreadconfig6 --file kwinrc --group TabBox --key LayoutName)" "thumbnail_grid"
check "user colour scheme back"    "$(kreadconfig6 --file kdeglobals --group General --key ColorScheme)" "UserScheme"
check "user icon theme back"       "$(kreadconfig6 --file kdeglobals --group Icons --key Theme)" "user-icons"
check "user widget style back"     "$(kreadconfig6 --file kdeglobals --group KDE --key widgetStyle)" "UserStyle"
check "user plasma theme back"     "$(kreadconfig6 --file plasmarc --group Theme --key name)" "user-theme"
check "their scheme untouched"     "$([ -f "$COLORS_DIR/TheirScheme.colors" ] && echo yes || echo no)" "yes"
check "GTK's preference back"      "$(cat "$GSETTINGS_STORE")" "prefer-dark"
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

#!/usr/bin/env bash
# Tests theme apply/revert inside a throwaway HOME.
#
# The gate this proves: applying the theme and then reverting must leave every
# KDE config file byte-identical to how it started. Nothing runs against a real
# home directory.
set -uo pipefail

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
source "$REPO_ROOT/tests/lib/harness.sh"
harness_init

# A home with settings already in it, including ones the theme will overwrite.
kwriteconfig6 --file kdeglobals --group General --key ColorScheme "UserScheme"
kwriteconfig6 --file kdeglobals --group Icons   --key Theme       "user-icons"
kwriteconfig6 --file kdeglobals --group KDE     --key widgetStyle "UserStyle"
kwriteconfig6 --file plasmarc   --group Theme   --key name        "user-theme"
kwriteconfig6 --file kwinrc     --group Windows --key Unrelated   "keepme"
kwriteconfig6 --file kwinrc     --group TabBox  --key LayoutName  "thumbnail_grid"

before_sums=$(kde_sums)

# Stand-ins for the session and for anything that installs a package: both
# must be reached by nothing here.
CALLS="$SANDBOX/calls"
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

fake_recorders "$CALLS" busctl pacman sudo

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
# One read for the checks against one state: here each read is five seconds.
s=$("$REPO_ROOT/scripts/theme.sh" status --json)
check "status says which"           "$(jq -r '.desktop.colours' <<<"$s")" "false"
check "and which are on"            "$(jq -r '.desktop.icons' <<<"$s")" "true"
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
s=$("$REPO_ROOT/scripts/theme.sh" status --json)
check "status carries it"             "$(jq -r '.variant.resolved' <<<"$s")" "light"
check "and whether it follows"        "$(jq -r '.variant.follows' <<<"$s")" "false"

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
# Copying a scheme's colours under another scheme's name is the same fault
# upside down, and this function caused it before it wrote the name as well.
check "and the name goes with them"               "$(kreadconfig6 --file kdeglobals --group General --key ColorScheme)" "$SLUG-light"
check "once they have, it does nothing"           "$("$REPO_ROOT/scripts/theme.sh" variant light 2>&1 | grep -c 'already in light')" "1"

# The part's own switch still holds: colours off means colours left alone,
# whoever is switching.
desktop_parts_off '{ "colours": false }'
kwriteconfig6 --file kdeglobals --group KDE --key LookAndFeelPackage "$LNF_DARK_PACKAGE_ID"
"$REPO_ROOT/scripts/theme.sh" variant dark >/dev/null 2>&1
check "colours off leaves them alone"             "$(kreadconfig6 --file kdeglobals --group "Colors:Window" --key BackgroundNormal)" "$light_bg"
desktop_parts_off ""

kwriteconfig6 --file kdeglobals --group KDE --key AutomaticLookAndFeel --delete

# `[ColorEffects:*]` is as much a part of a colour scheme as `[Colors:*]`: it
# is how disabled and inactive things are drawn. It was left behind until
# 2026-09-23, so a light desktop greyed its disabled text with the dark
# scheme's grey.
echo "== a scheme is more than its [Colors:*] groups =="
effect_of() { sed -n '/^\[ColorEffects:Inactive\]/,/^\[/ s/^Color=//p' "$COLORS_DIR/$SLUG-$1.colors" | head -1; }
"$REPO_ROOT/scripts/theme.sh" variant light >/dev/null 2>&1
check "the light effects are copied too" "$(kreadconfig6 --file kdeglobals --group "ColorEffects:Inactive" --key Color)" "$(effect_of light)"
"$REPO_ROOT/scripts/theme.sh" variant dark >/dev/null 2>&1
check "and the dark ones"                "$(kreadconfig6 --file kdeglobals --group "ColorEffects:Inactive" --key Color)" "$(effect_of dark)"

# A backup written before `[ColorEffects:*]` joined the governed set knows
# nothing about those groups, so a revert would take them away and put nothing
# back. Widening it is right; widening it by "everything governed now that the
# backup does not mention" is not -- by the second apply that is *our own
# colours*, and the backup would hand a revert the scheme it exists to undo.
echo "== a backup written before the group set grew =="
widen="$SANDBOX/widen"
mkdir -p "$widen"
printf '[Colors:Window]\nBackgroundNormal=1,2,3\n\n[ColorEffects:Inactive]\nColor=4,5,6\n' > "$widen/kdeglobals"
sections() { python3 -c "import json,sys; print(' '.join(b['section'] for b in json.load(open(sys.argv[1]))['blocks']))" "$1"; }

# As the old code wrote it: the groups it governed, and no note of which those were.
printf '{"blocks": [{"index": 1, "section": "Colors:Window", "text": "[Colors:Window]\\nBackgroundNormal=1,2,3\\n\\n"}]}\n' > "$widen/backup.json"
python3 "$REPO_ROOT/scripts/lib/kdeglobals-colors.py" save-widened "$widen/kdeglobals" "$widen/backup.json"
check "the new group is recorded"       "$(sections "$widen/backup.json")" "Colors:Window ColorEffects:Inactive"
python3 "$REPO_ROOT/scripts/lib/kdeglobals-colors.py" save-widened "$widen/kdeglobals" "$widen/backup.json"
check "and widening again does nothing" "$(sections "$widen/backup.json")" "Colors:Window ColorEffects:Inactive"

# Nothing was there when we started, and a widen must not change that answer.
printf '{"blocks": []}\n' > "$widen/empty.json"
python3 "$REPO_ROOT/scripts/lib/kdeglobals-colors.py" save-widened "$widen/kdeglobals" "$widen/empty.json"
check "our own colours are not theirs"  "$(sections "$widen/empty.json")" "ColorEffects:Inactive"

# Writing kdeglobals by hand is silent, and a silent write is one nobody acts
# on: KDE's own tools write through KConfig, which puts a ConfigChanged on the
# bus, and every KConfigWatcher in the session -- KWin's decoration palette and
# the desktop portal among them -- is listening for it. Measured on 2026-09-23:
# without it a window's contents followed the new colours and its titlebar did
# not.
echo "== and it is announced, not written in silence =="
: > "$CALLS"
"$REPO_ROOT/scripts/theme.sh" variant light >/dev/null 2>&1
check "no session, nothing emitted"      "$(wc -l < "$CALLS")" "0"

"$REPO_ROOT/scripts/theme.sh" variant dark >/dev/null 2>&1
: > "$CALLS"
env -u "$NO_SESSION_VAR" "$REPO_ROOT/scripts/theme.sh" variant light >/dev/null 2>&1
check "the config change is announced"   "$(grep -c 'emit /kdeglobals org.kde.kconfig.notify ConfigChanged' "$CALLS")" "1"
check "and the older signal as well"     "$(grep -c 'emit /KGlobalSettings' "$CALLS")" "1"
# The key names go as byte arrays, and busctl takes the bytes as numbers --
# `gdbus` would nul-terminate them and a listener would match none.
check "it names the key listeners watch" "$(grep -c 'General 1 11 67 111 108 111 114 83 99 104 101 109 101' "$CALLS")" "1"
: > "$CALLS"

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
s=$(th status --json 2>/dev/null)
check "every part reported"          "$(jq -r '[.package, .parts.switcher, .parts.desktoptheme, .parts.splash, .parts.schemes] | map(tostring) | join(",")' <<<"$s")" "true,true,true,true,2"
check "an installed style offered"   "$(jq -r '.styles[] | select(.id == "darkly") | .installed' <<<"$s")" "true"
check "a missing one is not"         "$(jq -r '.styles[] | select(.id == "union") | .installed' <<<"$s")" "false"
check "Fusion is built into Qt"      "$(jq -r '.styles[] | select(.id == "fusion") | .installed' <<<"$s")" "true"
check "the theme's style read back"  "$(jq -r .style <<<"$s")" "breeze"
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
check_unchanged "every config file byte-identical after revert" "$before_sums" "$(kde_sums)"

harness_done

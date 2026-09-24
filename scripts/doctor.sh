#!/usr/bin/env bash
# Checks the installation and reports what is wrong, with the fix for each.
#
# Every finding carries a command or a file, because a diagnostic that only
# says something is wrong leaves the person no better off than the symptom did.
set -uo pipefail

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
source "$REPO_ROOT/scripts/lib/log.sh"
source "$REPO_ROOT/scripts/lib/brand.sh"
source "$REPO_ROOT/scripts/lib/protected.sh"
source "$REPO_ROOT/scripts/lib/snapshot.sh"
source "$REPO_ROOT/scripts/lib/kconfig.sh"
source "$REPO_ROOT/scripts/lib/accel.sh"
source "$REPO_ROOT/scripts/lib/kwin.sh"
source "$REPO_ROOT/scripts/lib/lockscreen.sh"
source "$REPO_ROOT/scripts/lib/config.sh"
source "$REPO_ROOT/scripts/lib/renderers.sh"

# Read once: every section below asks for a setting or two of its own.
config_load

problems=0
warnings=0

ok()   { printf '  %sok%s    %s\n'   "$_c_grn" "$_c_off" "$*"; }
warn() { printf '  %swarn%s  %s\n'   "$_c_yel" "$_c_off" "$*"; warnings=$((warnings + 1)); }
bad()  { printf '  %sfail%s  %s\n'   "$_c_red" "$_c_off" "$*"; problems=$((problems + 1)); }
fix()  { printf '        %s\n' "$*"; }

section() { printf '\n%s==>%s %s\n' "$_c_grn" "$_c_off" "$*"; }

# ---------------------------------------------------------------- environment

section "environment"

if [ "${XDG_CURRENT_DESKTOP:-}" = "KDE" ]; then
    ok "running under KDE"
else
    warn "XDG_CURRENT_DESKTOP is '${XDG_CURRENT_DESKTOP:-unset}'"
    fix "this shell targets Plasma; other desktops are untested"
fi

for tool in quickshell jq busctl gdbus kwriteconfig6; do
    if command -v "$tool" >/dev/null 2>&1; then
        ok "$tool present"
    else
        bad "$tool not found"
        fix "install it; the shell needs it at runtime"
    fi
done

if [ -x /usr/lib/qt6/bin/qmllint ]; then
    ok "Qt6 qmllint present"
else
    warn "Qt6 qmllint not found"
    fix "install qt6-declarative to run 'make lint'"
fi

# -------------------------------------------------------------------- install

section "install"

missing=0
while IFS='|' read -r kind src dest; do
    [ -n "$kind" ] || continue
    if [ -e "$dest" ] || [ -L "$dest" ]; then
        continue
    fi
    bad "missing: $dest"
    missing=$((missing + 1))
done < <(source "$REPO_ROOT/scripts/lib/manifest.sh"; manifest_entries)

if [ "$missing" -eq 0 ]; then
    ok "every installed path is present"
else
    fix "run: make link   (or make install)"
fi

case ":$PATH:" in
    *":$BIN_DIR:"*) ok "$BIN_DIR is on PATH" ;;
    *) warn "$BIN_DIR is not on PATH"
       fix "add it, or run $BIN_DIR/$CTL_BIN by full path" ;;
esac

# -------------------------------------------------------------------- service

section "service"

if systemctl --user cat "$SYSTEMD_UNIT" >/dev/null 2>&1; then
    state=$(systemctl --user is-active "$SYSTEMD_UNIT" 2>/dev/null || true)
    case "$state" in
        active) ok "service is running" ;;
        failed) bad "service has failed"
                fix "see why: $ALIAS log -n 50" ;;
        *)      warn "service is $state"
                fix "start it: $ALIAS start" ;;
    esac

    restarts=$(systemctl --user show "$SYSTEMD_UNIT" -p NRestarts --value 2>/dev/null || echo 0)
    if [ "${restarts:-0}" -gt 3 ]; then
        warn "the service has restarted $restarts times"
        fix "a widget may be crashing it: $ALIAS log -n 100"
    fi
else
    warn "no systemd unit installed"
    fix "run: make link"
fi

# --------------------------------------------------------------- configuration

section "window previews"

# A live picture of a window needs three things to line up, and each of them
# fails quietly on its own: the compiled module, kpipewire to draw a node, and
# KWin's permission -- which it grants only to a client whose desktop file
# names the protocol.
preview_module="$HOME/.local/lib/qt6/qml/KWinScreencast/libshellscreencastplugin.so"
preview_dir=$(dirname "$(dirname "$preview_module")")
if [ -f "$preview_module" ]; then
    ok "the preview module is installed"
else
    warn "no preview module: windows are drawn as their application's icon"
    fix "build it with: make plugin  (needs cmake and Qt 6 development files)"
fi

# Installed is not the same as reachable. The module is a compiled QML module
# in the user's own Qt import directory, which Qt searches only when it is on
# QML2_IMPORT_PATH -- and the session script is what puts it there. Built,
# installed and unreachable reported itself as "the KWinScreencast module is
# not installed (build it with `make plugin`)", which sent the reader to
# rebuild a module that was already sitting in that directory.
if [ -f "$preview_module" ]; then
    if grep -q "$(printf '%s' "$preview_dir" | sed 's|^'"$HOME"'|\$HOME|')" "$BIN_DIR/$SESSION_BIN" 2>/dev/null \
       || grep -qF "$preview_dir" "$BIN_DIR/$SESSION_BIN" 2>/dev/null; then
        ok "the shell can import it ($preview_dir is on the import path)"
    else
        bad "the preview module is installed but the shell cannot import it"
        fix "$preview_dir is not on QML2_IMPORT_PATH in $BIN_DIR/$SESSION_BIN"
        fix "reinstall with: make link  (then: $ALIAS restart)"
    fi
fi

# The other module the same build installs, beside it. It answers what QML
# cannot ask without an event to hang the question on: which keys are held and
# which locks are on. Without it the lock-key OSD is silent, and the switchers
# cannot check whether their key is still down.
input_module="$preview_dir/ShellInput/libshellinputplugin.so"
if [ -f "$input_module" ]; then
    ok "the input module is installed (held keys, lock keys)"
else
    warn "no input module: no lock-key OSD, and the switchers cannot check which keys are held"
    fix "build it with: make plugin  (the same build as the previews)"
fi

if [ -d /usr/lib/qt6/qml/org/kde/pipewire ]; then
    ok "kpipewire present (it draws the stream)"
else
    warn "kpipewire is missing, so a stream could not be drawn even if KWin gave one"
    fix "install it with: sudo pacman -S --needed kpipewire"
fi

wayland_desktop="$APPLICATIONS_DIR/$SLUG-wayland-interfaces.desktop"
if grep -q "zkde_screencast_unstable_v1" "$wayland_desktop" 2>/dev/null; then
    ok "KWin is asked for the screencast protocol ($(basename "$wayland_desktop"))"
else
    bad "nothing asks KWin for the screencast protocol"
    fix "KWin only advertises it to a client whose desktop file names it in X-KDE-Wayland-Interfaces"
    fix "reinstall with: make link"
fi

section "configuration"

# The profile in use, not profiles/default -- checking a file the shell is
# not reading is a health check that cannot fail when it should.
profile_file="$(profile_file)"
if [ -f "$profile_file" ]; then
    if jq -e . "$profile_file" >/dev/null 2>&1; then
        ok "profile parses ($(jq -r '.schemaVersion // "no version"' "$profile_file"))"
    else
        bad "profile is not valid JSON: $profile_file"
        fix "the shell keeps its last good configuration and refuses to write until this parses"
        fix "check it with: jq . $profile_file"
    fi
else
    warn "no profile yet at $profile_file"
    fix "it is written the first time the shell starts"
fi

defaults_file="$DATA_DIR/config/defaults/shell.json"
if jq -e . "$defaults_file" >/dev/null 2>&1; then
    ok "shipped defaults parse"
else
    bad "shipped defaults are missing or invalid: $defaults_file"
    fix "run: make link"
fi

# ------------------------------------------------------------------- widgets

section "widgets"

health="$STATE_DIR/widget-health.json"
if [ -f "$health" ]; then
    q=$(jq -r '.quarantined | keys | join(", ")' "$health" 2>/dev/null || true)
    if [ -n "$q" ] && [ "$q" != "" ]; then
        warn "quarantined: $q"
        fix "these were disabled after repeatedly failing to load"
        fix "re-enable one from the settings window, Widgets page"
    else
        ok "no quarantined widgets"
    fi
else
    ok "no widget failures recorded"
fi

# ---------------------------------------------------------------- KDE changes

section "KDE configuration we have changed"

led=$(kconfig_ledger)
if [ -s "$led" ] && [ "$(jq '.entries | length' "$led")" -gt 0 ]; then
    drift=0
    while IFS=$'\t' read -r scope file group key had value; do
        mapfile -t gargs < <(_kconfig_group_args "$group")
        live=$(kreadconfig6 --file "$file" "${gargs[@]}" --key "$key" --default '<unset>' 2>/dev/null)
        printf '  %-9s %s [%s] %s = %s\n' "[$scope]" "$file" "$group" "$key" "$live"
        [ "$live" = "<unset>" ] && drift=$((drift + 1))
    done < <(jq -r '.entries[] | [(.scope // "-"), .file, .group, .key, (.had|tostring), .value] | @tsv' "$led")

    if [ "$drift" -gt 0 ]; then
        warn "$drift recorded key(s) are no longer set"
        fix "something else changed them; revert is still safe and will restore the recorded values"
    fi
    fix "undo everything: $ALIAS theme revert / edges revert / shortcuts revert"
else
    ok "no KDE settings changed by this project"
fi

# ------------------------------------------------------------------- hazards

section "known hazards"

shell_pkg=$(live_shell_package)
if [ "$shell_pkg" = "org.kde.plasma.desktop" ] \
   || [ -d "$XDG_DATA_HOME/plasma/shells/$shell_pkg" ] \
   || [ -d "/usr/share/plasma/shells/$shell_pkg" ]; then
    ok "plasmashell's shell package '$shell_pkg' exists"
else
    bad "plasmashell is set to '$shell_pkg', which is not installed"
    fix "on the next login plasmashell falls back to the default layout"
    fix "reinstall that package, or: kwriteconfig6 --file plasmashellrc --group Shell --key ShellPackage org.kde.plasma.desktop"
fi

# The headline failure mode of having two renderers: both drawing at once.
# Counted rather than assumed, because the case that matters is the one where
# the configuration and what is on screen have come apart.
configured_renderer=$(renderer_normalize "$(config_get '.panel.renderer' quickshell)")

# A value no renderer answers to is read as ours, as it always has been here.
expected_pkg=$(package_for "$configured_renderer")
[ -n "$expected_pkg" ] || expected_pkg=$SHELL_PACKAGE_ID

if [ "$shell_pkg" = "$expected_pkg" ]; then
    ok "renderer '$configured_renderer' matches plasmashell's package"
else
    warn "configured renderer is '$configured_renderer' but plasmashell uses '$shell_pkg'"
    fix "the panel you see may not be the one configured"
    fix "re-apply it: $ALIAS renderer set $configured_renderer"
fi

# Every panel containment in every layout we own. More than one, or one while
# the Quickshell panel is also drawing, is the stacked-panels bug.
our_panels=0
for pkg in "$SHELL_PACKAGE_ID" "$PLASMA_SHELL_PACKAGE_ID"; do
    f="$XDG_CONFIG_HOME/plasma-$pkg-appletsrc"
    [ -f "$f" ] || continue
    n=$(grep -c '^plugin=org.kde.panel$' "$f" 2>/dev/null || true)
    our_panels=$((our_panels + n))
    if [ "$pkg" = "$shell_pkg" ] && [ "$n" -gt 0 ] && [ "$configured_renderer" != "plasma" ]; then
        bad "the active layout for '$pkg' has a Plasma panel, but the renderer is '$configured_renderer'"
        fix "two panels will be drawn at the same edge"
        fix "regenerate it: $ALIAS renderer set $configured_renderer"
    fi
done
if [ "$our_panels" -le 1 ]; then
    ok "$our_panels panel containment(s) in the layouts we generate"
else
    bad "$our_panels panel containments across our layouts; at most one may exist"
    fix "regenerate them: $ALIAS renderer set $configured_renderer"
fi

# The state a real desktop was left in: the renderer says we draw the panel,
# and we are not running, so nothing does. plasmashell is behaving correctly
# and the screen is empty, which is the hardest kind of fault to place.
# Only when the quickshell renderer is actually in effect. With plasmashell on
# some other package, something else is drawing and the mismatch warning above
# is the finding -- reporting "no panel at all" while one is plainly on screen
# teaches people to ignore this output.
if [ "$configured_renderer" = "quickshell" ] && [ "$shell_pkg" = "$SHELL_PACKAGE_ID" ]; then
    if shell_running; then
        ok "the shell is running and drawing the panel"
    elif systemctl --user is-enabled "$SYSTEMD_UNIT" >/dev/null 2>&1; then
        warn "the shell is not running, so nothing is drawing a panel"
        fix "start it: $ALIAS start"
    else
        bad "the renderer is 'quickshell' but the shell is neither running nor enabled"
        fix "nothing is drawing a panel at all"
        fix "start it:            make link && $ALIAS start"
        fix "or hand it back:     $ALIAS renderer set plasma   (plasmashell draws our panel)"
        fix "or use your own:     $ALIAS renderer set none     (your stock Plasma panels)"
    fi
fi

# Another Quickshell shell drawing is the configuration, not a competitor, when
# it is the one the renderer names -- and nothing at all when it is gone.
foreign=""
if renderer_is_foreign "$configured_renderer"; then
    foreign=$(renderer_config_name "$configured_renderer")
    funit=$(renderer_unit "$foreign")
    if [ -z "$(renderer_config_dir "$foreign")" ]; then
        bad "the renderer is '$configured_renderer', but no Quickshell configuration named $foreign is here any more"
        fix "nothing draws a panel; pick another: $ALIAS renderer list"
    elif [ "$(quickshell list -j -c "$foreign" 2>/dev/null | jq 'length' 2>/dev/null)" -gt 0 ] 2>/dev/null; then
        ok "the $foreign configuration is running and drawing the panel"
        systemctl --user is-enabled "$funit" >/dev/null 2>&1 \
            || { warn "$funit is not enabled, so $foreign will not start at the next login"
                 fix "re-apply it: $ALIAS renderer set $configured_renderer"; }
    else
        bad "the renderer is '$configured_renderer', but $foreign is not running: nothing draws a panel"
        fix "start it: systemctl --user enable --now $funit"
    fi
fi

others=$(other_quickshells)
[ -n "$foreign" ] && others=$(printf '%s\n' "$others" | grep -vE -- "(-c|--config)[ =]$foreign( |\$)|/quickshell/$foreign/" || true)
if [ -n "$others" ]; then
    warn "another Quickshell shell is running"
    printf '%s\n' "$others" | sed 's/^/        /'
    fix "both draw at once, and they compete for global shortcuts"
else
    ok "no competing Quickshell instance"
fi

# A shortcut kglobalaccel has a record of but no running owner for is never
# grabbed, and that is invisible from the file: the record is perfect. It is
# the one failure this project spent a whole evening finding, so it is checked
# by name.
bound=""
for k in "${ACCEL_ACTIONS[@]}"; do
    [ -n "$bound" ] && break
    bound=$(kreadconfig6 --file kglobalshortcutsrc --group "$SLUG" --key "$k" --default '' 2>/dev/null)
done
legacy=""
for k in "${ACCEL_ACTIONS[@]}"; do
    v=$(kreadconfig6 --file kglobalshortcutsrc --group services --group "$SLUG-$k.desktop" --key _launch --default '' 2>/dev/null | cut -d, -f1)
    [ -n "$v" ] && [ "$v" != none ] && legacy="$legacy $k"
done
if [ -n "$legacy" ]; then
    warn "shortcuts still bound the old way:$legacy"
    fix "those are never grabbed after login; move them: $ALIAS shortcuts migrate"
fi
if [ -n "$bound" ] && [ "${bound%%,*}" != none ]; then
    case "$(accel_component_active "$SLUG")" in
        true)  ok "our global shortcuts have a running owner, so the keys are grabbed" ;;
        false) bad "our global shortcuts are filed but not grabbed: no owner is running"
               fix "the session daemon owns them; start it: $ALIAS windows list" ;;
        *)     warn "kglobalaccel did not say whether our shortcuts are grabbed" ;;
    esac
fi

if command -v kreadconfig6 >/dev/null 2>&1; then
    tilers=$(kwin_tiling_scripts | tr '\n' ' ')
    if [ -n "$tilers" ]; then
        warn "tiling script enabled: $tilers"
        fix "it and KWin's edge snapping can both claim a window dragged to an edge;"
        fix "turn snapping off in: $ALIAS settings edges"
    else
        ok "no tiling script enabled"
    fi
fi

# ----------------------------------------------------------------- snapshots

section "restore points"

root=$(snapshot_root)
count=$(ls -1 "$root" 2>/dev/null | wc -l)
if [ "$count" -gt 0 ]; then
    ok "$count restore point(s), $(du -sh "$root" 2>/dev/null | cut -f1) total"
    fix "oldest is the pre-install state; nothing is ever removed automatically"
else
    warn "no restore points"
    fix "take one before changing KDE settings: $ALIAS snapshot create"
fi

# --------------------------------------------------------------- window list

section "open windows"

profile_entries=$(jq -r '[.bar.entries[]? | select(.enabled != false) | .id] | join(" ")' \
    "$(profile_file)" 2>/dev/null || echo "")
[ -n "$profile_entries" ] || profile_entries=$(jq -r '[.bar.entries[]? | select(.enabled != false) | .id] | join(" ")' \
    "$defaults_file" 2>/dev/null || echo "")

script_loaded=$(kwin_scripting isScriptLoaded "$KWIN_SCRIPT_ID" || echo unknown)
daemon_answers=no
busctl --user --json=short call "$DBUS_NAME" /Windows "$DBUS_NAME.Windows" List >/dev/null 2>&1 && daemon_answers=yes

case " $profile_entries " in
    *" tasks "*)
        if [ "$script_loaded" = "true" ] && [ "$daemon_answers" = yes ]; then
            count=$(busctl --user --json=short call "$DBUS_NAME" /Windows "$DBUS_NAME.Windows" List 2>/dev/null \
                    | jq -r '.data[0] | fromjson | length' 2>/dev/null || echo '?')
            ok "the window list is running ($count window(s))"
        else
            bad "the panel has the open-windows widget, but the window list is off"
            fix "it will show nothing at all until the KWin script is loaded"
            fix "turn it on: $ALIAS windows enable"
        fi ;;
    *)
        if [ "$script_loaded" = "true" ]; then
            warn "the window list is running, but no panel widget shows it"
            fix "add the 'tasks' widget from the settings window, or: $ALIAS windows disable"
        else
            ok "the window list is off, and nothing asks for it"
        fi ;;
esac

# ------------------------------------------------------------------- the OSD

section "on-screen display"

osd_enabled=$(config_get '.osd.enabled' false)
lnf_active=$(kreadconfig6 --file kdeglobals --group KDE --key LookAndFeelPackage --default '')
osd_file="$PLASMA_LNF_DIR/$LNF_PACKAGE_ID/contents/osd/Osd.qml"
osd_silenced=no
grep -q 'drawn as nothing' "$osd_file" 2>/dev/null && osd_silenced=yes

if [ "$osd_enabled" != "true" ]; then
    ok "Plasma draws the OSD"
    if [ "$osd_silenced" = yes ]; then
        bad "but our package silences Plasma's OSD, and ours is switched off"
        fix "nothing will draw an OSD at all"
        fix "put it back: $ALIAS theme osd plasma"
    fi
elif [ "$lnf_active" != "$LNF_PACKAGE_ID" ]; then
    warn "our OSD is on, but our look-and-feel package is not active"
    fix "Plasma is drawing its own as well, so you will see two"
    fix "either apply the package ($ALIAS theme apply) or turn ours off"
elif [ "$osd_silenced" = yes ]; then
    ok "our OSD draws, Plasma's is silenced"
else
    warn "our OSD is on and Plasma's is not silenced; you will see two"
    fix "silence Plasma's: $ALIAS theme osd ours"
fi

# ----------------------------------------------------------- light and dark

section "light and dark"

# Who has the last word on the colour scheme. Nothing here is this project's
# to own -- a second thing writing kdeglobals is allowed -- but it must be
# said out loud, because the symptom is indistinguishable from this shell
# being broken: every setting reads light and correct, and the desktop is
# dark. Found on 2026-09-16 only by reading another service's journal.
variant=$(config_get '.theme.mode' auto)
scheme_now=$(kreadconfig6 --file kdeglobals --group General --key ColorScheme --default '')
theme_desktop=$(config_get '.theme.desktop.enabled' true)
theme_colours=$(config_get '.theme.desktop.colours' true)

if [ "$theme_desktop" != "true" ] || [ "$theme_colours" != "true" ]; then
    ok "colour scheme left to you (theme.desktop.colours is off): $scheme_now"
elif [ "$scheme_now" = "$SLUG-light" ] || [ "$scheme_now" = "$SLUG-dark" ]; then
    ok "colour scheme is ours: $scheme_now"
else
    warn "the colour scheme is not ours: $scheme_now"
    fix "something else wrote it after we did, and theme.mode ($variant) reads its answer"
    if systemctl --user cat kde-material-you-colors.service >/dev/null 2>&1; then
        fix "kde-material-you-colors is installed here and applies a scheme at every login"
        fix "  it follows this shell:  turn on theme.desktop.materialYou"
        fix "  or leave it out of it:  systemctl --user disable --now kde-material-you-colors"
    fi
    fix "put ours back: $ALIAS theme variant $([ "$variant" = dark ] && echo dark || echo light)"
fi

# Whether light and dark are settled before the session's applications start.
#
# The shell settles them too, but it is late: quickshell has to load, the
# profile has to be read and Night Light has to answer, which measured eight
# seconds into the session. Everything XDG autostart brings up -- session
# restore included -- starts inside that window and reads the desktop's
# colours once. An Electron application asks the portal at startup and never
# asks again, so one started in those eight seconds is dark for the rest of
# the day on a desktop that is light everywhere else.
auto_lnf=$(kreadconfig6 --file kdeglobals --group KDE --key AutomaticLookAndFeel --default false)
if [ "$auto_lnf" != "true" ] \
   && [ "$(config_get '.theme.desktop.followMode' false)" != "true" ]; then
    ok "light and dark left where you put them (nothing switches them)"
elif systemctl --user is-enabled "$SLUG-theme.service" >/dev/null 2>&1; then
    ok "light and dark are settled before the session's applications start"
else
    warn "light and dark are settled eight seconds into the session, not before it"
    fix "applications started in that window -- Electron ones especially -- keep last night's colours all day"
    fix "settle it at login: systemctl --user enable $SLUG-theme.service"
fi

# A scheme KDE cannot resolve to a file. kdeglobals names a scheme by the base
# name of its .colors file -- BreezeDark, not "Breeze Dark" -- and this project
# wrote the display name there until 2026-09-16. The colours still reached
# every application, because they are copied into kdeglobals as well, so the
# desktop looked nearly right: System Settings said the scheme was not
# installed and chose the default, and everything that resolves a scheme by
# name rather than reading the copy stayed on whatever it had.
#
# Nearly right is the worst kind of wrong to find by eye, so it is checked.
if [ -n "$scheme_now" ]; then
    found=""
    for dir in "$COLORS_DIR" "$XDG_DATA_HOME/color-schemes" /usr/share/color-schemes; do
        [ -f "$dir/$scheme_now.colors" ] && { found=$dir; break; }
    done
    if [ -n "$found" ]; then
        ok "the colour scheme resolves to a file: $found/$scheme_now.colors"

        # And holds that file's colours, which is a separate write again.
        #
        # kdeglobals carries both: the scheme's name under [General], and a
        # copy of its [Colors:*] groups, which is what every Qt application
        # reads. Found disagreeing on the morning of 2026-09-23 -- the name
        # said our light scheme, every group held our dark one, and every
        # window on the desktop was dark while this section said nothing.
        want_bg=$(sed -n '/^\[Colors:Window\]/,/^\[/ s/^BackgroundNormal=//p' \
                      "$found/$scheme_now.colors" 2>/dev/null | head -1 | tr -d ' ')
        have_bg=$(kreadconfig6 --file kdeglobals --group "Colors:Window" --key BackgroundNormal --default '' | tr -d ' ')
        if [ -z "$want_bg" ] || [ "$have_bg" = "$want_bg" ]; then
            :
        else
            bad "kdeglobals names '$scheme_now' and holds another scheme's colours"
            fix "the name is a label; the [Colors:*] groups copied beside it are what"
            fix "  every Qt application draws from -- so the desktop wears the copy"
            fix "'$scheme_now' paints windows $want_bg; kdeglobals says $have_bg"
            fix "put the named scheme's colours back: $ALIAS theme variant auto"
        fi
    else
        bad "kdeglobals names a colour scheme no file is called: '$scheme_now'"
        fix "KDE identifies a scheme by its file's base name, not the name it shows"
        fix "applications read the colours copied into kdeglobals and look right;"
        fix "  anything that resolves the scheme by name falls back to the default"
        fix "put ours back: $ALIAS theme apply"
    fi
fi

# Who switches light and dark. Plasma's own switch (kdeglobals [KDE]
# AutomaticLookAndFeel) applies a whole *global theme* at sunset -- and with
# nothing of ours named as its two halves it applies Breeze and Breeze Dark,
# which replaces this project's look-and-feel package, colour scheme, icons and
# decorations in one write. Found on 2026-09-16 with the desktop half ours and
# half Breeze Dark, which looks exactly like a theme that did not finish
# applying.
lnf_auto=$(kreadconfig6 --file kdeglobals --group KDE --key AutomaticLookAndFeel --default false)
lnf_light=$(kreadconfig6 --file kdeglobals --group KDE --key DefaultLightLookAndFeel --default '')
lnf_dark=$(kreadconfig6 --file kdeglobals --group KDE --key DefaultDarkLookAndFeel --default '')
lnf_now=$(kreadconfig6 --file kdeglobals --group KDE --key LookAndFeelPackage --default '')

if [ "$theme_desktop" != "true" ]; then
    ok "day and night left to you (theme.desktop.enabled is off)"
elif [ "$lnf_auto" != true ]; then
    ok "light and dark are ours to switch (Plasma's own switch is off)"
elif [ "$lnf_light" = "$LNF_PACKAGE_ID" ] && [ "$lnf_dark" = "$LNF_DARK_PACKAGE_ID" ]; then
    ok "Plasma switches light and dark between our two packages"
else
    bad "Plasma's 'Switch to Dark Mode at Night' is on and does not name ours"
    fix "at sunset it applies '${lnf_dark:-org.kde.breezedark.desktop}' over this theme -- the"
    fix "  colour scheme, the icons and the decorations go with it"
    fix "name ours as its two halves: $ALIAS theme apply"
    fix "or turn the switch off in System Settings -> Colors & Themes -> Global Theme"
fi

if [ "$lnf_now" = "$LNF_PACKAGE_ID" ] || [ "$lnf_now" = "$LNF_DARK_PACKAGE_ID" ]; then
    ok "the global theme in force is ours: $lnf_now"
elif [ "$theme_desktop" = "true" ]; then
    warn "the global theme in force is not ours: ${lnf_now:-<unset>}"
    fix "put ours back: $ALIAS theme apply"
fi

# Plasma's switch is on, names ours, and is still wearing the wrong half. Found
# on the evening of 2026-09-22: kded6 had been running since before a
# Frameworks upgrade replaced the libraries mapped into it, its timer never
# went off at sunset, and the desktop sat in light behind a dark shell for two
# hours. Nothing in the configuration is wrong when this happens, which is why
# it needs asking about rather than reading off a key.
if [ "$theme_desktop" = "true" ] && [ "$lnf_auto" = true ] \
   && [ "$lnf_light" = "$LNF_PACKAGE_ID" ] && [ "$lnf_dark" = "$LNF_DARK_PACKAGE_ID" ]; then
    case "$(night_light_daylight)" in
        true)  lnf_want=$LNF_PACKAGE_ID ;;
        false) lnf_want=$LNF_DARK_PACKAGE_ID ;;
        *)     lnf_want='' ;;
    esac
    if [ -z "$lnf_want" ]; then
        :   # no schedule to check it against
    elif [ "$lnf_now" = "$lnf_want" ]; then
        ok "Plasma's switch names the right half for the hour: $lnf_now"
    else
        bad "Plasma's day and night switch has not fired: the desktop is in the wrong half"
        fix "it is a background module on a timer, and a Frameworks upgrade under a"
        fix "  running session is enough to stop it going off"
        fix "put it right now:   $ALIAS theme variant auto"
        fix "wake the module:    qdbus6 org.kde.kded6 /kded unloadModule lookandfeelautoswitcher"
        fix "                    qdbus6 org.kde.kded6 /kded loadModule lookandfeelautoswitcher"
        fix "or log out and back in, which starts it fresh"
    fi
fi

# The icon theme is in the package too, and a package is applied whole -- so
# when Plasma is the one switching, the icons are Plasma's to write and not
# ours. Checked rather than assumed, for the same reason the colours are: the
# morning of 2026-09-23 showed that "Plasma applied the package" and "every
# part of the package reached kdeglobals" are two different statements.
if [ "$theme_desktop" = "true" ] && [ "$(config_get '.theme.desktop.icons' true)" = "true" ] \
   && [ -f "$PLASMA_LNF_DIR/$lnf_now/contents/defaults" ]; then
    want_icons=$(sed -n '/^\[kdeglobals\]\[Icons\]/,/^\[/ s/^Theme=//p' \
                     "$PLASMA_LNF_DIR/$lnf_now/contents/defaults" | head -1)
    have_icons=$(kreadconfig6 --file kdeglobals --group Icons --key Theme --default '')
    if [ -z "$want_icons" ] || [ "$have_icons" = "$want_icons" ]; then
        ok "the icon theme is the one the active package names: ${have_icons:-<unset>}"
    else
        warn "the icon theme is '$have_icons'; the global theme in force asks for '$want_icons'"
        fix "the package was applied and this part of it did not land"
        fix "put it right: $ALIAS theme variant auto"
    fi
fi

# The names libadwaita and the Adwaita GTK themes actually paint with. A
# stylesheet that sets one of these decides the colour of every window; the
# `*_breeze` names kde-gtk-config generates are not among them, which is why
# `colors.css` is safe and `gtk.css` was not.
GTK_PALETTE_NAMES='window_bg_color|view_bg_color|theme_bg_color|theme_base_color|headerbar_bg_color|card_bg_color|popover_bg_color|sidebar_bg_color|accent_bg_color|dialog_bg_color'

# A `gtk.css` that names the colours outright, which beats everyone.
#
# GTK loads `~/.config/gtk-N.0/gtk.css` last and an `@define-color` in it wins
# over the theme, over the preference, over the portal and over us. Found on
# 2026-09-23 with `window_bg_color #131317` in both files: every GTK 4 and
# libadwaita application drew near-black on a light desktop, with libadwaita's
# own dark flag reading `false` -- the application was not in dark mode, it was
# merely painted that way, which is why nothing that asks about dark mode could
# see it. Neither file is this project's to write; we write `settings.ini`.
if [ "$(config_get '.theme.desktop.gtk' true)" = "true" ]; then
    for gtk_v in 3.0 4.0; do
        gtk_css="$XDG_CONFIG_HOME/gtk-$gtk_v/gtk.css"
        [ -f "$gtk_css" ] || continue
        pinned=$(grep -oE "^@define-color ($GTK_PALETTE_NAMES) +#[0-9a-fA-F]{6}" "$gtk_css" | head -1)
        [ -n "$pinned" ] || continue
        bad "gtk-$gtk_v/gtk.css paints every GTK window itself: ${pinned#@define-color }"
        fix "an \`@define-color\` there is loaded last and beats the theme, the"
        fix "  preference, the portal and this project -- the application is not in"
        fix "  dark mode, it is painted dark, so nothing that asks can tell"
        fix "this file is not ours; we write gtk-$gtk_v/settings.ini and nothing else"
        fix "take the colours out and keep the @import lines:"
        fix "  sed -i '/^@define-color /d' $gtk_css"
    done
fi

# The same fault one file further out: a stylesheet gtk.css pulls in.
#
# `colors.css`, which kde-gtk-config writes, is safe because every name in it
# ends `_breeze` -- names only the Breeze GTK theme reads. A file that defines
# the palette names themselves is the `gtk.css` fault wearing an @import.
for gtk_v in 3.0 4.0; do
    gtk_css="$XDG_CONFIG_HOME/gtk-$gtk_v/gtk.css"
    [ -f "$gtk_css" ] || continue
    [ "$(config_get '.theme.desktop.gtk' true)" = "true" ] || continue
    while read -r imported; do
        [ -n "$imported" ] || continue
        case $imported in /*) f=$imported ;; *) f="$XDG_CONFIG_HOME/gtk-$gtk_v/$imported" ;; esac
        [ -f "$f" ] || continue
        pinned=$(grep -oE "^@define-color ($GTK_PALETTE_NAMES) +#[0-9a-fA-F]{6}" "$f" | head -1)
        [ -n "$pinned" ] || continue
        bad "gtk-$gtk_v/$imported sets the palette itself: ${pinned#@define-color }"
        fix "gtk.css imports it, so it lands in every GTK window the same way"
        fix "  an @define-color in gtk.css itself would -- see above"
        fix "stop importing it, or take that line out of $f"
    done <<< "$(sed -n "s/^@import *['\"]\\([^'\"]*\\)['\"].*/\\1/p" "$gtk_css")"
done

# Something in the session environment deciding it instead.
#
# These beat every file. `GTK_THEME` in particular is absolute: GTK takes it
# over the theme name, the preference and the portal, and `GTK_THEME=x:dark`
# is how a whole session ends up dark with nothing on disk to show for it.
for var in GTK_THEME QT_STYLE_OVERRIDE; do
    val=$(systemctl --user show-environment 2>/dev/null | sed -n "s/^$var=//p")
    [ -n "$val" ] || continue
    bad "$var=$val is set for the whole session"
    fix "it beats every file this project writes, and every mode switch"
    fix "take it out of wherever it is set and log out and in:"
    fix "  grep -rn $var ~/.config/environment.d ~/.config/plasma-workspace/env /etc/environment"
done

# A browser or Electron application told to be dark on the command line.
for flags in "$XDG_CONFIG_HOME"/*-flags.conf; do
    [ -f "$flags" ] || continue
    grep -q 'force-dark' "$flags" || continue
    warn "$(basename "$flags") forces dark mode on the command line"
    fix "that application will stay dark whatever the desktop does"
    fix "take the force-dark flag out of $flags"
done

# KDE keeps a second kdeglobals under `kdedefaults/`, written when a global
# theme is applied and read *beneath* the real one. It is Plasma's, not ours,
# and it is only reached for a key the real file does not have -- but when
# those two disagree the desktop has two answers on disk, and the second one
# is the one nobody thinks to look at.
kd_scheme=$(kreadconfig6 --file "$XDG_CONFIG_HOME/kdedefaults/kdeglobals" --group General --key ColorScheme --default '')
if [ -n "$kd_scheme" ] && [ -n "$scheme_now" ] && [ "$kd_scheme" != "$scheme_now" ]; then
    warn "kdedefaults/kdeglobals still falls back to '$kd_scheme'; the desktop is on '$scheme_now'"
    fix "Plasma writes that file when a global theme is applied; it is read beneath"
    fix "  the real kdeglobals, so it only shows when a key goes missing"
    fix "applying the theme again lines them up: $ALIAS theme apply"
fi

# A GTK theme whose *name* is the dark half of its pair ignores every
# preference we write and stays dark in each mode. The preference agreeing is
# not the same as the theme agreeing.
if [ "$(config_get '.theme.desktop.gtk' true)" = "true" ] && command -v gsettings >/dev/null 2>&1; then
    gtk_pref=$(gsettings get org.gnome.desktop.interface color-scheme 2>/dev/null | tr -d "'")
    gtk_theme=$(gsettings get org.gnome.desktop.interface gtk-theme 2>/dev/null | tr -d "'")
    named_light=$(config_get '.theme.desktop.gtkThemeLight' "")
    named_dark=$(config_get '.theme.desktop.gtkThemeDark' "")

    if [ -n "$named_light" ] || [ -n "$named_dark" ]; then
        ok "GTK theme follows the mode: $gtk_theme ($gtk_pref)"
    elif [ "$gtk_pref" = "prefer-light" ] && printf '%s' "$gtk_theme" | grep -qi 'dark'; then
        warn "GTK prefers light but its theme is $gtk_theme"
        fix "a theme named for the dark half of its pair ignores the preference"
        fix "name both halves: theme.desktop.gtkThemeLight and .gtkThemeDark"
    else
        ok "GTK: $gtk_theme ($gtk_pref)"
    fi
fi

# The daemon on the bus, against the file it was installed from.
#
# It is started by the bus rather than by the shell's unit, so it outlives
# every way of restarting the shell -- which is right, because the KWin script
# must be able to reach it before the shell exists, and a trap after an update:
# the fix is on disk and the process is the one that started with the session.
# On 2026-09-23 that made an icon fix appear to do nothing three times over.
daemon_bin="$BIN_DIR/$WINDOWSD_BIN"
daemon_pid=$(pgrep -f "$daemon_bin" 2>/dev/null | head -1)
if [ -n "$daemon_pid" ] && [ -f "$daemon_bin" ]; then
    if [ "$daemon_bin" -nt "/proc/$daemon_pid" ]; then
        warn "the window daemon running is older than the one installed"
        fix "it is started by the bus, not by the shell's unit, so restarting the"
        fix "  shell leaves it exactly where it was"
        fix "start the one on disk: $ALIAS windows restart"
    else
        ok "the window daemon running is the one installed"
    fi
fi

# ---------------------------------------------------------------- lock screen

section "lock screen"

if ! lockscreen_enabled; then
    ok "Plasma's lock screen draws; ours is off ($ALIAS lockscreen status)"
else
    ls_hash=$(cat "$LOCKSCREEN_ENABLED")
    for p in "${LOCKSCREEN_PACKAGES[@]}"; do
        [ -d "$PLASMA_SHELLS_DIR/$p" ] || continue
        d=$(lockscreen_installed_dir "$p")
        if [ ! -f "$d/$LOCKSCREEN_MARKER" ]; then
            warn "ours is on, but not installed in $p"
            fix "put it back: $ALIAS lockscreen enable"
        elif [ "$(lockscreen_hash "$d")" != "$ls_hash" ]; then
            bad "the lock screen in $p is not the build that was tried"
            fix "take it out ($ALIAS lockscreen disable), then try and enable it again"
        fi
    done
    if greeter=$(lockscreen_greeter); then
        if [ "$(lockscreen_greeter_id "$greeter")" != "$(jq -r '.greeter // empty' "$LOCKSCREEN_MARK" 2>/dev/null)" ]; then
            warn "Plasma's greeter has changed since our lock screen was tried"
            fix "to be sure it still unlocks: $ALIAS lockscreen try"
        fi
        if out=$(lockscreen_check "$LOCKSCREEN_TRIED" 2>&1); then
            ok "ours is on, and loads in this greeter"
        else
            bad "ours is on, and does not load cleanly in this greeter:"
            printf '%s\n' "$out" | sed 's/^/        /'
            fix "the greeter draws its own when ours fails to load; to take ours out: $ALIAS lockscreen disable"
        fi
    else
        warn "ours is on, but Plasma's greeter was not found to check it with"
    fi
    live_pkg=$(live_shell_package)
    case " ${LOCKSCREEN_PACKAGES[*]} " in
        *" $live_pkg "*) ;;
        *) warn "plasmashell is on $live_pkg, so its lock screen is drawn rather than ours" ;;
    esac
fi

# --------------------------------------------------------------- diagnostics

section "diagnostic reports"

source "$REPO_ROOT/scripts/lib/reports.sh"

report_count=$(ls -1 "$REPORT_DIR" 2>/dev/null | wc -l)
if [ "$report_count" -gt 0 ]; then
    ok "$report_count report(s) in $REPORT_DIR"
    fix "read the newest: $ALIAS report show"
    fix "nothing in them has been sent anywhere; they are local files"
else
    ok "no reports written"
fi

if systemctl --user cat "$SLUG-report@.service" >/dev/null 2>&1; then
    ok "the crash reporter is installed"
else
    warn "no crash reporter unit"
    fix "the shell cannot report its own death without it: make link"
fi

# --------------------------------------------------------------- crash dumps

section "crashes"

source "$REPO_ROOT/scripts/lib/crashes.sh"

crash_count=$(crash_list | wc -l)
if [ "$crash_count" -eq 0 ]; then
    ok "no crash dumps from this shell"
else
    newest=$(crash_newest)
    newest_when=$(crash_list | tail -1 | cut -f2)
    # Not a failure on its own: a dump from before an update is history, and
    # the shell has been restarting itself through all of them.
    warn "$crash_count crash dump(s); the newest is $newest ($newest_when)"
    fix "quickshell catches these itself and restarts, so systemd never reports a failure"
    fix "read it:       $ALIAS crash show"
    fix "ask about it:  $ALIAS ask --crash"
    reported=$(report_for_crash "$newest")
    if [ -n "$reported" ]; then
        ok "the newest crash has a report: $(basename "$reported")"
    else
        warn "no report written for the newest crash"
        fix "the shell writes one when it comes back; this dump predates that, or the shell has not restarted since"
        fix "write one now: $ALIAS report create --crash $newest"
    fi
    fix "clear them:    $ALIAS crash remove --all"
fi

# ----------------------------------------------------------------- AI assist

section "AI assist"

merged_cfg=$(config_merged)
ai_enabled=$(jq -r '.ai.enabled // false' <<< "$merged_cfg")
ai_provider=$(jq -r '.ai.provider // "clipboard"' <<< "$merged_cfg")
history_on=$(jq -r '.notifications.history // false' <<< "$merged_cfg")

if [ "$ai_enabled" = true ]; then
    avail=$("$REPO_ROOT/scripts/ask.sh" --providers --json 2>/dev/null \
            | jq -r --arg p "$ai_provider" '.[] | select(.id == $p) | if .available then "yes" else .reason end')
    if [ "$avail" = yes ]; then
        ok "AI assist is on, provider '$ai_provider' can run here"
    else
        bad "AI assist is on, but provider '$ai_provider' cannot run here: ${avail:-unknown provider}"
        fix "pick another: $ALIAS ask --providers"
    fi
    consent="$STATE_DIR/ai-consent.json"
    if [ -f "$consent" ]; then
        printf '  %s--%s    agreed to send: %s\n' "$_c_dim" "$_c_off" "$(jq -r 'keys | join(", ")' "$consent" 2>/dev/null)"
        fix "withdraw: $ALIAS ask --forget"
    fi
    if [ "$(kreadconfig6 --file kglobalshortcutsrc --group "$SLUG" --key ask --default '' | cut -d, -f1)" = "" ]; then
        printf '  %s--%s    no key bound to ask about the last notification\n' "$_c_dim" "$_c_off"
        fix "bind one: $ALIAS shortcuts set ask <key>"
    fi
else
    ok "AI assist is off; nothing is ever sent"
fi

if [ "$ai_enabled" = true ] || [ "$history_on" = true ]; then
    if shell_running; then
        n=$(quickshell ipc --path "$(shell_ipc_path)" call notifications count 2>/dev/null || echo '?')
        ok "the notification listener is wanted and the shell is running ($n remembered)"
    else
        warn "the notification listener is wanted, but the shell is not running"
        fix "the history is kept in memory by the shell; nothing is recorded while it is down"
    fi
else
    ok "no notification listener; nothing on the bus is read"
fi

# ------------------------------------------------------------ Plasma services

section "Plasma services"

# Plasma's notification server and Klipper live in its system tray, not in
# plasmashell. Where there is no Plasma tray -- our own renderer -- they exist
# only because the shell hosts them, and with no owner at all a notification
# is not queued or shown anywhere: it is dropped.
live_pkg=$(live_shell_package '')
notif_server=$(jq -r '.notifications.server // "plasma"' <<< "$merged_cfg" 2>/dev/null)
for pair in "org.freedesktop.Notifications:notifications" "org.kde.klipper:clipboard history"; do
    name=${pair%%:*}; what=${pair#*:}
    comm=$(bus_status_field "$name" Comm)
    # Asked to serve them itself, the shell waits for whoever holds the name
    # rather than taking it -- so the one thing worth saying is who that is.
    if [ "$name" = org.freedesktop.Notifications ] && [ "$notif_server" = shell ]; then
        if shell_holds_bus_name "$name"; then
            ok "notifications: served by this shell (notifications.server)"
            continue
        elif [ -n "$comm" ]; then
            warn "notifications.server is shell, but $comm holds the notification service"
            fix "the shell waits and takes over when it is let go of; until then $comm draws them"
            continue
        fi
    fi
    # plasmashell holding one of these while it is on our package holds a
    # leftover: the service was created by the previous package's tray and
    # outlived it, because switching packages live does not restart
    # plasmashell. The name is taken, so nothing else can serve it -- and for
    # notifications, the applet that draws popups is gone: they are accepted
    # and never shown.
    if [ "$comm" = plasmashell ] && [ "$live_pkg" = "$SHELL_PACKAGE_ID" ]; then
        if [ "$name" = org.freedesktop.Notifications ]; then
            bad "notifications: held by plasmashell with no notifications applet -- accepted, never shown"
        else
            warn "$what: held by plasmashell, left over from the previous panel"
        fi
        fix "restart plasmashell so the shell can host Plasma's own: systemctl --user restart plasma-plasmashell"
    elif [ "$comm" = quickshell ]; then
        # Ours is Quickshell too, and so is caelestia's bar: name the config.
        cfg=$(bus_status_field "$name" CommandLine \
              | grep -o -- '-p [^ ]*' | sed 's/^-p //; s|/shell.qml$||; s|.*/||')
        ok "$what: provided by quickshell (${cfg:-unknown config})"
    elif [ -n "$comm" ]; then
        ok "$what: provided by $comm"
    elif [ "$name" = org.freedesktop.Notifications ]; then
        bad "nothing provides notifications: every notification sent now is dropped"
        fix "under the quickshell renderer the shell hosts Plasma's own: $ALIAS start (and services.hostPlasma on)"
    else
        warn "nothing provides $what"
        fix "the clipboard widget keeps a history of its own meanwhile; Plasma's comes back with the shell"
    fi
done

# Which clipboard history Meta+V actually shows, which is a setting and not
# whoever happens to hold the name. Worth saying because the two differ where
# it matters: Klipper's DBus hands out text only, so an image in its history
# can be seen and never chosen.
clip_history=$(jq -r '.clipboard.history // "own"' <<< "$merged_cfg" 2>/dev/null)
klipper_up=$(busctl --user status org.kde.klipper >/dev/null 2>&1 && echo yes || echo no)
case "$clip_history" in
    own)    ok "clipboard history shown: this shell's own (images can be chosen)" ;;
    plasma) if [ "$klipper_up" = yes ]; then
                ok "clipboard history shown: Klipper's (clipboard.history), text only"
            else
                warn "clipboard.history is 'plasma' and Klipper is not running: the menu is empty"
                fix "ours has one meanwhile: $ALIAS settings services, clipboard.history 'own' or 'auto'"
            fi ;;
    auto)   if [ "$klipper_up" = yes ]; then
                ok "clipboard history shown: Klipper's while it runs (clipboard.history auto) -- its images cannot be chosen"
            else
                ok "clipboard history shown: this shell's own (Klipper is not running)"
            fi ;;
    *)      warn "clipboard.history is '$clip_history', which is not a value this knows"
            fix "one of: own, auto, plasma" ;;
esac

# ------------------------------------------------------------------- optional

section "optional components"

for pair in "union:a Qt style, selectable as the widget style" \
            "fuzzel:an alternative launcher" \
            "rofi:an alternative launcher" \
            "claude:the claude-code AI provider" \
            "ollama:the ollama AI provider" \
            "wl-copy:the clipboard AI provider"; do
    bin=${pair%%:*}; desc=${pair#*:}
    if command -v "$bin" >/dev/null 2>&1 || pacman -Qq "$bin" >/dev/null 2>&1; then
        ok "$bin present ($desc)"
    else
        printf '  %s--%s    %s not installed (%s)\n' "$_c_dim" "$_c_off" "$bin" "$desc"
    fi
done

# ------------------------------------------------------------------- verdict

echo
if [ "$problems" -gt 0 ]; then
    log_error "$problems problem(s), $warnings warning(s)"
    exit 1
fi
log_step "no problems${warnings:+, $warnings warning(s)}"

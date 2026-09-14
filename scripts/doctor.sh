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
if [ -f "$preview_module" ]; then
    ok "the preview module is installed"
else
    warn "no preview module: windows are drawn as their application's icon"
    fix "build it with: make plugin  (needs cmake and Qt 6 development files)"
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

profile_file="$CONFIG_DIR/profiles/default/shell.json"
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

shell_pkg=$(kreadconfig6 --file plasmashellrc --group Shell --key ShellPackage --default 'org.kde.plasma.desktop')
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
configured_renderer=$(jq -r '.panel.renderer // "quickshell"' "$CONFIG_DIR/profiles/default/shell.json" 2>/dev/null || echo unknown)
[ "$configured_renderer" = "null" ] && configured_renderer=$(jq -r '.panel.renderer // "quickshell"' "$defaults_file" 2>/dev/null || echo quickshell)

case "$configured_renderer" in
    plasma)     expected_pkg="$PLASMA_SHELL_PACKAGE_ID" ;;
    none)       expected_pkg="org.kde.plasma.desktop" ;;
    unknown)    expected_pkg="$shell_pkg" ;;
    *)          expected_pkg="$SHELL_PACKAGE_ID" ;;
esac

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

others=$(pgrep -a -x quickshell 2>/dev/null | grep -v "quickshell/$SLUG" || true)
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
bound=$(kreadconfig6 --file kglobalshortcutsrc --group "$SLUG" --key launcher --default '' 2>/dev/null)
for k in search settings ask clipboard sidebar keys switcher; do
    [ -n "$bound" ] && break
    bound=$(kreadconfig6 --file kglobalshortcutsrc --group "$SLUG" --key "$k" --default '' 2>/dev/null)
done
legacy=""
for k in launcher search settings ask clipboard sidebar keys switcher; do
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
    "$CONFIG_DIR/profiles/default/shell.json" 2>/dev/null || echo "")
[ -n "$profile_entries" ] || profile_entries=$(jq -r '[.bar.entries[]? | select(.enabled != false) | .id] | join(" ")' \
    "$defaults_file" 2>/dev/null || echo "")

script_loaded=$(qdbus6 org.kde.KWin /Scripting org.kde.kwin.Scripting.isScriptLoaded "$KWIN_SCRIPT_ID" 2>/dev/null || echo unknown)
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

osd_enabled=$(jq -r '.osd.enabled // false' "$CONFIG_DIR/profiles/default/shell.json" 2>/dev/null || echo false)
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
    live_pkg=$(kreadconfig6 --file plasmashellrc --group Shell --key ShellPackage --default org.kde.plasma.desktop)
    case " ${LOCKSCREEN_PACKAGES[*]} " in
        *" $live_pkg "*) ;;
        *) warn "plasmashell is on $live_pkg, so its lock screen is drawn rather than ours" ;;
    esac
fi

# --------------------------------------------------------------- diagnostics

section "diagnostic reports"

reports="$STATE_DIR/diagnostics"
report_count=$(ls -1 "$reports" 2>/dev/null | wc -l)
if [ "$report_count" -gt 0 ]; then
    ok "$report_count report(s) in $reports"
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
    reported=$(grep -rlxF "crash:  $newest" "$STATE_DIR/diagnostics"/*/error.txt 2>/dev/null | head -1)
    if [ -n "$reported" ]; then
        ok "the newest crash has a report: $(basename "$(dirname "$reported")")"
    else
        warn "no report written for the newest crash"
        fix "the shell writes one when it comes back; this dump predates that, or the shell has not restarted since"
        fix "write one now: $ALIAS report create --crash $newest"
    fi
    fix "clear them:    $ALIAS crash remove --all"
fi

# ----------------------------------------------------------------- AI assist

section "AI assist"

merged_cfg=$(jq -s '.[0] * (.[1] // {})' "$defaults_file" "$profile_file" 2>/dev/null || cat "$defaults_file" 2>/dev/null || echo '{}')
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
        n=$(quickshell ipc --path "$QS_CONFIG_DIR/shell.qml" call notifications count 2>/dev/null || echo '?')
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
live_pkg=$(kreadconfig6 --file plasmashellrc --group Shell --key ShellPackage 2>/dev/null)
notif_server=$(jq -r '.notifications.server // "plasma"' <<< "$merged_cfg" 2>/dev/null)
for pair in "org.freedesktop.Notifications:notifications" "org.kde.klipper:clipboard history"; do
    name=${pair%%:*}; what=${pair#*:}
    comm=$(busctl --user status "$name" 2>/dev/null | sed -n 's/^Comm=//p')
    # Asked to serve them itself, the shell waits for whoever holds the name
    # rather than taking it -- so the one thing worth saying is who that is.
    if [ "$name" = org.freedesktop.Notifications ] && [ "$notif_server" = shell ]; then
        if busctl --user status "$name" 2>/dev/null | sed -n 's/^CommandLine=//p' | grep -qF -- "$QS_CONFIG_DIR/"; then
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
        cfg=$(busctl --user status "$name" 2>/dev/null | sed -n 's/^CommandLine=//p' \
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

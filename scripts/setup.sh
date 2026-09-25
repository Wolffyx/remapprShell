#!/usr/bin/env bash
# The guided install: every choice this shell makes at install time, asked once
# and applied in one pass.
#
#   --unattended        ask nothing; take every default
#   --dry-run           say what would run, run nothing
#   --no-snapshot       skip the restore point (not advised)
#   --no-preflight      skip the machine check (you have already run it)
#   --ui <front end>    kdialog | whiptail | dialog | plain | none
#
# The steps are the commands a person would otherwise run by hand, in the order
# the handbook gives them: what the distribution provides, preflight, a
# restore point, install, renderer, the window list, window previews, theme,
# shortcuts, Alt+Tab, start at login. Nothing here reimplements any of
# them -- each step shells out to the script that owns it, so the guided path
# and the manual one cannot drift.
#
# Nothing is written until the summary is confirmed. Every question is asked
# first, the plan is shown, and one answer applies it -- the same shape as the
# first-run wizard, for the same reason: an installer that writes as it goes
# leaves a half-configured desktop when somebody changes their mind on step
# four.
set -uo pipefail

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
source "$REPO_ROOT/scripts/lib/log.sh"

# What the distribution provides comes first, before brand.sh: that needs jq,
# which is one of the things deps.sh installs. The bootstrap (install.sh at
# the top of the tree) has usually done this already, and then it is one
# quiet check. A dry run only says what is missing.
_dry=0; _yes=()
for _a in "$@"; do
    case "$_a" in
        --dry-run)    _dry=1 ;;
        --unattended) _yes=(--yes) ;;
    esac
done
if ! _missing=$("$REPO_ROOT/scripts/deps.sh" check); then
    if [ $_dry = 1 ]; then
        log_warn "dry run: missing, and not installed: $(printf '%s ' $_missing)"
    else
        "$REPO_ROOT/scripts/deps.sh" install "${_yes[@]}" \
            || die "the shell cannot run without those; nothing else was changed"
    fi
fi

source "$REPO_ROOT/scripts/lib/brand.sh"
source "$REPO_ROOT/scripts/lib/dialog.sh"

DRY=0
SNAPSHOT=1
PREFLIGHT=1

while [ $# -gt 0 ]; do
    case "$1" in
        --unattended)  export "${ENV_PREFIX}_UI=none" ;;
        --dry-run)     DRY=1 ;;
        --no-snapshot) SNAPSHOT=0 ;;
        --no-preflight) PREFLIGHT=0 ;;
        --ui)          [ $# -ge 2 ] || die "--ui needs a front end"
                       export "${ENV_PREFIX}_UI=$2"; shift ;;
        -h|--help)     sed -n '2,11p' "${BASH_SOURCE[0]}" | sed 's/^# \?//'; exit 0 ;;
        *)             die "unknown argument: $1" ;;
    esac
    shift
done

# The front end, decided once here, now that --ui and --unattended have had
# their say. Every question below asks inside `$(...)`, where it could not be
# remembered, and detection is a kdialog lookup and a terminal check a time.
ui_backend >/dev/null

# Every key this setup can bind, and what it binds it to. These are the
# defaults a fresh machine gets; anything already held by another shell is
# taken, said so, and given back by `shortcuts revert`.
declare -A KEYS=(
    [launcher]="Meta"
    [search]="Meta+Space"
    [settings]="Meta+Shift+R"
    [clipboard]="Meta+V"
    [sidebar]="Meta+S"
    [keys]="Meta+/"
)
KEY_ORDER=(launcher search settings clipboard sidebar keys)
KEYS_ON_BY_DEFAULT="launcher search"

# --- running things -------------------------------------------------------

FAILED=()

run() {
    if [ "$DRY" = 1 ]; then
        printf '  would run: %s\n' "$*" >&2
        return 0
    fi
    log_debug "run: $*"
    "$@"
}

# A step that may fail without taking the rest of the install with it: an
# install whose theme did not apply is still an install, and the summary is
# where that is reported rather than an exit in the middle.
step() {
    local what=$1; shift
    ui_note "$what"
    if ! run "$@"; then
        log_warn "$what: failed"
        FAILED+=("$what")
        return 1
    fi
}

cancelled() { log_info "nothing was changed."; exit 0; }

# The user's systemd is not sandboxed by a throwaway HOME: without a session
# (session_available, brand.sh) a unit is neither started nor enabled. The
# uninstall's first test run stopped the real shell for want of this.
in_session() {
    if session_available; then
        "$@"
    else
        log_info "no session; not run: $*"
    fi
}

# --- questions ------------------------------------------------------------

ui_info "$DISPLAY_NAME $VERSION" \
"This sets up $DISPLAY_NAME on this machine.

Every question is asked first. Nothing is written until you confirm the
summary at the end, and a restore point is taken before the first change."

if [ "$PREFLIGHT" = 1 ]; then
    ui_note "checking this machine"
    if ! "$REPO_ROOT/scripts/preflight.sh"; then
        # A machine that failed the check can still be set up -- a missing
        # optional tool is a warning, not a wall -- but the default is no, and
        # a front end with nobody behind it takes the default.
        if ! ui_yesno "Preflight found problems (see the terminal). Set up anyway?" no; then
            cancelled
        fi
    fi
fi

mode=$(ui_menu "Install" "How should the shell be installed?" copy \
    copy "Copy the files (an ordinary install)" \
    link "Symlink this checkout (development)") || cancelled

renderer=$(ui_menu "The panel" "What should draw the panel?" quickshell \
    quickshell "This shell draws it (the design)" \
    plasma     "Plasma draws it, from our layout" \
    none       "Leave whatever draws it now") || cancelled

keys_chosen=$(ui_checklist "Keys" "Which keys should this shell take?
A key another shell holds is taken from it, and given back by '$ALIAS shortcuts revert'." \
    "$KEYS_ON_BY_DEFAULT" \
    launcher  "${KEYS[launcher]} -- the application menu" \
    search    "${KEYS[search]} -- search" \
    settings  "${KEYS[settings]} -- the settings window" \
    clipboard "${KEYS[clipboard]} -- clipboard history" \
    sidebar   "${KEYS[sidebar]} -- the sidebar" \
    keys      "${KEYS[keys]} -- the key sheet") || cancelled

alttab=$(ui_menu "Alt+Tab" "Who switches windows?" plasma \
    plasma "KWin switches them, drawing our layout (recommended)" \
    shell  "This shell's own switcher takes the key" \
    none   "Leave Alt+Tab alone") || cancelled

# KWin knows what windows are open and the shell cannot ask it directly: a
# small KWin script tells it. Without that the taskbar is empty, which is why
# the answer is yes unless someone says otherwise.
ui_yesno "Show the open windows on the taskbar? (a small KWin script tells the shell about them)" yes
windowlist=$?; [ $windowlist -gt 1 ] && cancelled

# Compiled, and the one step that needs development packages -- a compiler,
# CMake, Qt's and KF6's headers -- which are installed with it. Without it
# the shell runs, with no live previews and no held-key detection.
ui_yesno "Build the window previews and the key module? (installs a compiler and Qt's development files, if missing)" yes
plugin=$?; [ $plugin -gt 1 ] && cancelled

ui_yesno "Apply the $DISPLAY_NAME look and feel? (colours, icons, splash, Alt+Tab's look)" yes
theme=$?; [ $theme -gt 1 ] && cancelled

ui_yesno "Start $DISPLAY_NAME at login?" yes
autostart=$?; [ $autostart -gt 1 ] && cancelled

# --- the plan -------------------------------------------------------------

plan=$(
    printf '%s\n' "install:    $mode"
    printf '%s\n' "panel:      $renderer"
    printf '%s\n' "keys:       $(printf '%s ' $keys_chosen | sed 's/ $//'; [ -n "$keys_chosen" ] || printf none)"
    printf '%s\n' "windows:    $([ $windowlist = 0 ] && echo 'listed on the taskbar' || echo 'not listed')"
    printf '%s\n' "previews:   $([ $plugin = 0 ] && echo 'built' || echo 'not built')"
    printf '%s\n' "Alt+Tab:    $alttab"
    printf '%s\n' "theme:      $([ $theme = 0 ] && echo 'apply' || echo 'leave alone')"
    printf '%s\n' "at login:   $([ $autostart = 0 ] && echo 'enabled' || echo 'not enabled')"
    printf '%s\n' "snapshot:   $([ $SNAPSHOT = 1 ] && echo 'yes, before anything' || echo 'NO -- nothing to roll back to')"
)

printf '\n%s\n' "$plan" >&2
ui_yesno "Apply this?

$plan" yes || cancelled

# --- applying -------------------------------------------------------------

[ "$DRY" = 1 ] && log_warn "dry run: nothing will be changed"

if [ "$SNAPSHOT" = 1 ]; then
    step "restore point" "$REPO_ROOT/scripts/snapshot.sh" create "before-setup"
fi

case "$mode" in
    copy) step "installing"      "$REPO_ROOT/scripts/install.sh" --copy ;;
    link) step "linking"         "$REPO_ROOT/scripts/install.sh" --link ;;
esac

[ $windowlist = 0 ] && step "the window list" "$REPO_ROOT/scripts/windows.sh" enable

# --yes: the plan that said "built" was the question. deps.sh returns at once
# when everything is there.
if [ $plugin = 0 ]; then
    step "build dependencies" "$REPO_ROOT/scripts/deps.sh" install --build --yes \
        && step "window previews and the key module" make -C "$REPO_ROOT" --no-print-directory plugin
fi

[ $theme = 0 ] && step "the look and feel" "$REPO_ROOT/scripts/theme.sh" apply

for action in "${KEY_ORDER[@]}"; do
    printf '%s\n' $keys_chosen | grep -qxF "$action" || continue
    step "${KEYS[$action]} -> $action" "$REPO_ROOT/scripts/shortcuts.sh" set "$action" "${KEYS[$action]}"
done

case "$alttab" in
    plasma) step "Alt+Tab, KWin's, in our layout" "$REPO_ROOT/scripts/switcher.sh" use plasma ;;
    shell)  step "Alt+Tab, ours"                  "$REPO_ROOT/scripts/switcher.sh" use shell ;;
esac

# The shell is started before the panel is handed to it: renderer.sh refuses
# to switch to a shell that is not running, rather than leave the screen with
# no panel -- and it was, on the first real install (2026-09-25), because
# this step came last. Switching also restarts plasmashell, which is what
# shows the look and feel applied above.
#
# Restarted, not only started: over a shell already running -- the one-line
# install run again, a reinstall -- `enable --now` leaves the old one running
# the old code, without the previews just built. Nothing is left for the
# person to run afterwards; that is the point of the whole script.
if [ $autostart = 0 ]; then
    step "starting at login" in_session systemctl --user enable "$SYSTEMD_UNIT"
fi
if [ $autostart = 0 ] || [ "$renderer" = quickshell ]; then
    step "starting the shell" in_session systemctl --user restart "$SYSTEMD_UNIT"
fi

[ "$renderer" != none ] && step "the panel" "$REPO_ROOT/scripts/renderer.sh" set "$renderer"

if [ $autostart = 0 ]; then
    # Separate from the shell, and enabled with it: it settles light and dark
    # before the session's applications start, which is the one moment the
    # shell itself is too late for. It writes nothing unless something is
    # actually switching -- Plasma's own day/night switch, or
    # `theme.desktop.followMode` -- so enabling it is not a decision about
    # whether the desktop is themed, or about who switches it.
    step "settling light and dark at login" \
        in_session systemctl --user enable "$SLUG-theme.service"
else
    log_info "not enabled at login; '$ALIAS start' runs it by hand"
fi

# --- what happened --------------------------------------------------------

if [ ${#FAILED[@]} -gt 0 ]; then
    ui_error "Set up, with ${#FAILED[@]} step(s) that failed:

$(printf '  %s\n' "${FAILED[@]}")

'$ALIAS doctor' says what is wrong, and '$ALIAS restore' puts KDE back."
    exit 1
fi

ui_info "$DISPLAY_NAME" \
"Set up, and running$([ $autostart = 0 ] && printf ' -- it starts at login too'). There is nothing else to do.

Whenever you like:
  $ALIAS settings         change any of this
  $ALIAS lockscreen try   try the lock screen, before '$ALIAS lockscreen enable'
  $ALIAS update           bring it up to date
  $ALIAS uninstall        take it off again"

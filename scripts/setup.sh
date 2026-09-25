#!/usr/bin/env bash
# The guided install: every choice this shell makes at install time, asked once
# and applied in one pass.
#
#   --unattended        ask nothing; take every default
#   --dry-run           say what would run, run nothing
#   --no-snapshot       skip the restore point (not advised)
#   --no-preflight      skip the machine check (you have already run it)
#   --ui <front end>    gui | kdialog | whiptail | dialog | plain | none
#   --progress          print ::step, ::ok, ::fail and ::done lines on stdout,
#                       for the installer window that runs this
#   --describe          print the keys it offers, as JSON, and stop
#
# Any question can be answered in advance, and is then not asked:
#
#   --mode copy|link   --renderer quickshell|plasma|none   --keys "<ids>"|none
#   --alttab plasma|shell|none   --window-list yes|no   --previews yes|no
#   --theme yes|no   --autostart yes|no
#
# In a graphical session, with nothing answered in advance, the questions are
# asked in the installer window (shell/installer.qml) rather than in kdialog:
# it runs this script again with every answer given, and draws its progress.
# `--ui kdialog` still asks them one dialog at a time.
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
PROGRESS=0
DESCRIBE=0
GUI=auto
declare -A ANSWER=()

# An answer given in advance, checked against what the question offers.
answer() {   # <key> <value> <allowed...>
    local key=$1 value=$2 ok
    shift 2
    for ok in "$@"; do
        [ "$value" = "$ok" ] && { ANSWER[$key]=$value; return; }
    done
    die "--$key: '$value' is not one of: $*"
}

while [ $# -gt 0 ]; do
    case "$1" in
        --unattended)  export "${ENV_PREFIX}_UI=none"; GUI=no ;;
        --dry-run)     DRY=1 ;;
        --no-snapshot) SNAPSHOT=0 ;;
        --no-preflight) PREFLIGHT=0 ;;
        --progress)    PROGRESS=1 ;;
        --describe)    DESCRIBE=1; GUI=no ;;
        --ui)          [ $# -ge 2 ] || die "--ui needs a front end"
                       if [ "$2" = gui ]; then GUI=yes; else export "${ENV_PREFIX}_UI=$2"; GUI=no; fi
                       shift ;;
        --mode|--renderer|--keys|--alttab|--window-list|--previews|--theme|--autostart)
                       [ $# -ge 2 ] || die "$1 needs a value"
                       case "$1" in
                           --mode)        answer mode "$2" copy link ;;
                           --renderer)    answer renderer "$2" quickshell plasma none ;;
                           --keys)        ANSWER[keys]=$2 ;;
                           --alttab)      answer alttab "$2" plasma shell none ;;
                           --window-list) answer window-list "$2" yes no ;;
                           --previews)    answer previews "$2" yes no ;;
                           --theme)       answer theme "$2" yes no ;;
                           --autostart)   answer autostart "$2" yes no ;;
                       esac
                       shift ;;
        -h|--help)     sed -n '2,30p' "${BASH_SOURCE[0]}" | sed 's/^# \?//'; exit 0 ;;
        *)             die "unknown argument: $1" ;;
    esac
    shift
done

# --- the installer window -------------------------------------------------

# Asked there, in a graphical session, unless a front end was named, the
# answers were given, or this is a dry run (whose point is the text). The
# window is Quickshell's, which deps.sh has just made sure of, run from this
# tree: the shell is not installed yet. It runs this script again with the
# answers, so what is applied is exactly what the terminal would apply.
if [ "$GUI" != no ] && [ ${#ANSWER[@]} -eq 0 ] && [ "$DRY" = 0 ]; then
    if [ "$GUI" = yes ] || { [ -n "${WAYLAND_DISPLAY:-}" ] && [ -z "${!_ui_var:-}" ]; }; then
        if command -v quickshell >/dev/null 2>&1 && [ -f "$REPO_ROOT/shell/installer.qml" ]; then
            "$REPO_ROOT/scripts/gen-branding.sh" >/dev/null && "$REPO_ROOT/scripts/gen-qmldir.sh" >/dev/null \
                || die "could not prepare the installer window"
            # What the window passes back to this script: the switches that
            # are not questions.
            extra=()
            [ $SNAPSHOT = 0 ] && extra+=(--no-snapshot)
            export "${ENV_PREFIX}_SETUP_EXTRA=${extra[*]}"
            export "${ENV_PREFIX}_INSTALLER_SOURCE=$REPO_ROOT"
            export QML2_IMPORT_PATH="$REPO_ROOT/shell${QML2_IMPORT_PATH:+:$QML2_IMPORT_PATH}"
            export QS_NO_RELOAD_POPUP=1
            exec quickshell -p "$REPO_ROOT/shell/installer.qml"
        fi
        [ "$GUI" = yes ] && die "the installer window needs Quickshell and a graphical session"
    fi
fi

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
declare -A KEY_WHAT=(
    [launcher]="the application menu"
    [search]="search"
    [settings]="the settings window"
    [clipboard]="clipboard history"
    [sidebar]="the sidebar"
    [keys]="the key sheet"
)

# The installer window's list of keys comes from here, so the two cannot
# offer different ones.
if [ "$DESCRIBE" = 1 ]; then
    for action in "${KEY_ORDER[@]}"; do
        on=false
        printf '%s\n' $KEYS_ON_BY_DEFAULT | grep -qxF "$action" && on=true
        jq -nc --arg id "$action" --arg key "${KEYS[$action]}" --arg what "${KEY_WHAT[$action]}" \
              --argjson on "$on" '{id: $id, key: $key, what: $what, on: $on}'
    done | jq -sc '{keys: .}'
    exit 0
fi

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
# ::step, ::ok, ::fail and ::done on stdout, for the installer window. Only
# with --progress: a person at a terminal reads the ==> lines instead.
progress() { [ "$PROGRESS" = 1 ] && printf '::%s %s\n' "$1" "$2"; return 0; }

step() {
    local what=$1; shift
    ui_note "$what"
    progress step "$what"
    if ! run "$@"; then
        log_warn "$what: failed"
        FAILED+=("$what")
        progress fail "$what"
        return 1
    fi
    progress ok "$what"
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

given() { [ -n "${ANSWER[$1]+x}" ]; }
# yes/no answers in the form ui_yesno returns them: 0 for yes, 1 for no.
yesno_of() { [ "${ANSWER[$1]}" = yes ] && echo 0 || echo 1; }

given mode && mode=${ANSWER[mode]} || mode=$(ui_menu "Install" "How should the shell be installed?" copy \
    copy "Copy the files (an ordinary install)" \
    link "Symlink this checkout (development)") || cancelled

given renderer && renderer=${ANSWER[renderer]} || renderer=$(ui_menu "The panel" "What should draw the panel?" quickshell \
    quickshell "This shell draws it (the design)" \
    plasma     "Plasma draws it, from our layout" \
    none       "Leave whatever draws it now") || cancelled

if given keys; then
    keys_chosen=${ANSWER[keys]}
    [ "$keys_chosen" = none ] && keys_chosen=""
else
keys_chosen=$(ui_checklist "Keys" "Which keys should this shell take?
A key another shell holds is taken from it, and given back by '$ALIAS shortcuts revert'." \
    "$KEYS_ON_BY_DEFAULT" \
    launcher  "${KEYS[launcher]} -- ${KEY_WHAT[launcher]}" \
    search    "${KEYS[search]} -- ${KEY_WHAT[search]}" \
    settings  "${KEYS[settings]} -- ${KEY_WHAT[settings]}" \
    clipboard "${KEYS[clipboard]} -- ${KEY_WHAT[clipboard]}" \
    sidebar   "${KEYS[sidebar]} -- ${KEY_WHAT[sidebar]}" \
    keys      "${KEYS[keys]} -- ${KEY_WHAT[keys]}") || cancelled
fi

given alttab && alttab=${ANSWER[alttab]} || alttab=$(ui_menu "Alt+Tab" "Who switches windows?" plasma \
    plasma "KWin switches them, drawing our layout (recommended)" \
    shell  "This shell's own switcher takes the key" \
    none   "Leave Alt+Tab alone") || cancelled

# KWin knows what windows are open and the shell cannot ask it directly: a
# small KWin script tells it. Without that the taskbar is empty, which is why
# the answer is yes unless someone says otherwise.
if given window-list; then windowlist=$(yesno_of window-list); else
ui_yesno "Show the open windows on the taskbar? (a small KWin script tells the shell about them)" yes
windowlist=$?; [ $windowlist -gt 1 ] && cancelled
fi

# Compiled, and the one step that needs development packages -- a compiler,
# CMake, Qt's and KF6's headers -- which are installed with it. Without it
# the shell runs, with no live previews and no held-key detection.
if given previews; then plugin=$(yesno_of previews); else
ui_yesno "Build the window previews and the key module? (installs a compiler and Qt's development files, if missing)" yes
plugin=$?; [ $plugin -gt 1 ] && cancelled
fi

if given theme; then theme=$(yesno_of theme); else
ui_yesno "Apply the $DISPLAY_NAME look and feel? (colours, icons, splash, Alt+Tab's look)" yes
theme=$?; [ $theme -gt 1 ] && cancelled
fi

if given autostart; then autostart=$(yesno_of autostart); else
ui_yesno "Start $DISPLAY_NAME at login?" yes
autostart=$?; [ $autostart -gt 1 ] && cancelled
fi

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
# Every question answered in advance is the installer window, whose review
# page was this question; asking it again, with nobody at a terminal, would
# be taken as no.
if [ ${#ANSWER[@]} -lt 8 ]; then
    ui_yesno "Apply this?

$plan" yes || cancelled
fi

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

progress done "${#FAILED[@]}"

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

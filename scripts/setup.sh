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
# the handbook gives them: preflight, a restore point, install, renderer,
# theme, shortcuts, Alt+Tab, start at login. Nothing here reimplements any of
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

ui_yesno "Apply the $DISPLAY_NAME look and feel? (colours, icons, splash, Alt+Tab's look)" yes
theme=$?; [ $theme -gt 1 ] && cancelled

ui_yesno "Start $DISPLAY_NAME at login?" yes
autostart=$?; [ $autostart -gt 1 ] && cancelled

# --- the plan -------------------------------------------------------------

plan=$(
    printf '%s\n' "install:    $mode"
    printf '%s\n' "panel:      $renderer"
    printf '%s\n' "keys:       $(printf '%s ' $keys_chosen | sed 's/ $//'; [ -n "$keys_chosen" ] || printf none)"
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

[ "$renderer" != none ] && step "the panel" "$REPO_ROOT/scripts/renderer.sh" set "$renderer"

[ $theme = 0 ] && step "the look and feel" "$REPO_ROOT/scripts/theme.sh" apply

for action in "${KEY_ORDER[@]}"; do
    printf '%s\n' $keys_chosen | grep -qxF "$action" || continue
    step "${KEYS[$action]} -> $action" "$REPO_ROOT/scripts/shortcuts.sh" set "$action" "${KEYS[$action]}"
done

case "$alttab" in
    plasma) step "Alt+Tab, KWin's, in our layout" "$REPO_ROOT/scripts/switcher.sh" use plasma ;;
    shell)  step "Alt+Tab, ours"                  "$REPO_ROOT/scripts/switcher.sh" use shell ;;
esac

if [ $autostart = 0 ]; then
    step "starting at login" systemctl --user enable --now "$SYSTEMD_UNIT"
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
"Set up.

  $ALIAS doctor     check everything
  $ALIAS settings   change any of this
  $ALIAS restore    put KDE back the way it was"

#!/usr/bin/env bash
# Takes the shell off this machine, and gives Plasma back what it had.
#
#   --yes       ask nothing
#   --dry-run   say what would run, run nothing
#   --purge     also remove the configuration, the restore points and the
#               fetched source -- what a reinstall would otherwise pick up
#
# The setup's steps, undone in reverse, each by the script that made the
# change in the first place -- so what is put back is what each of them
# recorded in its ledger, key by key, and nothing another program changed
# since is overwritten. A step that fails is reported at the end and does not
# stop the rest: half an uninstall is worse than an uninstall with a note.
#
# Packages are left alone. jq, git and Qt are not ours, and something else
# may well use them; the closing note says so.
#
# `restore --preinstall` is the other way back: it puts whole files back as
# they were before the first install, including changes made since by
# anything else. This undoes only what the shell did.
set -uo pipefail

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
source "$REPO_ROOT/scripts/lib/log.sh"
source "$REPO_ROOT/scripts/lib/brand.sh"
source "$REPO_ROOT/scripts/lib/dialog.sh"

DRY=0
PURGE=0
# The answer the confirmation takes with nobody to ask: no, unless --yes said
# otherwise. An uninstall that happens because no terminal was attached is
# the one thing this must never do.
ANSWER=no
# --no-summary: reinstall.sh's, which has a setup still to run -- a dialog
# saying "uninstalled, nothing else to do" in the middle of it would be wrong
# twice over.
SUMMARY=1
while [ $# -gt 0 ]; do
    case "$1" in
        --yes)     export "${ENV_PREFIX}_UI=none"; ANSWER=yes ;;
        --dry-run) DRY=1 ;;
        --purge)   PURGE=1 ;;
        --no-summary) SUMMARY=0 ;;
        -h|--help) sed -n '2,9p' "${BASH_SOURCE[0]}" | sed 's/^# \?//'; exit 0 ;;
        *)         die "unknown argument: $1" ;;
    esac
    shift
done
ui_backend >/dev/null

FAILED=()

run() {
    if [ "$DRY" = 1 ]; then
        printf '  would run: %s\n' "$*" >&2
        return 0
    fi
    "$@"
}

step() {
    local what=$1; shift
    ui_note "$what"
    run "$@" || { log_warn "$what: failed"; FAILED+=("$what"); }
}

# --- asking ---------------------------------------------------------------

kept="Kept: your settings and restore points ($CONFIG_DIR, $STATE_DIR), and the source."
[ $PURGE = 1 ] && kept="Also removed: your settings, every restore point, and the source ($DATA_DIR)."

ui_yesno "Uninstall $DISPLAY_NAME?

Plasma's own panel, keys, Alt+Tab, lock screen and look and feel are put back,
the shell is stopped and its files are removed.

$kept" "$ANSWER" || { log_info "nothing was changed."; exit 0; }

[ "$DRY" = 1 ] && log_warn "dry run: nothing will be changed"

# Asked now: with --purge, deps.sh is gone with the source by the end.
family=$("$REPO_ROOT/scripts/deps.sh" family 2>/dev/null)

# --- undoing ----------------------------------------------------------------

# The panel first, while the shell still draws one: Plasma's comes back before
# ours goes. It restarts plasmashell, which also shows the look and feel put
# back below it -- so the look and feel goes before it.
step "the look and feel"          "$REPO_ROOT/scripts/theme.sh" revert
step "Plasma's panel"             "$REPO_ROOT/scripts/renderer.sh" revert
# Behind session_available, like everything else that reaches the running
# session: a throwaway HOME does not sandbox the user's systemd, and the
# suite's first run of this stopped and disabled the real shell. The unit
# files go with the installed files either way.
if session_available; then
    step "stopping the shell"     systemctl --user disable --now "$SYSTEMD_UNIT" "$SLUG-theme.service"
fi
step "the lock screen"            "$REPO_ROOT/scripts/lockscreen.sh" disable
step "Alt+Tab"                    "$REPO_ROOT/scripts/switcher.sh" revert
step "the keys"                   "$REPO_ROOT/scripts/shortcuts.sh" revert
step "the screen edges"           "$REPO_ROOT/scripts/edges.sh" revert
step "KWin's window behaviour"    "$REPO_ROOT/scripts/windows.sh" behaviour revert
step "the window list"            "$REPO_ROOT/scripts/windows.sh" disable
step "window previews and the key module" \
    make -C "$REPO_ROOT" --no-print-directory plugin-clean
step "the installed files"        "$REPO_ROOT/scripts/install.sh" --uninstall

if [ $PURGE = 1 ]; then
    # Last: the ledgers every revert above read from are in STATE_DIR, and
    # this very script is in DATA_DIR's source -- which bash, reading it as
    # it goes, can still finish from once it is unlinked.
    step "settings and restore points" rm -rf "$CONFIG_DIR" "$STATE_DIR" "$XDG_STATE_HOME/$SLUG-snapshots"
    step "the source" rm -rf "$DATA_DIR"
fi

# --- what happened --------------------------------------------------------

note="Packages were left installed; they may be used by other things.
To remove Quickshell as well, use your package manager ($family)."

if [ $SUMMARY = 0 ]; then
    [ ${#FAILED[@]} -eq 0 ] || log_warn "uninstall steps that failed: ${FAILED[*]}"
    [ ${#FAILED[@]} -eq 0 ]
    exit
fi

if [ ${#FAILED[@]} -gt 0 ]; then
    ui_error "Uninstalled, with ${#FAILED[@]} step(s) that failed:

$(printf '  %s\n' "${FAILED[@]}")

$note"
    exit 1
fi

ui_info "$DISPLAY_NAME" \
"Uninstalled: Plasma is drawing its own panel again. There is nothing else to do.

$note"

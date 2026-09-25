#!/usr/bin/env bash
# Takes the shell off and puts it back, from the source already here.
#
#   --yes       ask nothing: the setup takes its defaults
#   --fresh     also start from no settings (restore points are kept)
#   --dry-run   say what would run, run nothing
#
# The uninstall, then the guided setup -- the same two scripts, run in turn,
# so a reinstall is exactly what doing both by hand would be. When it
# finishes the shell is running, drawing the panel, and starts at login:
# nothing is left to run afterwards.
#
# The setup asks its questions after the uninstall, so answering no at its
# summary leaves the shell uninstalled. That is said up front, and again if
# it happens, with the one line that finishes the job.
#
# For a newer version, run the one-line install again, or `update`: this
# reinstalls what is here.
set -uo pipefail

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
source "$REPO_ROOT/scripts/lib/log.sh"
source "$REPO_ROOT/scripts/lib/brand.sh"
source "$REPO_ROOT/scripts/lib/dialog.sh"

DRY=0
FRESH=0
YES=0
ANSWER=no
while [ $# -gt 0 ]; do
    case "$1" in
        --yes)     YES=1; ANSWER=yes; export "${ENV_PREFIX}_UI=none" ;;
        --fresh)   FRESH=1 ;;
        --dry-run) DRY=1 ;;
        -h|--help) sed -n '2,7p' "${BASH_SOURCE[0]}" | sed 's/^# \?//'; exit 0 ;;
        *)         die "unknown argument: $1" ;;
    esac
    shift
done
ui_backend >/dev/null

settings="Your settings are kept."
[ $FRESH = 1 ] && settings="Your settings are removed: it starts from the defaults. Restore points are kept."

ui_yesno "Reinstall $DISPLAY_NAME?

It is uninstalled, then set up again from $REPO_ROOT.
$settings
The setup's questions come after the uninstall; answering no at its summary
leaves the shell uninstalled." "$ANSWER" || { log_info "nothing was changed."; exit 0; }

pass=()
[ $DRY = 1 ] && pass+=(--dry-run)

# --yes: the question above was the one that mattered.
"$REPO_ROOT/scripts/uninstall.sh" --yes --no-summary "${pass[@]}" \
    || log_warn "the uninstall reported a problem; setting up again anyway"

if [ $FRESH = 1 ]; then
    # The profiles and the shell's state, not the restore points -- they are
    # in a directory of their own, and the reason to keep them is exactly a
    # reinstall that was not wanted after all.
    if [ $DRY = 1 ]; then
        printf '  would run: rm -rf %s %s\n' "$CONFIG_DIR" "$STATE_DIR" >&2
    else
        rm -rf "$CONFIG_DIR" "$STATE_DIR"
        log_step "settings removed"
    fi
fi

setup_args=("${pass[@]}")
[ $YES = 1 ] && setup_args+=(--unattended)

if ! "$REPO_ROOT/scripts/setup.sh" "${setup_args[@]}"; then
    log_warn "the setup did not finish; to set up again: $REPO_ROOT/scripts/setup.sh"
    exit 1
fi

# The setup says "nothing was changed" and exits 0 when its summary is
# declined; after an uninstall that is not nothing.
if [ $DRY = 0 ] && [ ! -e "$QS_CONFIG_DIR" ]; then
    log_warn "the setup was cancelled, so $DISPLAY_NAME is uninstalled."
    log_info "to set it up again: $REPO_ROOT/scripts/setup.sh"
    exit 1
fi

#!/usr/bin/env bash
# Chooses what draws the panel.
#
#   status              what is drawing the panel now, and what would change
#   list [--json]       every renderer here, other Quickshell shells included
#   set <renderer>      switch, with a restore point and a rollback
#   revert              put plasmashell's shell package back
#
# There is one `panel.renderer` key and one generator, so two panels at the
# same screen edge is not a state this can reach. That is the bug it exists to
# avoid: a shell package that ships a Plasma panel while a second shell also
# draws one leaves the user with both, stacked.
#
# Every mutating path is plan -> snapshot -> apply -> verify -> rollback. The
# generated applet layout is the riskiest write in the project, so the failure
# case is designed first: if the switch does not verify, the previous layout
# and every KDE key we touched go back before the command returns.
#
# The command is here, and the rest is in scripts/lib/renderer/: what is
# configured and what the Plasma renderer leaves out (plan.sh), plasmashell's
# side of a switch (plasma.sh), Plasma's tray-only services (services.sh),
# another Quickshell shell as the renderer (foreign.sh), and the commands
# themselves (status.sh, switch.sh).
set -uo pipefail

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
source "$REPO_ROOT/scripts/lib/log.sh"
source "$REPO_ROOT/scripts/lib/brand.sh"
source "$REPO_ROOT/scripts/lib/lockscreen.sh"
source "$REPO_ROOT/scripts/lib/render.sh"
source "$REPO_ROOT/scripts/lib/kconfig.sh"
source "$REPO_ROOT/scripts/lib/protected.sh"
source "$REPO_ROOT/scripts/lib/snapshot.sh"
source "$REPO_ROOT/scripts/lib/appletsrc.sh"
source "$REPO_ROOT/scripts/lib/renderers.sh"
source "$REPO_ROOT/scripts/lib/config.sh"

BACKUP_DIR="$STATE_DIR/renderer-backups"

source "$REPO_ROOT/scripts/lib/renderer/plan.sh"
source "$REPO_ROOT/scripts/lib/renderer/foreign.sh"
source "$REPO_ROOT/scripts/lib/renderer/plasma.sh"
source "$REPO_ROOT/scripts/lib/renderer/services.sh"
source "$REPO_ROOT/scripts/lib/renderer/status.sh"
source "$REPO_ROOT/scripts/lib/renderer/switch.sh"

cmd=${1:-status}
[ $# -gt 0 ] && shift

ASSUME_YES=0
DRY_RUN=0
FORCE=0
JSON=0
args=()
while [ $# -gt 0 ]; do
    case "$1" in
        -y|--yes)   ASSUME_YES=1 ;;
        --force)    FORCE=1 ;;
        --dry-run)  DRY_RUN=1 ;;
        --json)     JSON=1 ;;
        -*)         die "unknown option: $1" ;;
        *)          args+=("$1") ;;
    esac
    shift
done

case "$cmd" in
    list)   renderer_list ;;
    status) renderer_status ;;
    set)    renderer_set "${args[0]:-}" ;;
    revert) renderer_revert ;;
    *) die "unknown command: $cmd (expected status, list, set or revert)" ;;
esac

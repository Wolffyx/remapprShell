#!/usr/bin/env bash
# Screen edges and corners.
#
#   status [--json]        what every edge and corner does, and whether
#                          mouse triggers are on
#   actions                what an edge can be set to
#   set <edge> <action>    bind a corner or edge to one action
#   shell [<edge> <action|none>]
#                          this shell's own actions on an edge: KWin's edges
#                          run KWin's actions only, so ours needs a KWin
#                          script of its own. No arguments lists what is bound
#   effect <name> <edge|none>
#                          the same as `set <edge> <name>`; with `none`, take
#                          that effect off every edge
#   follow                 make KWin's edges agree with the sidebar's own
#                          settings: an edge on the side it opens from when
#                          sidebar.trigger is "hover", and no edge at all when
#                          it is anything else
#   snap on|off            Aero-Snap style edge tiling and maximise
#   disable-all            the master switch: every mouse trigger off
#   enable-all             ...and back on, exactly as they were
#   revert                 undo everything this project set
#
# KWin already implements all of this. Nothing here reimplements an edge
# trigger; it configures the ones KWin has and records the previous value so
# every change can be undone. That is the whole difference between a shell that
# co-operates with the desktop and one that fights it.
#
# The command is here. What it acts on is in scripts/lib/edges/: KWin's own
# edges and corners in borders.sh, and in script.sh the edges this shell
# registers for itself.
set -uo pipefail

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
source "$REPO_ROOT/scripts/lib/log.sh"
source "$REPO_ROOT/scripts/lib/brand.sh"
source "$REPO_ROOT/scripts/lib/kconfig.sh"
source "$REPO_ROOT/scripts/lib/accel.sh"
source "$REPO_ROOT/scripts/lib/kwin.sh"
source "$REPO_ROOT/scripts/lib/render.sh"
source "$REPO_ROOT/scripts/lib/config.sh"
source "$REPO_ROOT/scripts/lib/edges/borders.sh"
source "$REPO_ROOT/scripts/lib/edges/script.sh"

cmd=${1:-status}
[ $# -gt 0 ] && shift

case "$cmd" in
    status)      edges_status "$@" ;;
    actions)     edges_actions ;;
    set)         edges_set "$@" ;;
    effect)      edges_effect "$@" ;;
    snap)        edges_snap "$@" ;;
    disable-all) edges_disable_all ;;
    enable-all)  edges_enable_all ;;
    shell)       edges_shell "$@" ;;
    follow)      edges_follow ;;

    revert)
        # The switch first: its records hold what the corners were after our
        # own changes, and reverting ours afterwards is what gets back to the
        # user's.
        triggers_off && kconfig_revert edges-off
        shell_remove
        kconfig_revert edges
        kwin_reconfigure
        ;;

    *) die "unknown command: $cmd" ;;
esac

#!/usr/bin/env bash
# Fails when the shell starts an application anywhere but through Launch.
#
# An application the shell starts itself is the shell's child, in the shell's
# systemd service, and the service ends every process in it when the shell
# stops, crashes or restarts. On 2026-09-24 a restart of the shell took the
# user's game (running under Wine) and its store's client with it that way.
# shell/platform/system/Launch.qml starts every application in a scope of its
# own instead, and this keeps the known ways round it closed:
#
#   .execute()                  a DesktopEntry or DesktopAction run directly
#   Qt.openUrlExternally()      xdg-open, as the shell's child
#   ["xdg-open", ...]           and the other programs that open or host an
#   ["systemsettings", ...]     application, written as a command line for
#   ["plasmawindowed", ...]     execDetached or a Process -- unless the same
#                               line hands it to Launch
#
# A line that means it -- a service the shell hosts and owns, which should go
# when the shell does -- says so with `lint-launch: allow`, on the line or the
# one above, and why. The shapes are the ones this code has used; a command
# line built elsewhere and passed in cannot be seen from here.
set -euo pipefail

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
source "$REPO_ROOT/scripts/lib/log.sh"
cd "$REPO_ROOT"

LAUNCH=shell/platform/system/Launch.qml
[ -f "$LAUNCH" ] || die "no Launch at $LAUNCH"

programs='xdg-open|kde-open|kioclient|gtk-launch|systemsettings|plasmawindowed'

fail=0
checked=0
while IFS= read -r file; do
    [ "$file" = "$LAUNCH" ] && continue
    checked=$((checked + 1))
    while IFS= read -r hit; do
        log_error "$hit"
        fail=1
    done < <(awk -v file="$file" -v progs="$programs" '
        {
            allowed = (prev ~ /lint-launch: allow/) || ($0 ~ /lint-launch: allow/)
            prev = $0
        }
        /^[ \t]*\/\// || allowed { next }
        /\.execute\(/ {
            printf "%s:%d: execute() starts the application as the shell'\''s child -- use Launch.entry() or Launch.action()\n", file, NR
            next
        }
        /Qt\.openUrlExternally\(/ {
            printf "%s:%d: Qt.openUrlExternally() opens it as the shell'\''s child -- use Launch.open()\n", file, NR
            next
        }
        $0 ~ ("\\[[ \t]*[\"'\''](" progs ")[\"'\'']") && $0 !~ /Launch\./ {
            match($0, "(" progs ")")
            printf "%s:%d: runs %s as the shell'\''s child -- use Launch.command() or Launch.open()\n", file, NR, substr($0, RSTART, RLENGTH)
        }
    ' "$file")
done < <(find shell -name '*.qml' -type f | sort)

if [ "$fail" -ne 0 ]; then
    log_error "  an application started there dies with the shell; Launch gives it a scope of its own"
    exit 1
fi
log_step "launch lint clean ($checked file(s) checked)"

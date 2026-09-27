# shellcheck shell=bash
# Where diagnostic reports live, and the few things more than one command
# needs to know about them: which is newest, and which one is about a crash.
# Sourced, never executed. Requires brand.sh.
#
# report.sh writes them, ask.sh hands one to an assistant and doctor counts
# them. Each kept its own copy of the directory and of these questions, and
# the one line that ties a report to a crash dump was written in one file and
# grepped for, spelled out again, in two others.

REPORT_DIR="$STATE_DIR/diagnostics"

# The newest report's name, or nothing. Names begin with a sortable timestamp.
report_newest() { ls -1 "$REPORT_DIR" 2>/dev/null | sort | tail -1; }

# The line a report's error.txt carries when it is about a crash dump.
report_crash_line() { printf 'crash:  %s' "$1"; }   # <dump id>

# The newest report written about one crash dump, as its directory, or
# nothing. Asking about a crash twice reads the same bundle rather than writing
# a second one, and doctor says whether the newest crash has one at all.
report_for_crash() {   # <dump id>
    local line d
    line=$(report_crash_line "$1")
    while IFS= read -r d; do
        [ -f "$d/crash.txt" ] || continue
        grep -qxF -- "$line" "$d/error.txt" 2>/dev/null && printf '%s\n' "${d%/}"
    done < <(ls -1d "$REPORT_DIR"/*/ 2>/dev/null | sort) | tail -1
}

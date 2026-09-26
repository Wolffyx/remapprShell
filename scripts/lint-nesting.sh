#!/usr/bin/env bash
# Warns about a loop nested in a loop with a condition among them -- the
# `for > if > for > if` shape -- in the QML, JavaScript, C++, shell and Python.
#
# A nest like that reads as one block while doing two jobs, and the inner one
# is usually a function waiting to be named: splitting a line into fields,
# skipping a quoted string, measuring a run of numbers. Six were flattened on
# 2026-09-27 that way, each by giving its inner loop a name or an early
# `continue`.
#
# A warning, not a failure: some nests are the shape of the data -- each
# directory, then each file in it -- and say so with `lint-nesting: allow`
# and why, on the outer loop's line or the one above. The reading itself is
# scripts/lib/nesting.py, which says what counts as a loop.
set -euo pipefail

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
source "$REPO_ROOT/scripts/lib/log.sh"

command -v python3 >/dev/null || die "python3 is needed to read the tree"

found=$(python3 "$REPO_ROOT/scripts/lib/nesting.py" "$REPO_ROOT")
if [ -z "$found" ]; then
    log_step "nesting lint clean"
    exit 0
fi

while IFS=$'\t' read -r where func shape; do
    log_warn "$where ($func): $shape"
done <<< "$found"
log_warn "  give the inner loop a name, or skip early with continue;"
log_warn "  a nest that is the shape of its data says so with 'lint-nesting: allow -- why'"

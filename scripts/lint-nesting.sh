#!/usr/bin/env bash
# Warns about two shapes in the QML, JavaScript, C++, shell and Python:
#
#   three deep   three control statements, each inside the last -- `for > if >
#                for`, `if > if > if` -- counted from the function
#   a ladder     three or more tests of one thing in a row -- `if kind is a,
#                else if kind is b, else if ...`, or `?:` after `?:`
#
# A nest three deep reads as one block while doing two jobs, and the inner one
# is usually a function waiting to be named: splitting a line into fields,
# skipping a quoted string, measuring a run of numbers. Six loops in loops were
# flattened on 2026-09-27 that way, and then some thirty nests of every kind,
# each by giving the inner block a name or leaving early. A ladder is a table
# written out as code: a map from each value to what it does says it once, and
# the next value is a line in it rather than another branch.
#
# A warning, not a failure: some nests are the shape of the data -- each
# directory, then each file in it -- and say so with `lint-nesting: allow`
# and why, on the line of a statement in the nest or the one above. The
# reading itself is scripts/lib/nesting.py, which says what counts.
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
log_warn "  a nest: leave early (return, continue), or give the inner block a name;"
log_warn "  a ladder: a map from each value to what it does;"
log_warn "  a nest that is the shape of its data says so with 'lint-nesting: allow -- why'"

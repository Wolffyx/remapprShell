#!/usr/bin/env bash
# Fails if docs/config.md is not what the schema would generate.
#
# The document is committed because it is prose people read on the forge, where
# nothing runs. That makes it possible for it to go stale -- a key added to the
# schema, the reference not regenerated -- and a configuration reference that is
# quietly wrong is worse than none: it is trusted.
#
# So staleness fails the build rather than waiting to be noticed.
set -euo pipefail

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
source "$REPO_ROOT/scripts/lib/log.sh"

DOC="$REPO_ROOT/docs/config.md"
[ -f "$DOC" ] || die "docs/config.md is missing (run: make docs)"

tmp=$(mktemp)
trap 'rm -f "$tmp"' EXIT

"$REPO_ROOT/scripts/gen-docs.sh" "$tmp" >/dev/null

if ! diff -q "$DOC" "$tmp" >/dev/null; then
    log_error "docs/config.md is out of date:"
    diff "$DOC" "$tmp" | head -40 >&2
    die "regenerate it: make docs"
fi

log_step "docs lint clean"

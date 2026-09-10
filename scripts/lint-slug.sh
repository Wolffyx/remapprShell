#!/usr/bin/env bash
# Fails if the project slug is hardcoded anywhere it should not be.
#
# This lint is what makes `rmpr rename` a supported operation rather than a
# scavenger hunt. Without it, hardcoded names creep back in within a week.
set -euo pipefail

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
source "$REPO_ROOT/scripts/lib/log.sh"
source "$REPO_ROOT/scripts/lib/brand.sh"

cd "$REPO_ROOT"

# Allowed to contain the slug:
#   branding.json          the single source of truth
#   shell/core/Branding.qml generated from it
#   docs/, README.md       prose for humans
#   LICENSE                upstream text
#   .git/                  not ours
allow_re='^(branding\.json|shell/core/Branding\.qml|README\.md|docs/|LICENSE|\.git/|theme/colors/[^/]*\.colors)'

# git grep is faster and honours .gitignore, but it fails outside a work tree
# (a release tarball, a CI checkout without .git). Falling back matters: with
# `|| true` swallowing the error, an unavailable git would make this lint
# silently pass, which is worse than not having it.
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    _grep_all() { git grep -n --no-color -F -- "$1" -- "${@:2}"; }
else
    log_debug "not a git work tree; falling back to grep -r"
    _grep_all() {
        local pat=$1; shift
        grep -rn --binary-files=without-match -F -- "$pat" "${@:-.}" \
            --exclude-dir=.git --exclude-dir=build
    }
fi

hits=$(_grep_all "$SLUG" . 2>/dev/null | sed 's|^\./||' | grep -vE "$allow_re" || true)

# The alias is a shorter string and appears in prose far more often, so it is
# only checked in code, not in comments. Keeping this narrow avoids false
# positives that would train people to ignore the lint.
alias_hits=$(_grep_all "\"$ALIAS\"" shell bin 2>/dev/null | sed 's|^\./||' | grep -vE "$allow_re" || true)

if [ -n "$hits" ] || [ -n "$alias_hits" ]; then
    log_error "hardcoded project name found -- use Branding.qml (QML) or \$SLUG (shell):"
    [ -n "$hits" ]       && printf '%s\n' "$hits" >&2
    [ -n "$alias_hits" ] && printf '%s\n' "$alias_hits" >&2
    exit 1
fi

log_step "slug lint clean"

#!/usr/bin/env bash
# Enforces the dependency ladder:
#
#   0 core/       -> nothing
#   1 platform/   -> core
#   2 domain/     -> core, platform
#   3 ui/         -> core, platform, domain
#   4 features/   -> core, platform, domain, ui
#
# A layer may import from layers strictly below it, never sideways and never up.
# Sideways imports are what turn a codebase into a ball of mud, so they fail here
# rather than in review.
set -euo pipefail

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
source "$REPO_ROOT/scripts/lib/log.sh"
cd "$REPO_ROOT/shell"

declare -A rank=( [core]=0 [platform]=1 [domain]=2 [ui]=3 [features]=4 [widgets]=4 )
fail=0

while IFS= read -r file; do
    layer=${file%%/*}
    [ -n "${rank[$layer]:-}" ] || continue

    # Matches both `import qs.domain.config` and `import "../domain/config"`.
    while IFS= read -r dep; do
        [ -n "${rank[$dep]:-}" ] || continue
        if [ "${rank[$dep]}" -gt "${rank[$layer]}" ]; then
            log_error "$file: '$layer' (rank ${rank[$layer]}) imports '$dep' (rank ${rank[$dep]})"
            fail=1
        elif [ "${rank[$dep]}" -eq "${rank[$layer]}" ] && [ "$dep" != "$layer" ]; then
            log_error "$file: sideways import '$layer' -> '$dep'"
            fail=1
        fi
    done < <(grep -oE '^\s*import\s+(qs\.[a-z]+|"[./]*[a-z]+)' "$file" 2>/dev/null \
             | sed -E 's/.*(qs\.|")([.\/]*)//' | tr -d '"')
done < <(find . -name '*.qml' -type f | sed 's|^\./||')

[ "$fail" -eq 0 ] || exit 1
log_step "layer lint clean"

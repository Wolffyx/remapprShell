#!/usr/bin/env bash
# Generates a qmldir for every directory under shell/ that contains QML.
#
# Quickshell synthesises these at runtime, but qmllint cannot: it needs a real
# qmldir to resolve `import qs.<dir>` and to know which types are singletons.
# Generating them (rather than hand-writing one per directory) keeps the lint
# and the runtime seeing the same module structure, and means adding a file
# never requires remembering to edit a qmldir.
#
# Generated files are gitignored.
set -euo pipefail

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
source "$REPO_ROOT/scripts/lib/log.sh"
cd "$REPO_ROOT"

count=0
while IFS= read -r dir; do
    # Skip directories whose only QML lives deeper down.
    ls "$dir"/*.qml >/dev/null 2>&1 || continue

    # shell/domain/config -> qs.domain.config
    rel=${dir#shell}
    rel=${rel#/}
    if [ -z "$rel" ]; then
        module="qs"
    else
        module="qs.${rel//\//.}"
    fi

    {
        printf '# GENERATED FILE -- DO NOT EDIT. Regenerate: scripts/gen-qmldir.sh\n'
        printf 'module %s\n\n' "$module"
        for f in "$dir"/*.qml; do
            base=$(basename "$f" .qml)
            # A type name must start with an uppercase letter; anything else is
            # a plain script file, not a component.
            case "$base" in [A-Z]*) ;; *) continue ;; esac
            if head -5 "$f" | grep -q '^pragma Singleton'; then
                printf 'singleton %s 1.0 %s.qml\n' "$base" "$base"
            else
                printf '%s 1.0 %s.qml\n' "$base" "$base"
            fi
        done
    } > "$dir/.qmldir.new"
    # Replaced whole, and only when it changed. The running shell reads these
    # the moment one changes: a qmldir truncated and written line by line was
    # read half-written, and a type still in it was "not a type" for one
    # reload (2026-09-24). A rename is atomic, and one left alone is not
    # a reason to reload at all.
    if cmp -s "$dir/.qmldir.new" "$dir/qmldir"; then
        rm -f "$dir/.qmldir.new"
    else
        mv -f "$dir/.qmldir.new" "$dir/qmldir"
    fi
    count=$((count + 1))
done < <(find shell -type d | sort)

log_step "generated $count qmldir file(s)"

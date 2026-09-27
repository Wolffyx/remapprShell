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

shopt -s nullglob

# The singletons: a file is one when `pragma Singleton` is among its first five
# lines. Found by one grep over every file -- the first such line in each, and
# its number -- rather than by a head and a grep a file. A grep, not an awk:
# awk stops at a file it cannot open, and every singleton after that one would
# be written down as a plain type.
declare -A singleton=()
while IFS=: read -r file line _; do
    [ "$line" -le 5 ] || continue
    singleton[$file]=1
done < <(find shell -name '*.qml' ! -type d -exec grep -Hnm1 '^pragma Singleton' {} +)

# qmldir_body <module> <file>...: the qmldir for a directory of those files, in
# $body.
qmldir_body() {
    local module=$1 f base
    shift
    printf -v body '# GENERATED FILE -- DO NOT EDIT. Regenerate: scripts/gen-qmldir.sh\nmodule %s\n\n' "$module"
    for f in "$@"; do
        base=${f##*/}
        base=${base%.qml}
        # A type name must start with an uppercase letter; anything else is
        # a plain script file, not a component.
        case "$base" in [A-Z]*) ;; *) continue ;; esac
        if [ -n "${singleton[$f]:-}" ]; then
            body+="singleton $base 1.0 $base.qml"$'\n'
        else
            body+="$base 1.0 $base.qml"$'\n'
        fi
    done
}

count=0
while IFS= read -r dir; do
    # Skip directories whose only QML lives deeper down.
    qml=("$dir"/*.qml)
    [ "${#qml[@]}" -gt 0 ] || continue

    # shell/domain/config -> qs.domain.config
    rel=${dir#shell}
    rel=${rel#/}
    if [ -z "$rel" ]; then
        module="qs"
    else
        module="qs.${rel//\//.}"
    fi
    qmldir_body "$module" "${qml[@]}"

    # Replaced whole, and only when it changed. The running shell reads these
    # the moment one changes: a qmldir truncated and written line by line was
    # read half-written, and a type still in it was "not a type" for one
    # reload (2026-09-24). A rename is atomic, and one left alone is not
    # a reason to reload at all. Compared in the shell rather than by cmp:
    # read up to a NUL, which a qmldir never holds, the file comes back whole,
    # trailing newlines and all, which $(<file) would drop.
    old=""
    if [ -f "$dir/qmldir" ]; then
        IFS= read -rd '' old < "$dir/qmldir" || true
    fi
    if [ "$body" != "$old" ]; then
        printf '%s' "$body" > "$dir/.qmldir.new"
        mv -f "$dir/.qmldir.new" "$dir/qmldir"
    fi
    count=$((count + 1))
done < <(find shell -type d | sort)

log_step "generated $count qmldir file(s)"

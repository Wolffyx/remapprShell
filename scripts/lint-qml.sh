#!/usr/bin/env bash
# Runs qmllint over the project's QML.
#
# With no arguments it covers shell/ and theme/. The theme QML is drawn by
# Plasma rather than by us -- the OSD, the window switcher -- which makes it
# more important to lint, not less: a syntax error there means Alt+Tab silently
# does nothing, with nothing in our own journal to say why.
#
# Given file arguments it lints exactly those, which is what the crash reporter
# uses to say something useful about the file a failure came from.
#
# Two things this gets right that a naive `find | xargs qmllint` does not:
#
#   1. It uses the Qt6 qmllint. On Arch, /usr/bin/qmllint belongs to
#      qt5-declarative and reports version "1.0"; handed a Qt6/Quickshell file
#      it exits 255 with no output at all. Linting against the wrong Qt major
#      is worse than not linting.
#   2. Every bad file is reported, by name, rather than aborting at the first.
#      One qmllint reads them all and says, as JSON, which it had anything to
#      say about; only those are linted again, alone, for the words and the
#      verdict that are that file's. It was one qmllint a file, the same Qt
#      modules loaded some 370 times over: 49 s for the tree, now about 15.
set -uo pipefail

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
source "$REPO_ROOT/scripts/lib/log.sh"
source "$REPO_ROOT/scripts/lib/brand.sh"
source "$REPO_ROOT/scripts/lib/render.sh"
cd "$REPO_ROOT"

# Resolve the Qt6 qmllint explicitly; $PATH usually finds the Qt5 one first.
QMLLINT=""
for candidate in "${QMLLINT_BIN:-}" /usr/lib/qt6/bin/qmllint "$(command -v qmllint6 2>/dev/null || true)"; do
    [ -n "$candidate" ] && [ -x "$candidate" ] || continue
    if "$candidate" --version 2>&1 | grep -qE 'qmllint 6\.'; then
        QMLLINT=$candidate
        break
    fi
done
# Last resort: a $PATH qmllint, but only if it really is Qt6.
if [ -z "$QMLLINT" ] && command -v qmllint >/dev/null 2>&1; then
    if qmllint --version 2>&1 | grep -qE 'qmllint 6\.'; then
        QMLLINT=$(command -v qmllint)
    fi
fi
# An update verifying itself on a user's machine sets LINT_QML_OPTIONAL: qmllint
# is a development tool there, in a -devel or -dev-tools package outside Arch,
# and a machine without it is no reason to roll an update back.
if [ -z "$QMLLINT" ]; then
    if [ -n "${LINT_QML_OPTIONAL:-}" ]; then
        log_warn "Qt6 qmllint not found; the QML lint is skipped"
        exit 0
    fi
    die "Qt6 qmllint not found (install qt6-declarative, or set QMLLINT_BIN)"
fi
log_debug "using $QMLLINT ($("$QMLLINT" --version 2>&1))"

# The generated singleton must exist or every import of it is a false positive.
[ -f shell/core/Branding.qml ] || scripts/gen-branding.sh >/dev/null

# Quickshell special-cases the `qs.` import prefix, mapping it to the config
# root. qmllint does not: it resolves the module URI `qs.core` to the directory
# `<importpath>/qs/core`. So build a throwaway import root containing a single
# `qs` symlink to shell/, and point qmllint at that.
IMPORT_ROOT=$(mktemp -d)
trap 'rm -rf "$IMPORT_ROOT"' EXIT
ln -s "$REPO_ROOT/shell" "$IMPORT_ROOT/qs"

# QML that ships as a template is rendered and linted too. It is installed as
# real QML, so an error in one is an error that reaches the user -- and the
# splash screen, being a template, would otherwise be the one file nothing ever
# checks.
render_templates() {
    local src rendered
    while IFS= read -r src; do
        rendered="$IMPORT_ROOT/rendered/${src%.in}"
        mkdir -p "$(dirname "$rendered")"
        if render_template "$src" "$rendered" >/dev/null 2>&1; then
            printf '%s\n' "$rendered"
        else
            log_error "$src: unresolved placeholders"
            failed=$((failed + 1))
        fi
    done < <(find shell theme -name '*.qml.in' -type f | sort)
}

failed=0
checked=0

# A property named `on` and a capital letter is read as a signal handler.
# Beside a property named for the rest (`primary` and `onPrimary`) it fails to
# compile -- "Cannot assign a value to a signal" -- and in a singleton it was
# instead left silently unset: every colour of the theme named that way drew
# black, and qmllint said nothing about either.
if [ $# -eq 0 ]; then
    while IFS= read -r hit; do
        log_error "${hit%%:*}: a property named on<Capital> is read as a signal handler (line ${hit#*:}); name it differently, e.g. primaryFg"
        failed=$((failed + 1))
    done < <(grep -rnoE '^\s*((readonly|required|default)\s+)*property\s+\S+\s+on[A-Z][A-Za-z0-9_]*' shell theme share --include='*.qml' \
             | sed -E 's/^([^:]+):([0-9]+):.*property\s+\S+\s+(\S+)$/\1:\2 \3/' || true)
fi

# lint_one <file>: qmllint over the one file, its output as qmllint gave it --
# an error with the file named, warnings passed on without failing.
lint_one() {
    local file=$1 out
    if ! out=$("$QMLLINT" -I "$IMPORT_ROOT" -I shell "$file" 2>&1); then
        log_error "$file"
        [ -n "$out" ] && printf '%s\n' "$out" >&2
        failed=$((failed + 1))
    elif [ -n "$out" ]; then
        # qmllint reports warnings on a zero exit; surface them without failing.
        printf '%s\n' "$out" >&2
    fi
}

# lint_batch: one qmllint over every file, marking in `quiet` each it had
# nothing at all to say about; every other file is linted again on its own.
#
# A module whose import warned is warned about for the first file that
# imports it only -- qmllint imports a module once a run -- so every file that
# imports one is linted alone as well, to say it again for each. And one file
# that crashes qmllint takes the whole run with it: a run that did not finish
# with every file in it marks nothing, and each file is linted alone, as
# before. So does a machine without jq.
declare -A quiet=()
lint_batch() {
    local warned file
    local -a listed
    [ "${#files[@]}" -gt 1 ] || return 0
    { IFS= read -r warned; mapfile -t listed; } < <(
        "$QMLLINT" -I "$IMPORT_ROOT" -I shell --json - "${files[@]}" 2>/dev/null \
            | jq -r --argjson n "${#files[@]}" '
                if (.files | length) != $n then error("the run did not finish") else . end
                | ([.files[].warnings[] | select(.id == "import") | .message
                    | capture("importing module \"(?<m>[^\"]+)\"").m | gsub("\\."; "\\.")]
                   | unique | join("|")),
                  (.files[] | select(.success and (.warnings | length) == 0) | .filename)' 2>/dev/null)
    for file in "${listed[@]}"; do
        quiet[$file]=1
    done
    [ -n "$warned" ] || return 0
    while IFS= read -r file; do
        unset 'quiet[$file]'
    done < <(grep -lE "^\s*import\s+($warned)([[:space:];]|\$)" "${listed[@]}" < /dev/null)
}

mapfile -t files < <(if [ $# -gt 0 ]; then
                         printf '%s\n' "$@"
                     else
                         find shell theme share -name '*.qml' -type f | sort
                         render_templates
                     fi)
lint_batch
for file in "${files[@]}"; do
    checked=$((checked + 1))
    [ -z "${quiet[$file]:-}" ] || continue
    lint_one "$file"
done

if [ "$failed" -gt 0 ]; then
    die "qmllint: $failed of $checked file(s) failed"
fi
log_step "qml lint clean ($checked files, $("$QMLLINT" --version 2>&1))"

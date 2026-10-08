# shellcheck shell=bash
# Writing a generated file that is committed, into a tree a shell may be
# running from. Sourced, never executed; requires log.sh.
#
# Two of them are read by the shell as it starts -- core/Branding.qml and the
# widget index -- and are committed for that reason: a gitignored file in the
# live checkout is one `make clean` away from a login with no shell, which is
# what 2026-10-08 was. Committed, they need two things this gives them:
#
#   - a write that the running shell never sees half done, and none at all
#     when nothing changed. Quickshell reloads the moment a file it imported
#     changes; a file truncated and written line by line was read half-written
#     once already (the qmldirs, 2026-09-24), and an unchanged one rewritten is
#     a reload for nothing.
#   - a check that the committed copy is what its sources make, for the lint.
#     GEN_CHECK=1 writes nothing and fails on a difference.

# write_generated <dest>: stdin, as <dest>, replaced whole and only when it
# changed. Read up to a NUL, which neither file holds, so trailing newlines
# survive the comparison as they would not through $(...).
write_generated() {
    local dest=$1 body="" old=""
    IFS= read -rd '' body || true
    [ -f "$dest" ] && { IFS= read -rd '' old < "$dest" || true; }
    [ "$body" != "$old" ] || return 0

    if [ "${GEN_CHECK:-0}" = 1 ]; then
        log_error "${dest#"$REPO_ROOT"/} is not what its sources make -- run \`make brand\` and commit it"
        return 1
    fi
    local tmp
    tmp="$(dirname "$dest")/.$(basename "$dest").new"
    printf '%s' "$body" > "$tmp" && mv -f "$tmp" "$dest"
}

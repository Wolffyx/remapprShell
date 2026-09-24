# shellcheck shell=bash
# The session daemon, for the suites that test it: tests/test-windowsd*.sh.
#
# Sourced after harness.sh, never executed:
#
#   windowsd_require     ends the suite with a SKIP where python-gobject is missing
#   windowsd_install     the daemon rendered as an install renders it, to where an
#                        install puts it in this sandbox's HOME: WINDOWSD_DAEMON is
#                        the script, WINDOWSD_PACKAGE the package beside it
#   windowsd_example     the package alone, under example names, for the blocks
#   windowsd_python [arg]... <<'PY'
#                        a Python block that imports the example package as
#                        `windowsd`, with check() as the harness has it
#
# The daemon is a package, bin/windowsd/, and one module of it is a template,
# so a suite imports a rendered copy and never the source.

source "$HARNESS_ROOT/scripts/lib/render.sh"
source "$HARNESS_ROOT/scripts/lib/manifest.sh"

windowsd_require() {
    python3 -c "import gi; gi.require_version('Gio','2.0')" 2>/dev/null \
        || { echo "  SKIP  python-gobject not installed"; exit 0; }
}

# By the manifest's own entries, so a daemon that starts here is one whose
# script finds its package where an install leaves it.
windowsd_install() {
    local kind src dest
    WINDOWSD_DAEMON="" WINDOWSD_PACKAGE=""
    while IFS='|' read -r kind src dest; do
        case "$kind|$src" in
            "package|bin/windowsd")
                render_package "$HARNESS_ROOT/$src" "$dest" || return 1
                WINDOWSD_PACKAGE=$dest ;;
            "template|bin/windowsd.py.in")
                render_template "$HARNESS_ROOT/$src" "$dest" || return 1
                WINDOWSD_DAEMON=$dest ;;
        esac
    done < <(manifest_entries)
    [ -n "$WINDOWSD_DAEMON" ] && [ -n "$WINDOWSD_PACKAGE" ]
}

# The names the blocks were written against -- slug t, bus name
# com.example.T -- rather than this install's, so that what they check is the
# code and not the branding. Rendered in a subshell: the names are changed for
# the render alone.
windowsd_example() {
    WINDOWSD_EXAMPLE_LIB="$SANDBOX/example-lib"
    (
        # shellcheck disable=SC2034  # read by render_template, by name
        SLUG=t DISPLAY_NAME=T DBUS_NAME=com.example.T ALIAS=t BIN_DIR=/nowhere CTL_BIN=t-ctl
        render_package "$HARNESS_ROOT/bin/windowsd" "$WINDOWSD_EXAMPLE_LIB/windowsd"
    )
}

_windowsd_prelude() {
    cat <<'PY'
def check(name, got, want):
    ok = got == want
    print(f"  {'PASS' if ok else 'FAIL'}  {name}" + ("" if ok else f" (expected {want!r}, got {got!r})"))
PY
}

# Its checks are counted from what it prints rather than written down beside
# it: two of the counts written down had fallen behind their blocks, by five
# checks and by three, and a check nobody counts is one a failure can hide in.
# A block that stops before its end -- an exception -- is one failure more.
windowsd_python() {
    local out rc
    out=$({ _windowsd_prelude; cat; } | PYTHONPATH="$WINDOWSD_EXAMPLE_LIB" python3 - "$@" 2>&1); rc=$?
    printf '%s\n' "$out"
    pass=$((pass + $(grep -c '^  PASS  ' <<< "$out")))
    fail=$((fail + $(grep -c '^  FAIL  ' <<< "$out")))
    if [ "$rc" -ne 0 ]; then
        printf '  FAIL  the block above stopped with status %s\n' "$rc" >&2
        fail=$((fail + 1))
    fi
}

# shellcheck shell=bash
# What every shell suite sets up before its first check, and the checks.
#
# Sourced by tests/test-*.sh, never executed:
#
#   REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
#   source "$REPO_ROOT/tests/lib/harness.sh"
#   harness_init                # a throwaway HOME, the names, the switches
#   check "a name" "$(...)" "what it should be"
#   harness_done                # the summary, and the exit status
#
# harness_init leaves behind SANDBOX (removed on exit), FAKEBIN (first on
# PATH, for stand-ins), `profile` (the default profile's shell.json, inside
# the sandbox) and the pass/fail counters, and has sourced log.sh and
# brand.sh -- after HOME moved, so every derived path is a sandbox path.
#
# The same fifteen lines were copied into seventeen suites before this, and
# the copies had begun to differ in what they were careful about: six of
# them left the no-session switch to whoever ran them.

HARNESS_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)

# harness_init [--cache] [--no-home]
#
#   --cache     XDG_CACHE_HOME inside the sandbox too, for a suite reading a
#               cache (crash dumps live in one)
#   --no-home   a sandbox but the caller's own HOME, for a suite that only
#               renders a file and names real paths without touching them
harness_init() {
    local home=1 cache=0
    while [ $# -gt 0 ]; do
        case "$1" in
            --cache)   cache=1 ;;
            --no-home) home=0 ;;
            *) echo "harness_init: unknown option: $1" >&2; exit 2 ;;
        esac
        shift
    done

    # The PATH as it was, for path_only -- which must not find a stand-in when
    # it asks where the real tool is -- and for the clean-up, which must still
    # find rm after path_only has taken it away.
    HARNESS_PATH=$PATH
    SANDBOX=$(mktemp -d)
    _harness_on_exit=()
    trap _harness_exit EXIT

    if [ "$home" = 1 ]; then
        export HOME="$SANDBOX/home"
        export XDG_CONFIG_HOME="$HOME/.config"
        export XDG_DATA_HOME="$HOME/.local/share"
        export XDG_STATE_HOME="$HOME/.local/state"
        mkdir -p "$XDG_CONFIG_HOME" "$XDG_DATA_HOME" "$XDG_STATE_HOME"
        if [ "$cache" = 1 ]; then
            export XDG_CACHE_HOME="$HOME/.cache"
            mkdir -p "$XDG_CACHE_HOME"
        fi
    fi

    source "$HARNESS_ROOT/scripts/lib/log.sh"
    source "$HARNESS_ROOT/scripts/lib/brand.sh"

    # A HOME is not a session: systemd and the session bus are the user's
    # real ones whatever $HOME says. scripts/test.sh sets this for every
    # suite, and it is set again here so a suite run by hand is as safe as
    # one run by `make test` -- test-update, run without it, restarted the
    # user's running shell on every run until 2026-09-11.
    export "$NO_SESSION_VAR=1"

    # Stand-ins go here, and are found before anything real.
    FAKEBIN="$SANDBOX/bin"
    mkdir -p "$FAKEBIN"
    export PATH="$FAKEBIN:$PATH"

    # Only with a HOME of its own: under --no-home this would be the caller's
    # real profile, and nothing here may write that.
    if [ "$home" = 1 ]; then profile="$CONFIG_DIR/profiles/default/shell.json"; fi

    pass=0; fail=0
}

# harness_on_exit <command>: run on exit, before the sandbox is removed --
# for what outlives the suite otherwise, like a daemon it started.
harness_on_exit() { _harness_on_exit+=("$1"); }

_harness_exit() {
    local hook
    for hook in "${_harness_on_exit[@]}"; do eval "$hook"; done
    PATH=$HARNESS_PATH rm -rf "$SANDBOX"
}

# harness_done: the summary line and the exit status, as the last line of a
# suite. Non-zero when anything failed, which is all scripts/test.sh reads.
harness_done() {
    echo
    if [ "$fail" -gt 0 ]; then printf 'FAILED: %d passed, %d failed\n' "$pass" "$fail" >&2; exit 1; fi
    printf 'OK: %d passed\n' "$pass"
}

# --- checks -----------------------------------------------------------------

# check <name> <got> <want>
check() { if [ "$2" = "$3" ]; then printf '  PASS  %s\n' "$1"; pass=$((pass+1));
          else printf '  FAIL  %s (expected %q, got %q)\n' "$1" "$3" "$2" >&2; fail=$((fail+1)); fi; }

# contains <name> <text> <part>
contains() { case "$2" in *"$3"*) check "$1" yes yes ;; *) check "$1" "$2" "(containing) $3" ;; esac; }

# absent <name> <file> <text>, present <name> <file> <text>
absent() { if grep -qF -- "$3" "$2" 2>/dev/null; then
               printf '  FAIL  %s (found %q in %s)\n' "$1" "$3" "$2" >&2; fail=$((fail+1));
           else printf '  PASS  %s\n' "$1"; pass=$((pass+1)); fi; }
present() { if grep -qF -- "$3" "$2" 2>/dev/null; then printf '  PASS  %s\n' "$1"; pass=$((pass+1));
            else printf '  FAIL  %s (%q not in %s)\n' "$1" "$3" "$2" >&2; fail=$((fail+1)); fi; }

# check_unchanged <name> <before> <after>: two lists of checksums, the same.
# On a difference it prints which lines moved: a byte-identical gate that
# says only "no" leaves the file that changed to be found by hand.
check_unchanged() {
    if [ "$2" = "$3" ]; then printf '  PASS  %s\n' "$1"; pass=$((pass+1))
    else
        printf '  FAIL  %s:\n' "$1" >&2
        diff <(printf '%s\n' "$2") <(printf '%s\n' "$3") | sed 's/^/        /' >&2
        fail=$((fail+1))
    fi
}

# wait_for <file>: up to two seconds for it to appear. A detached terminal
# finishes after the command that opened it returns.
wait_for() { local i; for i in $(seq 1 40); do [ -f "$1" ] && return 0; sleep 0.05; done; return 1; }

# --- reading what was written -----------------------------------------------

# kread <file> <group>... <key>: one key as KDE reads it, '<unset>' when the
# file does not set it. More than one group is a nested group.
kread() {
    local file=$1 groups=(); shift
    while [ $# -gt 1 ]; do groups+=(--group "$1"); shift; done
    kreadconfig6 --file "$file" "${groups[@]}" --key "$1" --default '<unset>'
}

# ledger_count <scope>: how many KDE keys the ledger holds for one scope.
ledger_count() { jq --arg s "$1" '[.entries[] | select(.scope == $s)] | length' "$STATE_DIR/kconfig-ledger.json"; }

# kde_sums [file...]: checksums of KDE's configuration files, for a gate that
# they are byte-identical after a revert. With no files, every one in the
# sandbox's config directory but this project's own: that directory is ours
# to write, and is removed by an uninstall rather than by a revert.
kde_sums() {
    if [ $# -gt 0 ]; then (cd "$XDG_CONFIG_HOME" && sha256sum "$@" 2>/dev/null)
    else (cd "$XDG_CONFIG_HOME" && find . -type f -not -path "./$SLUG/*" | sort | xargs sha256sum); fi
}

# --- stand-ins ----------------------------------------------------------------

# fake_recorders <calls file> <command>...: stand-ins that do nothing but
# append the line they were called with. For whatever reaches the running
# desktop -- a throwaway HOME does not make a throwaway KWin -- so a call that
# gets through is written down rather than made.
fake_recorders() {
    local calls=$1 t; shift
    : > "$calls"
    for t in "$@"; do
        printf '#!/bin/sh\nprintf "%%s\\n" "%s $*" >> "%s"\n' "$t" "$calls" > "$FAKEBIN/$t"
        chmod +x "$FAKEBIN/$t"
    done
}

# fake_pgrep: a `pgrep` that answers from FAKE_PROC and nothing else.
#
# The process list is a piece of the live session a sandbox HOME does not
# reach: "is the shell running?" depended on whether whoever ran the suite had
# `make run` going -- which is precisely when these tests are run. The suite
# says what is running, in this process and in the scripts it calls, and
# FAKE_PROC is the one place it says it.
fake_pgrep() {
    cat > "$FAKEBIN/pgrep" <<'STUB'
#!/usr/bin/env bash
[ -n "${FAKE_PROC:-}" ] && printf '%s\n' "$FAKE_PROC"
exit 0
STUB
    chmod +x "$FAKEBIN/pgrep"
}

# path_only <tool>...: PATH becomes the stand-ins and these tools, and
# nothing else. A real program anywhere on this machine's PATH must not stand
# in for one a test took away: a check that a missing program is refused is
# only a check if the program can be missing.
path_only() {
    local sys="$SANDBOX/sys" t path
    mkdir -p "$sys"
    for t in "$@"; do
        path=$(PATH=$HARNESS_PATH; command -v "$t" 2>/dev/null) && ln -sf "$path" "$sys/$t"
    done
    export PATH="$FAKEBIN:$sys"
}

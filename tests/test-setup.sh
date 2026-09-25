#!/usr/bin/env bash
# Tests the dialog front ends and the guided install's plan, inside a
# throwaway HOME. Every setup run here is a dry run: the thing under test is
# which commands would run, not what they do -- each of those has a suite of
# its own.
set -uo pipefail

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
source "$REPO_ROOT/tests/lib/harness.sh"
harness_init
source "$REPO_ROOT/scripts/lib/dialog.sh"

UI_VAR="${ENV_PREFIX}_UI"
setup() { "$REPO_ROOT/scripts/setup.sh" "$@" 2>&1; }

# Stand-ins for the graphical front end, so detection can be tested on a
# machine that has no kdialog -- and so a case that reaches one by mistake
# cannot put a dialog on the screen of whoever is running the suite.
printf '#!/bin/sh\nexit 0\n' > "$FAKEBIN/kdialog"; chmod +x "$FAKEBIN/kdialog"

# The library under test, in a subshell per case with its answer forgotten:
# ui_backend remembers what it decided, which is the point of it and would
# make the cases depend on order. Sourced once, above: sourcing it per case
# read branding.json again every time, nine jq runs for each of twenty.
#
# The session this suite is run from is not the session under test: a real
# WAYLAND_DISPLAY would make every detection case answer kdialog.
ui() {
    local backend=$1; shift
    ( DIALOG_UI=
      export "$UI_VAR=$backend"
      unset WAYLAND_DISPLAY DISPLAY
      [ -n "${TEST_WAYLAND:-}" ] && export WAYLAND_DISPLAY="$TEST_WAYLAND"
      "$@" )
}

echo "== the front end =="
check "forced backend is used"          "$(ui plain ui_backend)" "plain"
check "nothing attached is 'none'"      "$(ui none ui_backend)" "none"
check "'none' is not interactive"       "$(ui none ui_interactive && echo yes || echo no)" "no"
check "a terminal is interactive"       "$(ui plain ui_interactive && echo yes || echo no)" "yes"
# An unreadable setting must not be obeyed silently: it falls back to
# detection, which in a test has no terminal and so answers 'none'.
check "unknown backend falls back"      "$(ui banana ui_backend 2>/dev/null)" "none"
# A graphical session with kdialog installed is the one case that is chosen
# over a terminal: it is the front end the person asking for it can see.
check "a graphical session is kdialog"  "$(TEST_WAYLAND=wayland-0 ui "" ui_backend)" "kdialog"

echo "== nobody there: every question takes its default =="
check "menu"      "$(ui none ui_menu T text second first One second Two)" "second"
check "checklist" "$(ui none ui_checklist T text 'a c' a A b B c C | tr '\n' ' ')" "a c "
check "input"     "$(ui none ui_input T text hello)" "hello"
check "yes"       "$(ui none ui_yesno 'q?' yes && echo yes || echo no)" "yes"
check "no"        "$(ui none ui_yesno 'q?' no && echo yes || echo no)" "no"

echo "== a terminal, answered =="
check "menu takes a number"      "$(printf '2\n' | ui plain ui_menu T text one one One two Two)" "two"
check "menu takes the tag"       "$(printf 'two\n' | ui plain ui_menu T text one one One two Two)" "two"
check "menu takes the default"   "$(printf '\n' | ui plain ui_menu T text one one One two Two)" "one"
# A typed answer that is not on offer is refused rather than passed on: a
# caller doing `renderer set "$(ui_menu ...)"` would otherwise be handed it.
check "menu refuses an unknown"  "$(printf 'banana\n' | ui plain ui_menu T text one one One two Two 2>/dev/null; echo "rc=$?")" "rc=2"
check "checklist takes tags"     "$(printf 'b c\n' | ui plain ui_checklist T text a a A b B c C | tr '\n' ' ')" "b c "
check "checklist keeps defaults" "$(printf '\n' | ui plain ui_checklist T text 'a b' a A b B c C | tr '\n' ' ')" "a b "
check "yes/no reads y"           "$(printf 'y\n' | ui plain ui_yesno 'q?' no && echo yes || echo no)" "yes"
check "yes/no reads n"           "$(printf 'n\n' | ui plain ui_yesno 'q?' yes && echo yes || echo no)" "no"
check "yes/no empty is default"  "$(printf '\n' | ui plain ui_yesno 'q?' yes && echo yes || echo no)" "yes"

echo "== the plan, unattended =="
plan=$(export "$UI_VAR=none"; setup --dry-run --unattended --no-preflight)
check "installs by copying"     "$(printf '%s' "$plan" | grep -c 'install.sh --copy')" "1"
check "our shell draws"         "$(printf '%s' "$plan" | grep -c 'renderer.sh set quickshell')" "1"
check "binds the two keys"      "$(printf '%s' "$plan" | grep -cE 'shortcuts.sh set (launcher Meta|search Meta\+Space)$')" "2"
check "binds nothing else"      "$(printf '%s' "$plan" | grep -c 'shortcuts.sh set ')" "2"
check "Alt+Tab stays KWin's"    "$(printf '%s' "$plan" | grep -c 'switcher.sh use plasma')" "1"
check "themes the desktop"      "$(printf '%s' "$plan" | grep -c 'theme.sh apply')" "1"
check "enables the unit"        "$(printf '%s' "$plan" | grep -c "systemctl --user enable --now $SYSTEMD_UNIT")" "1"
check "takes a restore point"   "$(printf '%s' "$plan" | grep -c 'snapshot.sh create before-setup')" "1"
check "lists the windows"       "$(printf '%s' "$plan" | grep -c 'windows.sh enable')" "1"
check "builds the previews"     "$(printf '%s' "$plan" | grep -c 'plugin$')" "1"
check "with what they need"     "$(printf '%s' "$plan" | grep -c 'deps.sh install --build --yes')" "1"
check "a dry run changes nothing" "$(ls "$XDG_DATA_HOME" | wc -l)" "0"

echo "== --no-snapshot is the only way to skip the restore point =="
plan=$(export "$UI_VAR=none"; setup --dry-run --unattended --no-preflight --no-snapshot)
check "no snapshot"             "$(printf '%s' "$plan" | grep -c 'snapshot.sh create')" "0"
check "still installs"          "$(printf '%s' "$plan" | grep -c 'install.sh --copy')" "1"

echo "== answered at a terminal =="
# link, plasma, two other keys, Alt+Tab left alone, no window list, no
# previews, no theme, no autostart, and yes to the summary.
plan=$(printf 'link\nplasma\nsettings sidebar\nnone\nn\nn\nn\nn\ny\n' \
       | (export "$UI_VAR=plain"; setup --dry-run --no-preflight --no-snapshot))
check "links the checkout"      "$(printf '%s' "$plan" | grep -c 'install.sh --link')" "1"
check "Plasma draws"            "$(printf '%s' "$plan" | grep -c 'renderer.sh set plasma')" "1"
check "binds what was ticked"   "$(printf '%s' "$plan" | grep -cE 'shortcuts.sh set (settings|sidebar) ')" "2"
check "leaves Alt+Tab alone"    "$(printf '%s' "$plan" | grep -c 'switcher.sh use')" "0"
check "leaves the theme alone"  "$(printf '%s' "$plan" | grep -c 'theme.sh apply')" "0"
check "does not enable the unit" "$(printf '%s' "$plan" | grep -c 'systemctl --user enable')" "0"
check "no window list"          "$(printf '%s' "$plan" | grep -c 'windows.sh enable')" "0"
check "builds nothing"          "$(printf '%s' "$plan" | grep -cE 'deps.sh install|plugin$')" "0"

echo "== the summary is the one-way door =="
# Everything answered -- eight questions -- then no at the summary: nothing
# is applied at all.
plan=$(printf '\n\n\n\n\n\n\n\nn\n' \
       | (export "$UI_VAR=plain"; setup --dry-run --no-preflight))
check "nothing would run"       "$(printf '%s' "$plan" | grep -c 'would run')" "0"
check "and it says so"          "$(printf '%s' "$plan" | grep -c 'nothing was changed')" "1"

echo "== unknown arguments are refused =="
check "refuses an unknown flag" "$(setup --wat >/dev/null 2>&1 && echo ran || echo refused)" "refused"

harness_done

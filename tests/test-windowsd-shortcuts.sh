#!/usr/bin/env bash
# Tests the global shortcuts the session daemon owns, inside a throwaway HOME.
#
# The CLI that binds them is tested in test-shortcuts.sh, which also checks
# that the daemon and the CLI agree on every key.
set -uo pipefail

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
source "$REPO_ROOT/tests/lib/harness.sh"
harness_init
source "$REPO_ROOT/tests/lib/windowsd.sh"
windowsd_require
windowsd_example

# The shortcuts the daemon owns. Two things can be checked without a session:
# that a key string becomes the integer kglobalaccel wants -- the same numbers
# scripts/lib/accel.sh is checked against, from the same measurements off a
# running server -- and that the component's group is read out of the file the
# way kglobalaccel writes it.
echo "== the shortcuts the daemon owns =="
windowsd_python "$SANDBOX" <<'PYTEST'
import sys, os
from windowsd import brand, shortcuts
from windowsd.keys import keycode
sandbox = sys.argv[1]

for name, spec, want in [
    ("Print", "Print", 16777225),
    ("Meta+Shift+Print", "Meta+Shift+Print", 318767113),
    ("a letter is its ASCII", "Q", 81),
    ("lower case too", "q", 81),
    ("Meta+Space", "Meta+Space", 268435488),
    ("a function key", "F5", 16777268),
    ("Alt+Tab", "Alt+Tab", 150994945),
    ("every modifier at once", "Meta+Alt+Ctrl+Shift+Delete", 520093703),
    ("Meta alone is a key", "Meta", 16777250),
    ("a modifier nobody knows", "Hyper+Q", None),
    ("a key nobody knows", "Meta+Banana", None),
    ("nothing at all", "", None),
    ("Meta+/, as the file spells it", "Meta+/", 268435503),
    ("Meta+Slash, spelled out", "Meta+Slash", 268435503),
    ("Meta+Shift+S", "Meta+Shift+S", 301989971),
]:
    check(name, keycode(spec), want)

# The file as kglobalaccel keeps it: a component's group, three fields, a tab
# between two keys written as a literal backslash-t.
config = os.path.join(sandbox, "kglobalshortcutsrc")
os.environ["XDG_CONFIG_HOME"] = sandbox
open(config, "w").write(
    "[somebodyelse]\n"
    "launcher=Meta+X,none,Not ours\n"
    "\n"
    "[t]\n"
    "launcher=Meta,none,Application menu\n"
    "search=none,none,Search\n"
    "switcher=Alt+Tab\\tMeta+F1,none,Window switcher\n"
    "nosuchaction=Meta+Z,none,Unknown\n"
)
found = shortcuts.GlobalShortcuts.bindings()
check("reads our group only", found.get("launcher"), ["Meta"])
check("an unbound action is empty", found.get("search"), [])
check("two keys on one action", found.get("switcher"), ["Alt+Tab", "Meta+F1"])
check("an action we do not know is ignored", "nosuchaction" in found, False)

# Ownership: only the daemon holding the shell's own bus name claims the
# shell's keys. A second copy that did would take them off the first, on the
# live session, which is what the test suite itself once did.
wanted = shortcuts.shortcuts_wanted
os.environ.pop(shortcuts.NO_SESSION_VAR, None)
brand.BUS_NAME = shortcuts.SHORTCUT_OWNER
check("the daemon that owns the name claims them", wanted(), True)
brand.BUS_NAME = shortcuts.SHORTCUT_OWNER + "Test1234"
check("a copy under another name claims nothing", wanted(), False)
brand.BUS_NAME = shortcuts.SHORTCUT_OWNER
os.environ[shortcuts.NO_SESSION_VAR] = "1"
check("and neither does one with no session", wanted(), False)
PYTEST

harness_done

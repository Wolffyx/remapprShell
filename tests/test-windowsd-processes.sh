#!/usr/bin/env bash
# Tests what the session daemon reads about the process behind a window,
# inside a throwaway HOME.
set -uo pipefail

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
source "$REPO_ROOT/tests/lib/harness.sh"
harness_init
source "$REPO_ROOT/tests/lib/windowsd.sh"
windowsd_require
windowsd_example

# What Plasma reads about the process behind a window, for the shell to match
# it by when the window itself matches no application: the command line and
# the name KProcessList makes of it, and of the environment two variables and
# nothing else. Read from a /proc made up here, so every case is one the test
# decides.
echo "== what Plasma reads about a window's process =="
windowsd_python "$SANDBOX" <<'PYTEST'
import sys, os, json
from windowsd.desktop_files import app_id_file
from windowsd.processes import Processes
sandbox = sys.argv[1]

root = os.path.join(sandbox, "procfacts")
proc = os.path.join(root, "proc")
def write(path, data, mode=0o644):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "wb" if isinstance(data, bytes) else "w") as handle:
        handle.write(data)
    os.chmod(path, mode)
    return path
def process(pid, comm="example", cmdline=b"", environ=b""):
    write(os.path.join(proc, str(pid), "stat"), f"{pid} ({comm}) S 1 1 1 0 -1")
    write(os.path.join(proc, str(pid), "cmdline"), cmdline)
    write(os.path.join(proc, str(pid), "environ"), environ)

# The command line, as KProcessList gives it.
process(101, cmdline=b"/opt/example/bin/example-viewer\0--open\0some file.txt\0")
check("NULs are spaces",                 Processes.command(101, proc),
      ("/opt/example/bin/example-viewer --open some file.txt", "example-viewer"))
process(102, cmdline=b"C:\\Programs\\Example App\\app.exe\0" + b"\0" * 40)
check("the padding a program leaves is trimmed, and a name with no slash is whole",
      Processes.command(102, proc), ("C:\\Programs\\Example App\\app.exe", "C:\\Programs\\Example App\\app.exe"))
process(103, comm="kernel-thing")
check("no arguments: the kernel's name for it", Processes.command(103, proc), ("kernel-thing", "kernel-thing"))
check("a process that cannot be read gives nothing", (Processes.command(999, proc), Processes.read(999, proc)), (None, {}))
process(104, cmdline=b"x" * 5000)
check("a command line is cut where no Exec line reaches", len(Processes.read(104, proc, path="")["cmdline"]), 4096)

# The words of it that are programs on PATH -- QStandardPaths' rules, not
# shutil.which's: a relative path is looked for on PATH too.
bindir = os.path.join(root, "bin")
write(os.path.join(bindir, "example-tool"), "#!/bin/sh\n", 0o755)
write(os.path.join(bindir, "not-a-program"), "", 0o644)
write(os.path.join(bindir, "sub", "tool"), "#!/bin/sh\n", 0o755)
absolute = write(os.path.join(root, "elsewhere", "example-run"), "#!/bin/sh\n", 0o755)
line = f"example-tool not-a-program sub/tool {absolute} --flag example-tool"
check("the programs among the words, once each", Processes.executables(line, bindir),
      ["example-tool", "sub/tool", absolute])
check("only the first sixteen words are looked at",
      Processes.executables(" ".join(["w"] * 16 + ["example-tool"]), bindir), [])

# The environment: two variables, the first one there deciding, and nothing
# else of it kept.
data = os.path.join(root, "data")
os.environ["XDG_DATA_HOME"] = data
os.environ["LANG"] = "de_DE.UTF-8"
hinted = write(os.path.join(data, "applications", "sub", "example-hinted.desktop"),
               "[Desktop Entry]\nType=Application\nName=Hinted\nName[de]=Angedeutet\nIcon=example-hinted\n"
               "[Desktop Action New]\nName=New Window\n")
process(105, environ=b"HOME=/somewhere\0PRIVATE_THING=secret\0"
                     b"BAMF_DESKTOP_FILE_HINT=" + hinted.encode() + b"\0APPDIR=/nowhere\0")
hint = Processes.desktop_hint(105, proc)
check("a desktop file hint, with its id among the installed ones",
      (hint["variable"], hint["path"], hint["id"]), ("BAMF_DESKTOP_FILE_HINT", hinted, "sub-example-hinted"))
check("its name in the session's language, not an action's", hint["name"], "Angedeutet")
check("nothing else of the environment", "secret" in json.dumps(Processes.read(105, proc)), False)

appdir = os.path.join(root, "mounted")
write(os.path.join(appdir, "Zeta.desktop"), "[Desktop Entry]\nName=Zeta\n")
write(os.path.join(appdir, "alpha.desktop"), "[Desktop Entry]\nName=Alpha\nIcon=alpha-icon.svg\n")
write(os.path.join(appdir, "alpha-icon.svg"), "<svg/>")
write(os.path.join(appdir, "alpha-icon.png"), b"png")
process(106, environ=b"APPDIR=" + appdir.encode() + b"\0")
hint = Processes.desktop_hint(106, proc)
check("a mounted application: its first desktop file by name, whatever the case",
      (hint["variable"], hint["name"], hint["id"]), ("APPDIR", "Alpha", ""))
check("and the icon beside it, a PNG first", hint["iconFile"], os.path.join(appdir, "alpha-icon.png"))
empty = os.path.join(root, "empty")
os.makedirs(empty)
process(107, environ=b"APPDIR=" + empty.encode() + b"\0BAMF_DESKTOP_FILE_HINT=" + hinted.encode() + b"\0")
check("the first variable decides even when it names nothing", Processes.desktop_hint(107, proc), None)
process(108, environ=b"APPDIR=" + appdir.encode() + b"\0")
os.chmod(os.path.join(proc, "108", "environ"), 0)
check("an environment that cannot be read gives nothing", Processes.desktop_hint(108, proc), None)

# An app id that is a desktop file's path, as it is or without the suffix.
named = write(os.path.join(root, "files", "example-named.desktop"), "[Desktop Entry]\nName=Named\nIcon=/an/icon.png\n")
check("an app id that is a desktop file's path",
      (app_id_file({"desktopFile": named})["name"], app_id_file({"desktopFile": named})["iconFile"]), ("Named", ""))
check("or is one without the suffix", app_id_file({"desktopFile": "", "appId": named[:-8]})["path"], named)
check("but not a name, nor a path to nothing",
      (app_id_file({"appId": "example-named"}), app_id_file({"appId": "/no/such/thing"})), (None, None))

# Kept per process while it has a window, and not after.
class Counting(Processes):
    reads = 0
    @staticmethod
    def read(pid, proc="/proc", path=None):
        Counting.reads += 1
        return {"cmdline": str(pid)}
kept = Counting()
for pid in (5, 5, 6, 5):
    kept.facts_for(pid)
check("read once for each process", Counting.reads, 2)
kept.forget_all_but({6})
kept.facts_for(5)
check("and again once it had gone", Counting.reads, 3)
check("no process, nothing read", (kept.facts_for(0), kept.facts_for(None), Counting.reads), ({}, {}, 3))
PYTEST

harness_done

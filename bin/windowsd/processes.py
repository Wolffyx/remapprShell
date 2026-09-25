"""What Plasma reads about the process behind a window."""

import os

from .desktop_files import first_desktop_file, menu_id, read_desktop_file

# Plasma's task manager finds a window's application from the window first --
# its app id and class against the installed desktop entries -- and, when none
# of that matches, from the process that owns it: two variables of its
# environment, then its command line (servicesFromEnvironment and
# servicesFromPid in plasma-workspace's libtaskmanager/tasktools.cpp). The
# shell does the matching, since it is the one holding the desktop entries;
# what it cannot do is read another process's /proc, or a desktop file that is
# not among the installed ones. So the daemon reads those -- here, and in
# desktop_files.py -- and sends them with the window.
#
# Only what Plasma reads, and nothing of the environment but those two
# variables: an environment is full of things that are nobody's business, and
# this goes out on the session bus with every update.

# The two variables, looked for in the order the environment has them: the
# path of a desktop file (what a Snap sets) and the directory an AppImage is
# mounted at.
DESKTOP_HINT_VARIABLES = ("BAMF_DESKTOP_FILE_HINT", "APPDIR")

# A command line is sent whole up to here. Plasma compares one with an entry's
# Exec line, and no Exec line is this long; past it is a list of arguments no
# window was ever matched by, which would go out with every update.
CMDLINE_MAX = 4096

# How many words of a command line are looked up on PATH. Plasma's last step
# asks about the first word left once an interpreter it skips is gone, and an
# interpreter is one word: sixteen is far past any line it could reach.
COMMAND_WORDS = 16


def find_executable(word, path=None):
    """Where QStandardPaths::findExecutable finds `word`, or "".

    An absolute path is taken as it is. Anything else is looked for in each
    directory on PATH -- a relative path too, which is what Qt does and what
    Python's shutil.which does not.
    """
    def runnable(candidate):
        return os.path.isfile(candidate) and os.access(candidate, os.X_OK)

    if not word:
        return ""
    if os.path.isabs(word):
        return os.path.normpath(word) if runnable(word) else ""
    for directory in (os.environ.get("PATH", "") if path is None else path).split(os.pathsep):
        if directory:
            candidate = os.path.normpath(os.path.join(directory, word))
            if runnable(candidate):
                return candidate
    return ""


class Processes:
    """What Plasma reads about the process behind a window, kept per process.

    Read once for a process and kept while it has a window on the list: its
    command line and environment do not change under the window, and /proc is
    read on the thread that answers D-Bus. A process whose /proc cannot be
    read -- another user's, or one that has just gone -- gives nothing, and
    gives Plasma nothing either.
    """

    def __init__(self):
        self._facts = {}          # pid -> what was read

    def facts_for(self, pid):
        if not isinstance(pid, int) or pid <= 0:
            return {}
        if pid not in self._facts:
            self._facts[pid] = self.read(pid)
        return self._facts[pid]

    def forget_all_but(self, pids):
        """Drop what was read about processes that no longer have a window.

        A process id is reused once its process is gone, and what was true of
        the old one is not of the new.
        """
        for pid in [p for p in self._facts if p not in pids]:
            del self._facts[pid]

    @staticmethod
    def read(pid, proc="/proc", path=None):
        facts = {}
        command = Processes.command(pid, proc)
        if command is not None:
            line, name = command
            facts["cmdline"] = line[:CMDLINE_MAX]
            facts["processName"] = name
            facts["executables"] = Processes.executables(line, path)
        hint = Processes.desktop_hint(pid, proc)
        if hint:
            facts["desktopHint"] = hint
        return facts

    @staticmethod
    def command(pid, proc="/proc"):
        """The command line and the process's name, as KProcessList gives them.

        The line is /proc's with every NUL a space and the ends trimmed. The
        name is the last path component of the first argument, and the name
        the kernel keeps for the process when there are no arguments to read.
        None when the process cannot be read at all.
        """
        base = os.path.join(proc, str(pid))
        try:
            with open(os.path.join(base, "stat"), "rb") as handle:
                fields = handle.read().decode("utf-8", "replace").split(" ")
        except OSError:
            return None
        if len(fields) < 2:
            return None
        name = fields[1]
        if name.startswith("(") and name.endswith(")"):
            name = name[1:-1]
        line = name
        try:
            with open(os.path.join(base, "cmdline"), "rb") as handle:
                raw = handle.read()
        except OSError:
            raw = b""
        if raw:
            zero = raw.find(b"\0")
            end = zero if zero >= 0 else len(raw)
            name = raw[raw.rfind(b"/", 0, end + 1) + 1:end].decode("utf-8", "replace")
            line = raw.replace(b"\0", b" ").decode("utf-8", "replace").strip(" \t\n\r\v\f")
        return line, name

    @staticmethod
    def executables(line, path=None):
        """The words of a command line that name a program on PATH.

        Plasma's last step names a window after its process when the command
        it ends on -- the first word left once an interpreter it skips is gone
        -- is a program QStandardPaths can find. Which word that is depends on
        the matching, and the matching is the shell's; whether a word is a
        program depends on the file system, which only this side can look at.
        So each word it could be is looked up here, and the programs are sent.
        """
        found = []
        for word in line.split(" ")[:COMMAND_WORDS]:
            if word and word not in found and find_executable(word, path):
                found.append(word)
        return found

    @staticmethod
    def desktop_hint(pid, proc="/proc"):
        """The desktop file the process's environment names, read, or None.

        The first of the two variables the environment has decides, whatever
        it turns out to name: Plasma stops there. Nothing else of the
        environment is kept.
        """
        try:
            with open(os.path.join(proc, str(pid), "environ"), "rb") as handle:
                environ = handle.read()
        except OSError:
            return None
        for entry in environ.split(b"\0"):
            key, sep, value = entry.partition(b"=")
            key = key.decode("utf-8", "replace")
            if not sep or key not in DESKTOP_HINT_VARIABLES:
                continue
            value = value.decode("utf-8", "replace")
            path = first_desktop_file(value) if key == "APPDIR" else value
            if not path:
                return None
            hint = {"variable": key, "path": path, "id": menu_id(path)}
            hint.update(read_desktop_file(path) or {})
            return hint
        return None

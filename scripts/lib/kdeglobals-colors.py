#!/usr/bin/env python3
"""Copies a colour scheme's colours into kdeglobals, reversibly.

Selecting a colour scheme in KDE is two things, and this project had only ever
done the first: `kdeglobals [General] ColorScheme` *names* the scheme, and the
scheme's own `[Colors:*]` and `[WM]` groups are copied into kdeglobals, where
every Qt and KDE application actually reads its colours. Without the copy, the
name said light while every window stayed the colour the last scheme left
behind -- and the desktop portal, which decides what Chrome and every Electron
application do, reads those same values and answers "dark".

Plasma's own Colors page does the copy. `plasma-apply-colorscheme` does it too
and keeps no record of what was there, which is the reason this exists
instead: a scheme is over a hundred keys, so the per-key ledger the rest of
this project writes would mean a hundred jq rewrites per switch, twice a day.

It works on lines rather than through ConfigParser, and only on the groups a
colour scheme governs. That is not fussiness: `theme revert` has to leave
every KDE config file **byte-identical**, and a parser that reads and rewrites
the whole file reorders keys and drops comments even when the values it wrote
are the ones that were already there.

Copying is only half of it. KDE's own tools write kdeglobals through KConfig
with its `Notify` flag, which puts a `ConfigChanged` signal on the bus; every
`KConfigWatcher` in the session is listening for it. Writing the file by hand,
as this does, is silent -- and a silent write is a write nobody acts on. That
was measured on 2026-09-23: after it, a window's *contents* changed (the legacy
`KGlobalSettings` notify reaches those) and its **titlebar did not**, because
KWin's decoration palette is a `KConfigWatcher` and heard nothing. So `notify`
sends the signal KConfig would have sent.

    save <kdeglobals> <backup.json>            once, before the first write
    save-widened <kdeglobals> <backup.json>    add groups an older save missed
    apply <scheme.colors> <kdeglobals>         copy the colours in
    notify <scheme.colors>                     tell the session it changed
    restore <backup.json> <kdeglobals>         put the saved groups back
"""

import json
import subprocess
import sys

# What a colour scheme governs. `[Colors:*]` is the palette proper; `[WM]` is
# the titlebar, which KWin reads from kdeglobals rather than from the scheme;
# `[ColorEffects:*]` is how disabled and inactive things are drawn, and is as
# much a part of the scheme as the rest -- left behind until 2026-09-23, so a
# light desktop greyed its disabled text with the dark scheme's grey.
GROUP_PREFIXES = ("Colors:", "ColorEffects:")
GROUPS = ("WM",)


# What `_governed` covered before `[ColorEffects:*]` joined it. A backup
# written then says nothing about those groups, and cannot be read as if it
# did: see `save_widened`.
GROUP_PREFIXES_BEFORE_2026_09_23 = ("Colors:",)
GROUPS_BEFORE_2026_09_23 = ("WM",)


def _governed(section, prefixes=GROUP_PREFIXES, groups=GROUPS):
    return section in groups or section.startswith(prefixes)


def _blocks(text):
    """The file as [(section or None, [lines])], preserving every byte.

    The first block carries whatever sits above the first group header --
    usually nothing, sometimes a comment.
    """
    out = [(None, [])]
    for line in text.splitlines(keepends=True):
        stripped = line.strip()
        if stripped.startswith("[") and stripped.endswith("]"):
            out.append((stripped[1:-1], [line]))
        else:
            out[-1][1].append(line)
    return out


def _render(blocks):
    text = "".join("".join(lines) for _, lines in blocks)
    # KConfig puts a blank line before each group when it rewrites the file, so
    # the blank above a group we then take away is left behind at the end --
    # one byte that fails `theme revert`'s "byte-identical" gate, which is
    # exactly the gate that makes this whole approach safe.
    text = text.rstrip("\n")
    return text + "\n" if text else ""


def _read(path):
    try:
        with open(path, encoding="utf-8") as f:
            return f.read()
    except FileNotFoundError:
        return ""


def _write(path, text):
    with open(path, "w", encoding="utf-8") as f:
        f.write(text)


def _governs_now():
    return {"prefixes": list(GROUP_PREFIXES), "groups": list(GROUPS)}


def save(kdeglobals, backup):
    """Remember the governed groups, verbatim, and where they sat.

    `governs` records what "governed" meant at the time, because that is the
    one thing a later reader cannot work out for itself: a group absent from
    `blocks` was either not there, or not ours to look at yet, and telling
    those apart is the whole of `save_widened`.
    """
    blocks = _blocks(_read(kdeglobals))
    kept = [
        {"index": i, "section": section, "text": "".join(lines)}
        for i, (section, lines) in enumerate(blocks)
        if section and _governed(section)
    ]
    _write(backup, json.dumps({"governs": _governs_now(), "blocks": kept}, indent=2))
    return 0


def save_widened(kdeglobals, backup):
    """Add groups a backup written under a narrower `_governed` never saw.

    The set grew on 2026-09-23 to take in `[ColorEffects:*]`. A backup saved
    before that knows nothing of them, so a `revert` would take them away and
    put nothing back -- this project's one promise about other people's
    configuration, broken by an upgrade.

    Only groups that were **outside** the old set are added. A group inside it
    and absent from the backup was absent from the file, and adding it here
    would record our own colours as the user's: the backup would then hand a
    revert the scheme it was meant to undo.
    """
    try:
        with open(backup, encoding="utf-8") as f:
            saved = json.load(f)
    except (OSError, ValueError):
        return 0

    governs = saved.get("governs") or {
        "prefixes": list(GROUP_PREFIXES_BEFORE_2026_09_23),
        "groups": list(GROUPS_BEFORE_2026_09_23),
    }
    if governs == _governs_now():
        return 0

    was = (tuple(governs.get("prefixes", ())), tuple(governs.get("groups", ())))
    blocks = saved.get("blocks", [])
    known = {entry.get("section") for entry in blocks}
    added = [
        {"index": i, "section": section, "text": "".join(lines)}
        for i, (section, lines) in enumerate(_blocks(_read(kdeglobals)))
        if section
        and _governed(section)
        and not _governed(section, was[0], was[1])
        and section not in known
    ]
    saved["blocks"] = blocks + added
    saved["governs"] = _governs_now()
    _write(backup, json.dumps(saved, indent=2))
    return 0


def apply_scheme(scheme, kdeglobals):
    """Copy the scheme's colour groups in, replacing the ones there."""
    wanted = [
        (section, lines)
        for section, lines in _blocks(_read(scheme))
        if section and _governed(section)
    ]
    if not wanted:
        print("that scheme carries no colours", file=sys.stderr)
        return 1

    # Replaced rather than merged: a scheme that does not name a key means the
    # default, and leaving the previous scheme's value there is how a light
    # window ends up with a dark selection.
    blocks = [b for b in _blocks(_read(kdeglobals)) if not (b[0] and _governed(b[0]))]
    _write(kdeglobals, _render(blocks + wanted))
    return 0


# The object path KConfig uses for kdeglobals, the interface and signal it
# sends, and the argument it sends them with: a map of group name to the keys
# in it that changed, the keys as byte arrays. Read off the bus on 2026-09-23
# from a real `kwriteconfig6 --notify`, rather than taken from memory.
NOTIFY_PATH = "/kdeglobals"
NOTIFY_INTERFACE = "org.kde.kconfig.notify"
NOTIFY_SIGNAL = "ConfigChanged"
NOTIFY_SIGNATURE = "a{saay}"


def _changes(scheme):
    """{group: [key, ...]} for everything an apply of this scheme writes.

    `General: [ColorScheme]` goes in whether or not the scheme file carries it:
    it is the key listeners key off -- it is what KDE's own apply names -- and
    the name beside the colours is written by the caller, not here.
    """
    changes = {"General": ["ColorScheme"]}
    for section, lines in _blocks(_read(scheme)):
        if not section or not _governed(section):
            continue
        keys = [
            line.split("=", 1)[0].strip()
            for line in lines
            if "=" in line and not line.lstrip().startswith(("#", "[", ";"))
        ]
        if keys:
            changes.setdefault(section, []).extend(keys)
    return changes


def notify(scheme):
    """Say on the bus what KConfig would have said, had it done the writing.

    Byte-exact on purpose: `gdbus emit` writes a GVariant bytestring, which is
    nul-terminated, and a listener comparing key names would find none of them.
    `busctl` takes the bytes as numbers and sends exactly those.
    """
    changes = _changes(scheme)
    args = ["busctl", "--user", "emit", NOTIFY_PATH,
            NOTIFY_INTERFACE, NOTIFY_SIGNAL, NOTIFY_SIGNATURE, str(len(changes))]
    for group, keys in changes.items():
        args += [group, str(len(keys))]
        for key in keys:
            raw = key.encode()
            args += [str(len(raw))] + [str(byte) for byte in raw]
    try:
        return subprocess.run(args, check=False).returncode
    except OSError as err:
        print(f"could not announce the colours: {err}", file=sys.stderr)
        return 1


def restore(backup, kdeglobals):
    """Take ours away and put the saved groups back where they were."""
    with open(backup, encoding="utf-8") as f:
        saved = json.load(f).get("blocks", [])

    blocks = [b for b in _blocks(_read(kdeglobals)) if not (b[0] and _governed(b[0]))]
    for entry in sorted(saved, key=lambda e: e.get("index", 0)):
        at = min(max(int(entry.get("index", len(blocks))), 0), len(blocks))
        blocks.insert(at, (entry.get("section"), [entry.get("text", "")]))
    _write(kdeglobals, _render(blocks))
    return 0


def main(argv):
    if len(argv) == 3 and argv[1] == "notify":
        return notify(argv[2])
    if len(argv) != 4:
        print(__doc__, file=sys.stderr)
        return 2
    what, first, second = argv[1], argv[2], argv[3]
    if what == "save":
        return save(first, second)
    if what == "save-widened":
        return save_widened(first, second)
    if what == "apply":
        return apply_scheme(first, second)
    if what == "restore":
        return restore(first, second)
    print(f"unknown command: {what}", file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv))

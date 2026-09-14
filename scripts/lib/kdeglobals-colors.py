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

    save <kdeglobals> <backup.json>            once, before the first write
    apply <scheme.colors> <kdeglobals>         copy the colours in
    restore <backup.json> <kdeglobals>         put the saved groups back
"""

import json
import sys

# What a colour scheme governs. `[Colors:*]` is the palette proper; `[WM]` is
# the titlebar, which KWin reads from kdeglobals rather than from the scheme.
GROUP_PREFIXES = ("Colors:",)
GROUPS = ("WM",)


def _governed(section):
    return section in GROUPS or section.startswith(GROUP_PREFIXES)


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


def save(kdeglobals, backup):
    """Remember the governed groups, verbatim, and where they sat."""
    blocks = _blocks(_read(kdeglobals))
    kept = [
        {"index": i, "section": section, "text": "".join(lines)}
        for i, (section, lines) in enumerate(blocks)
        if section and _governed(section)
    ]
    _write(backup, json.dumps({"blocks": kept}, indent=2))
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
    if len(argv) != 4:
        print(__doc__, file=sys.stderr)
        return 2
    what, first, second = argv[1], argv[2], argv[3]
    if what == "save":
        return save(first, second)
    if what == "apply":
        return apply_scheme(first, second)
    if what == "restore":
        return restore(first, second)
    print(f"unknown command: {what}", file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv))

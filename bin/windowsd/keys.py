"""A key as kglobalshortcutsrc spells it, as the integer kglobalaccel wants."""

import re

from . import brand

# Qt::KeyboardModifier values, ORed into the key. The same table as
# scripts/lib/accel.sh, because the file stores "Meta+Space" and kglobalaccel
# wants an integer.
_MODIFIERS = {
    "meta": 0x10000000, "super": 0x10000000, "win": 0x10000000,
    "ctrl": 0x04000000, "control": 0x04000000,
    "alt": 0x08000000,
    "shift": 0x02000000,
}

# A modifier pressed alone is a key in its own right -- a bare Super opening a
# launcher is the obvious binding, and kglobalaccel accepts it.
_BARE_MODIFIERS = {
    "meta": 0x01000022, "super": 0x01000022, "win": 0x01000022,
    "ctrl": 0x01000021, "control": 0x01000021,
    "shift": 0x01000020,
    "alt": 0x01000023,
}

# Qt::Key values for every named key and punctuation mark, by name: the table
# scripts/lib/accel.sh reads, scripts/lib/keycodes.tsv, rendered into brand.py
# at install. Each side used to keep its own copy and they disagreed -- the
# CLI accepted "Volume Up" and this refused it, so the key was written to the
# file and never grabbed. Looked up without regard to case, like the
# modifiers.
_KEYCODES = {name.lower(): code for name, code in brand.ACCEL_KEYCODES.items()}


def keycode(spec):
    """"Meta+Shift+Print" -> one integer in Qt's encoding, or None.

    Anything this table does not know returns None rather than a guess: a
    wrong integer is a key bound to something the user never asked for.
    """
    # The plus key itself: "Meta++" split on "+" is a modifier and nothing,
    # which made it bare Meta here while the CLI bound Meta and Plus.
    if spec == "+":
        spec = "Plus"
    elif spec.endswith("++"):
        spec = spec[:-1] + "Plus"

    parts = [p.strip() for p in spec.split("+") if p.strip()]
    if len(parts) == 1 and parts[0].lower() in _BARE_MODIFIERS:
        return _BARE_MODIFIERS[parts[0].lower()]

    total = 0
    bases = [p for p in parts if p.lower() not in _MODIFIERS]
    for part in parts:
        mod = _MODIFIERS.get(part.lower())
        if mod is not None:
            total |= mod

    # Two things that are not modifiers means a modifier this table does not
    # know -- "Hyper+Q" must fail rather than quietly binding Q on its own.
    if len(bases) != 1:
        return None
    base = bases[0]

    low = base.lower()
    if low in _KEYCODES:
        return total | _KEYCODES[low]
    if len(base) == 1 and base.isalnum():
        return total | ord(base.upper())
    match = re.fullmatch(r"[Ff]([1-9]|1[0-9]|2[0-5])", base)
    if match:
        return total | (0x01000030 + int(match.group(1)) - 1)
    return None

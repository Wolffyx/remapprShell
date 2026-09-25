"""The desktop files a window, or the process behind it, names.

Half of what Plasma reads about a window beyond the window itself; the other
half, and why the daemon reads either, is in processes.py.
"""

import os


def application_dirs():
    """The directories desktop entries are installed in, in XDG's order."""
    home = os.environ.get("XDG_DATA_HOME") or os.path.join(os.path.expanduser("~"), ".local", "share")
    dirs = os.environ.get("XDG_DATA_DIRS") or "/usr/local/share:/usr/share"
    return [os.path.join(d, "applications") for d in [home, *dirs.split(":")] if d]


def menu_id(path):
    """The id an installed desktop file goes by, or "" for one that is not installed.

    The shell's list of entries names one by its path under an applications
    directory, a subdirectory joined on with a dash and the suffix dropped:
    applications/sub/name.desktop is "sub-name".
    """
    for directory in application_dirs():
        prefix = os.path.join(os.path.normpath(directory), "")
        if path.startswith(prefix) and path.endswith(".desktop"):
            return path[len(prefix):-len(".desktop")].replace("/", "-")
    return ""


def localized(values, key):
    """A key of a desktop file in the session's language, else as it is written."""
    lang = os.environ.get("LC_ALL") or os.environ.get("LC_MESSAGES") or os.environ.get("LANG") or ""
    lang = lang.split(".", 1)[0].split("@", 1)[0]
    for variant in (lang, lang.split("_", 1)[0]):
        if variant and variant not in ("C", "POSIX") and f"{key}[{variant}]" in values:
            return values[f"{key}[{variant}]"]
    return values.get(key, "")


def icon_beside(path, icon):
    """An icon file lying next to a desktop file, where Plasma looks for one.

    The Icon value without its suffix, as a PNG and then as an SVG -- which is
    where an AppImage keeps its own icon, since no theme has it.
    """
    if not icon or "/" in icon:
        return ""
    base = icon.rsplit(".", 1)[0] if "." in icon else icon
    for suffix in (".png", ".svg"):
        candidate = os.path.join(os.path.dirname(path), base + suffix)
        if os.path.isfile(candidate):
            return candidate
    return ""


def read_desktop_file(path):
    """What names and draws the application a desktop file describes, or None.

    For the desktop files the shell's list of installed entries does not have:
    the one inside an AppImage, or one a window's app id names by its path.
    Only the main group is read -- an action's Name is not the application's.
    """
    try:
        with open(path, encoding="utf-8", errors="replace") as handle:
            text = handle.read(1 << 16)
    except OSError:
        return None
    values, group = {}, None
    for raw in text.splitlines():
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        if line.startswith("[") and line.endswith("]"):
            group = line[1:-1]
            continue
        if group == "Desktop Entry" and "=" in line:
            key, value = line.split("=", 1)
            values.setdefault(key.strip(), value.strip())
    icon = values.get("Icon", "")
    return {"path": path, "name": localized(values, "Name"), "icon": icon,
            "iconFile": icon_beside(path, icon)}


def first_desktop_file(directory):
    """The first desktop file in a directory by name, as QDir lists them, or ""."""
    try:
        names = os.listdir(directory)
    except OSError:
        return ""
    files = sorted((n for n in names
                    if n.lower().endswith(".desktop") and not n.startswith(".")
                    and os.path.isfile(os.path.join(directory, n))), key=str.lower)
    return os.path.join(directory, files[0]) if files else ""


def app_id_file(window):
    """The desktop file a window's app id names by its path, read, or None.

    Plasma's app id is the desktop file KWin associated with the window, else
    its class; one that is an absolute path is taken as a desktop file's --
    as it is, or with the suffix added.
    """
    app_id = window.get("desktopFile") or window.get("appId") or ""
    if not isinstance(app_id, str) or not app_id.startswith("/"):
        return None
    for path in (app_id, app_id + ".desktop"):
        if path.endswith(".desktop") and os.path.isfile(path):
            return read_desktop_file(path)
    return None

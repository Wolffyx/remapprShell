#!/usr/bin/env python3
"""Whether the sun is up: KDE's answer first, ours when KDE cannot give one.

    daylight.py [--prefer kde|shell] [--coordinates LAT,LON] [--cache FILE]
                [--desktop-id ID] [--timeout SECONDS] [--now MS] [--no-bus]

--no-bus asks neither KDE nor GeoClue: what the CLI passes when there is no
session to ask, so the test suites never reach the developer's own desktop.

    daylight.py --locate [--cache FILE] [--desktop-id ID] [--timeout S]

prints only where this machine is, the OS's way -- { "known": true,
"latitude": ..., "longitude": ..., "location": "geoclue" | "cache" } -- for
the weather, which asks the internet only when this has no answer.

Prints one JSON object and exits 0 when something knows, 3 when nothing does:

    { "known": true, "daylight": false, "source": "kde", "location": "kde",
      "next": 1793161033000, "why": "..." }

`source` is who answered -- "kde" or "shell" -- and `location` where the
place came from: "kde" (KDE worked it out itself), "geoclue", "cache" (the
last place GeoClue gave, kept for a login it is too slow for) or
"coordinates" (typed in by the user). `next` is when the answer changes, in
milliseconds since the epoch, or 0 when nothing says.

Why KDE first. Plasma's night time service, KNightTime, is the schedule the
rest of the desktop already follows: KWin's Night Light warms the screen on
it, and Plasma's "Switch to Dark Mode at Night" swaps the global theme on it.
A second clock here could only disagree with them. Unlike Night Light's own
`daylight`, KNightTime answers whether Night Light is on or not. A Plasma
older than 6.5 has no KNightTime, and there KWin's Night Light is asked
instead, as it always was.

Why ours at all. KNightTime can be missing -- uninstalled, not running, an
older Plasma -- and it can be wrong without saying so. Its location comes
from GeoClue, asked once when it starts; at login GeoClue can be too slow to
answer, and KNightTime then uses the fallback times from its settings,
18:00 and 06:00 by default, until it is restarted. Its schedule looks no
different: the same cycles, the same kind. What gives it away is that every
transition lands on those configured times to the second while the user has
asked for their location, which a real sunset never does. Either way the
answer here is worked out from the sun itself, at the place GeoClue gives,
or the one it gave last time, or the coordinates the user typed in. Nothing
here asks the internet: GeoClue is the OS's own, and a place nobody has
given is no answer rather than a guess.

Why Python. A GeoClue client belongs to the D-Bus connection that made it,
and its location arrives as a signal some time after `Start` returns; a
one-shot `busctl call` has disconnected by then, and its client with it.

    0  an answer; `known` is true
    3  nothing knows: no KDE schedule, no place
   64  a command line this does not understand
"""

import configparser
import json
import math
import os
import sys
import time
from datetime import datetime

EXIT_OK, EXIT_UNKNOWN, EXIT_USAGE = 0, 3, 64

NIGHT_TIME = ("org.kde.NightTime", "/org/kde/NightTime/Manager", "org.kde.NightTime.Manager")
GEOCLUE = "org.freedesktop.GeoClue2"
GEOCLUE_MANAGER = "/org/freedesktop/GeoClue2/Manager"

# GeoClue's accuracy levels. A city is plenty for a sunset -- a minute of
# sunset is some twenty kilometres -- and asks for no more than that.
ACCURACY_CITY = 4

# Where the sun's centre is at sunrise and sunset: half its width below the
# horizon, and the refraction that lifts it back into view.
HORIZON_DEG = -0.833

DAY_MS = 86400000


def fail(code, message):
    print(f"daylight: {message}", file=sys.stderr)
    sys.exit(code)


# ---- the sun ---------------------------------------------------------------

def elevation(lat, lon, ms):
    """The sun's elevation above the horizon in degrees, at a place and time.

    The US Naval Observatory's low-precision formulae: good to a minute of
    sunrise for two centuries either side of 2000, which is enough here.
    """
    d = ms / DAY_MS + 2440587.5 - 2451545.0
    g = math.radians((357.529 + 0.98560028 * d) % 360)
    q = (280.459 + 0.98564736 * d) % 360
    ecliptic = math.radians((q + 1.915 * math.sin(g) + 0.020 * math.sin(2 * g)) % 360)
    tilt = math.radians(23.439 - 0.00000036 * d)
    ra = math.atan2(math.cos(tilt) * math.sin(ecliptic), math.cos(ecliptic))
    dec = math.asin(math.sin(tilt) * math.sin(ecliptic))
    sidereal = (18.697374558 + 24.06570982441908 * d) % 24
    hour_angle = math.radians(sidereal * 15 + lon) - ra
    phi = math.radians(lat)
    return math.degrees(math.asin(math.sin(phi) * math.sin(dec)
                                  + math.cos(phi) * math.cos(dec) * math.cos(hour_angle)))


def is_up(lat, lon, ms):
    return elevation(lat, lon, ms) > HORIZON_DEG


def next_change(lat, lon, now):
    """When the sun next rises or sets, to the second, or 0 within two days.

    Stepped rather than solved: a formula for sunrise has no answer in a
    polar summer, and this needs none -- it finds the first step where the
    answer differs and halves the gap until it is a second wide.
    """
    up = is_up(lat, lon, now)
    step = 5 * 60000
    before = now
    for after in range(now + step, now + 2 * DAY_MS, step):
        if is_up(lat, lon, after) != up:
            return narrow(lambda ms: is_up(lat, lon, ms) == up, before, after)
        before = after
    return 0


def narrow(unchanged, before, after):
    """The first second after `before` where `unchanged` stops being true."""
    while after - before > 1000:
        middle = (before + after) // 2
        if unchanged(middle):
            before = middle
        else:
            after = middle
    return after


def sun_answer(lat, lon, now, location, why):
    return {
        "known": True,
        "daylight": is_up(lat, lon, now),
        "source": "shell",
        "location": location,
        "next": next_change(lat, lon, now),
        "why": why,
    }


# ---- KDE's schedule --------------------------------------------------------

def schedule_answer(cycles, now):
    """Day or night from KNightTime's cycles, and when that changes.

    Each cycle is (noon, morning start, morning end, evening start, evening
    end), in milliseconds. Day begins as the morning transition begins and
    ends as the evening one does -- where KWin's Night Light flips its own
    `daylight`, so the shell turns when the screen starts to warm.
    """
    daylight = any(c[1] <= now < c[3] for c in cycles)
    later = sorted(t for c in cycles for t in (c[1], c[3]) if t > now)
    return daylight, (later[0] if later else 0)


def knighttime_config(path):
    """What the user asked KNightTime for: (source, automatic, sunrise, sunset)."""
    parser = configparser.ConfigParser(interpolation=None, strict=False)
    parser.optionxform = str
    try:
        parser.read(path, encoding="utf-8")
    except configparser.Error as exc:
        print(f"daylight: {path} is unreadable, taking KDE's defaults: {exc}", file=sys.stderr)
    source = parser.get("General", "Source", fallback="Location")
    automatic = parser.get("Location", "Automatic", fallback="true").strip().lower() == "true"
    sunrise = parser.get("Times", "SunriseStart", fallback="06:00:00")
    sunset = parser.get("Times", "SunsetStart", fallback="18:00:00")
    return source, automatic, sunrise[:8], sunset[:8]


def clock(ms):
    return datetime.fromtimestamp(ms / 1000).strftime("%H:%M:%S")


def lost_location(cycles, config):
    """Whether KNightTime is on its fallback times while asked for a location.

    With `Source=Location` and `Automatic=true` it owes us a sunset; when
    every cycle starts on the configured fallback times instead, to the
    second, GeoClue did not answer it and it has not asked again. Typed
    times, or a typed location, are the user's own and always stand.
    """
    source, automatic, sunrise, sunset = config
    if source != "Location" or not automatic or not cycles:
        return False
    return all(clock(c[1]) == sunrise and clock(c[3]) == sunset for c in cycles)


def ask_knighttime(Gio, GLib, timeout):
    """KNightTime's cycles, or None when it is not there to ask."""
    name, path, iface = NIGHT_TIME
    try:
        bus = Gio.bus_get_sync(Gio.BusType.SESSION, None)
        reply = bus.call_sync(name, path, iface, "Subscribe",
                              GLib.Variant("(a{sv})", ({},)), GLib.VariantType("(a{sv})"),
                              Gio.DBusCallFlags.NONE, int(timeout * 1000), None)
    except GLib.Error:
        return None
    answer = reply.unpack()[0]
    cookie = answer.get("Cookie")
    if cookie is not None:
        try:
            bus.call_sync(name, path, iface, "Unsubscribe", GLib.Variant("(u)", (cookie,)),
                          None, Gio.DBusCallFlags.NONE, 2000, None)
        except GLib.Error as exc:
            print(f"daylight: KNightTime kept subscription {cookie}: {exc.message}", file=sys.stderr)
    schedule = answer.get("Schedule")
    if not schedule or len(schedule) < 2:
        return None
    return [tuple(c) for c in schedule[1] if len(c) >= 5]


def ask_night_light(Gio, GLib, timeout):
    """(daylight, next change in ms) from KWin's Night Light, or None.

    The schedule before KNightTime: a Plasma older than 6.5 has none, and
    there Night Light kept the location and the sunset itself. On a newer
    one it is asked only when KNightTime is not there, which it follows.
    """
    try:
        bus = Gio.bus_get_sync(Gio.BusType.SESSION, None)
        props = bus.call_sync("org.kde.KWin", "/org/kde/KWin/NightLight",
                              "org.freedesktop.DBus.Properties", "GetAll",
                              GLib.Variant("(s)", ("org.kde.KWin.NightLight",)),
                              GLib.VariantType("(a{sv})"), Gio.DBusCallFlags.NONE,
                              int(timeout * 1000), None).unpack()[0]
    except GLib.Error:
        return None
    if props.get("available") is not True or props.get("enabled") is not True:
        return None
    if not isinstance(props.get("daylight"), bool):
        return None
    return props["daylight"], int(props.get("scheduledTransitionDateTime") or 0) * 1000


# ---- where we are ----------------------------------------------------------

def geoclue_client(Gio, GLib, desktop_id, timeout):
    """(bus, client path) ready to start, or None when GeoClue is not there."""
    try:
        bus = Gio.bus_get_sync(Gio.BusType.SYSTEM, None)
        client = bus.call_sync(GEOCLUE, GEOCLUE_MANAGER, f"{GEOCLUE}.Manager", "GetClient",
                               None, GLib.VariantType("(o)"), Gio.DBusCallFlags.NONE,
                               int(timeout * 1000), None).unpack()[0]
        for prop, value in (("DesktopId", GLib.Variant("s", desktop_id)),
                            ("RequestedAccuracyLevel", GLib.Variant("u", ACCURACY_CITY))):
            bus.call_sync(GEOCLUE, client, "org.freedesktop.DBus.Properties", "Set",
                          GLib.Variant("(ssv)", (f"{GEOCLUE}.Client", prop, value)),
                          None, Gio.DBusCallFlags.NONE, 5000, None)
    except GLib.Error as exc:
        print(f"daylight: GeoClue cannot be asked: {exc.message}", file=sys.stderr)
        return None
    return bus, client


def ask_geoclue(Gio, GLib, desktop_id, timeout):
    """(latitude, longitude) from GeoClue, or None."""
    ready = geoclue_client(Gio, GLib, desktop_id, timeout)
    if ready is None:
        return None
    bus, client = ready
    loop = GLib.MainLoop()
    found = {}

    def on_location(_conn, _sender, _path, _iface, _signal, params, _data):
        found["path"] = params.unpack()[1]
        loop.quit()

    def timed_out():
        loop.quit()
        return False

    # Subscribed before Start: GeoClue may answer from its cache at once.
    subscription = bus.signal_subscribe(GEOCLUE, f"{GEOCLUE}.Client", "LocationUpdated",
                                        client, None, Gio.DBusSignalFlags.NONE, on_location, None)
    try:
        bus.call_sync(GEOCLUE, client, f"{GEOCLUE}.Client", "Start", None, None,
                      Gio.DBusCallFlags.NONE, int(timeout * 1000), None)
    except GLib.Error as exc:
        bus.signal_unsubscribe(subscription)
        print(f"daylight: GeoClue would not start: {exc.message}", file=sys.stderr)
        return None
    timer = GLib.timeout_add(int(timeout * 1000), timed_out)
    loop.run()
    if "path" in found:
        GLib.source_remove(timer)
    bus.signal_unsubscribe(subscription)

    where = geoclue_coordinates(Gio, GLib, bus, found["path"]) if "path" in found else None
    try:
        bus.call_sync(GEOCLUE, client, f"{GEOCLUE}.Client", "Stop", None, None,
                      Gio.DBusCallFlags.NONE, 2000, None)
    except GLib.Error as exc:
        print(f"daylight: GeoClue did not stop: {exc.message}", file=sys.stderr)
    return where


def geoclue_coordinates(Gio, GLib, bus, path):
    try:
        props = bus.call_sync(GEOCLUE, path, "org.freedesktop.DBus.Properties", "GetAll",
                              GLib.Variant("(s)", (f"{GEOCLUE}.Location",)),
                              GLib.VariantType("(a{sv})"), Gio.DBusCallFlags.NONE,
                              5000, None).unpack()[0]
    except GLib.Error as exc:
        print(f"daylight: GeoClue's location is unreadable: {exc.message}", file=sys.stderr)
        return None
    return valid(props.get("Latitude"), props.get("Longitude"))


def valid(lat, lon):
    try:
        lat, lon = float(lat), float(lon)
    except (TypeError, ValueError):
        return None
    if not (-90 <= lat <= 90 and -180 <= lon <= 180):
        return None
    return lat, lon


def coordinates(text):
    """"46.77,23.60" -> (46.77, 23.6), or None."""
    parts = [p.strip() for p in str(text or "").split(",")]
    return valid(*parts) if len(parts) == 2 else None


def read_cache(path):
    try:
        with open(path, encoding="utf-8") as f:
            data = json.load(f)
    except FileNotFoundError:
        return None
    except (OSError, ValueError) as exc:
        print(f"daylight: the kept place is unreadable: {exc}", file=sys.stderr)
        return None
    return valid(data.get("latitude"), data.get("longitude")) if isinstance(data, dict) else None


def write_cache(path, where):
    """Kept atomically, and only on this machine: it is somebody's home."""
    try:
        os.makedirs(os.path.dirname(path), exist_ok=True)
        temp = f"{path}.{os.getpid()}"
        with open(temp, "w", encoding="utf-8") as f:
            json.dump({"latitude": where[0], "longitude": where[1]}, f)
        os.chmod(temp, 0o600)
        os.replace(temp, path)
    except OSError as exc:
        print(f"daylight: could not keep the place: {exc}", file=sys.stderr)


# ---- the command -----------------------------------------------------------

FLAGS = {"--prefer": "prefer", "--coordinates": "coordinates", "--cache": "cache",
         "--desktop-id": "desktop_id", "--timeout": "timeout", "--now": "now"}


def parse(argv):
    opts = {"prefer": "kde", "coordinates": "", "cache": "", "desktop_id": "daylight",
            "timeout": "5", "now": None}
    opts["no_bus"] = "--no-bus" in argv
    opts["locate"] = "--locate" in argv
    args = [a for a in argv if a not in ("--no-bus", "--locate")]
    while args:
        arg = args.pop(0)
        if arg not in FLAGS or not args:
            fail(EXIT_USAGE, f"unknown argument: {arg}")
        opts[FLAGS[arg]] = args.pop(0)
    if opts["prefer"] not in ("kde", "shell"):
        fail(EXIT_USAGE, "--prefer takes kde or shell")
    try:
        opts["timeout"] = float(opts["timeout"])
        opts["now"] = int(opts["now"]) if opts["now"] is not None else int(time.time() * 1000)
    except ValueError:
        fail(EXIT_USAGE, "--timeout takes seconds and --now milliseconds")
    if opts["timeout"] <= 0:
        fail(EXIT_USAGE, "--timeout takes a number of seconds")
    return opts


def gio():
    try:
        import gi
        gi.require_version("Gio", "2.0")
        from gi.repository import Gio, GLib
    except (ImportError, ValueError):
        return None, None
    return Gio, GLib


def from_kde(Gio, GLib, opts):
    """KDE's answer and "", or None and the reason there is none."""
    if opts["prefer"] != "kde":
        return None, "theme.daylight.source is shell"
    if opts["no_bus"]:
        return None, "there is no session to ask KDE in"
    if Gio is None:
        return None, "python-gobject is not installed, so KDE cannot be asked"
    cycles = ask_knighttime(Gio, GLib, opts["timeout"])
    if cycles is None:
        return from_night_light(Gio, GLib, opts)
    config = knighttime_config(os.path.join(
        os.environ.get("XDG_CONFIG_HOME") or os.path.expanduser("~/.config"), "knighttimerc"))
    if lost_location(cycles, config):
        return None, f"KDE has lost the location and is on its fallback {config[2][:5]}/{config[3][:5]}"
    daylight, change = schedule_answer(cycles, opts["now"])
    return {"known": True, "daylight": daylight, "source": "kde", "location": "kde",
            "next": change, "why": "KDE's night time schedule"}, ""


def from_night_light(Gio, GLib, opts):
    """KWin's answer where there is no KNightTime: an older Plasma."""
    answer = ask_night_light(Gio, GLib, opts["timeout"])
    if answer is None:
        return None, "KDE has no night time service and Night Light is off or not there"
    daylight, change = answer
    return {"known": True, "daylight": daylight, "source": "kde", "location": "kde",
            "next": change, "why": "KWin's Night Light"}, ""


def where_we_are(Gio, GLib, opts):
    """(latitude, longitude, what said so), or None."""
    where = ask_geoclue(Gio, GLib, opts["desktop_id"], opts["timeout"]) if Gio else None
    if where and opts["cache"]:
        write_cache(opts["cache"], where)
    if where:
        return (*where, "geoclue")
    where = read_cache(opts["cache"]) if opts["cache"] else None
    if where:
        return (*where, "cache")
    where = coordinates(opts["coordinates"])
    return (*where, "coordinates") if where else None


SAID_BY = {
    "geoclue": "where GeoClue says",
    "cache": "where GeoClue last said",
    "coordinates": "at weather.coordinates",
}


def from_us(Gio, GLib, opts, because):
    """Our answer: the sun, at the best place there is."""
    where = where_we_are(Gio, GLib, opts)
    if where is None:
        return {"known": False, "daylight": None, "source": "", "location": "", "next": 0,
                "why": f"{because}, and nothing says where this machine is"}
    lat, lon, said_by = where
    return sun_answer(lat, lon, opts["now"], said_by, f"{because}; the sun, {SAID_BY[said_by]}")


def locate(Gio, GLib, opts):
    """--locate: only where this machine is, the OS's way, for the weather.

    GeoClue, or the place it gave last. Not the typed coordinates -- the
    weather reads its own -- and never the internet: a caller with no answer
    here decides for itself whether to ask one.
    """
    where = where_we_are(Gio, GLib, dict(opts, coordinates=""))
    if where is None:
        print(json.dumps({"known": False}))
        return EXIT_UNKNOWN
    lat, lon, said_by = where
    print(json.dumps({"known": True, "latitude": lat, "longitude": lon, "location": said_by}))
    return EXIT_OK


def main(argv):
    opts = parse(argv)
    Gio, GLib = (None, None) if opts["no_bus"] else gio()
    if opts["locate"]:
        return locate(Gio, GLib, opts)
    answer, because = from_kde(Gio, GLib, opts)
    if answer is None:
        answer = from_us(Gio, GLib, opts, because)
    elif Gio and opts["cache"] and not os.path.exists(opts["cache"]):
        # KDE answered, so nothing here needs the place today. It will on the
        # login GeoClue is too slow for -- the one KDE loses it on -- so it is
        # asked for once now, while GeoClue is up, and kept for that morning.
        where = ask_geoclue(Gio, GLib, opts["desktop_id"], opts["timeout"])
        if where:
            write_cache(opts["cache"], where)
    print(json.dumps(answer))
    return EXIT_OK if answer["known"] else EXIT_UNKNOWN


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))

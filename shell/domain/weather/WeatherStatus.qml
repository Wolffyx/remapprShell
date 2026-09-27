pragma Singleton

// The weather, fetched.
//
// This is the only part of this shell that talks to the internet, so it is off
// until `weather.enabled` is turned on and it asks for as little as it can:
//
//   - Open-Meteo, which needs no account and no key, and is asked only for a
//     pair of coordinates.
//   - A place you have named is turned into coordinates once, by Open-Meteo's
//     own geocoder. Coordinates you typed yourself are used as they are and
//     nothing is looked up at all.
//   - Only when neither is set is this machine's IP address used to guess
//     where it is -- one call, cached, and the setting that avoids it is one
//     line of text away.
//
// The answer is cached in the state directory with the time it was fetched, so
// a restart of the shell draws yesterday's forecast immediately and replaces
// it when the new one arrives, rather than showing nothing for two seconds on
// every start.
//
// The arithmetic -- codes, URLs, parsing -- is Forecast's, which is pure and
// tested. This holds the processes, the timer and the cache.

import QtQuick
import Quickshell.Io
import qs.core
import qs.platform.system
import qs.domain.config
import qs.domain.weather.forecast

QtObject {
    id: root

    readonly property bool enabled: ConfigStore.value("weather.enabled", false) === true
    readonly property string wantedPlace: String(ConfigStore.value("weather.place", "")).trim()
    readonly property string wantedCoordinates: String(ConfigStore.value("weather.coordinates", "")).trim()
    readonly property string units: ConfigStore.value("weather.units", "metric")
    readonly property int refreshMinutes: Math.max(10, Number(ConfigStore.value("weather.refresh", 30)) || 30)

    // Where the forecast is for: { latitude, longitude, name, source }.
    // `source` is "coordinates", "place" or "ip", which is what the settings
    // page shows so nobody has to guess whether they were geolocated.
    property var location: null

    // The forecast itself, as Forecast.parse returns it, or null.
    property var forecast: null

    property string error: ""
    property real fetchedAt: 0
    property bool busy: false

    readonly property bool ready: root.enabled && root.forecast !== null
    readonly property var current: root.forecast?.current ?? null
    readonly property var hours: root.forecast?.hours ?? []
    readonly property var days: root.forecast?.days ?? []
    readonly property string temperatureUnit: root.forecast?.temperatureUnit ?? "°"
    readonly property string placeName: root.location?.name ?? ""

    // What to draw for right now: { label, glyph, icon }.
    readonly property var condition: root.current
        ? Forecast.describe(root.current.code, root.current.isDay)
        : { label: "", glyph: "cloud", icon: "weather-none-available" }

    readonly property string temperatureText: root.current
        ? Forecast.degrees(root.current.temperature, root.temperatureUnit) : ""

    function refresh(force) {
        if (!root.enabled)
            return;
        if (force === true)
            root.fetchedAt = 0;
        root._resolve();
    }

    // The settings page and `rmpr ipc` both ask for this. No coordinates in
    // it beyond the ones the user set themselves: a location worked out from
    // an IP address is somebody's home, and this ends up in bug reports.
    function summary() {
        return {
            enabled: root.enabled,
            place: root.placeName,
            source: root.location?.source ?? "",
            units: root.units,
            fetchedAt: root.fetchedAt,
            condition: root.condition.label,
            temperature: root.temperatureText,
            error: root.error
        };
    }

    // ---- deciding where ----------------------------------------------------

    function _resolve() {
        const typed = Forecast.coordinates(root.wantedCoordinates);
        if (typed) {
            root._located(Object.assign({ name: root.wantedPlace || root.wantedCoordinates, source: "coordinates" }, typed));
            return;
        }
        if (root.wantedPlace.length > 0) {
            if (root.location?.source === "place" && root.location?.query === root.wantedPlace) {
                root._fetch();
                return;
            }
            search.command = ["curl", "-fsS", "--max-time", "10", Forecast.searchUrl(root.wantedPlace)];
            search.running = false;
            search.running = true;
            return;
        }
        if (root.location?.source === "ip") {
            root._fetch();
            return;
        }
        locate.running = false;
        locate.running = true;
    }

    function _located(where) {
        root.location = where;
        root._fetch();
    }

    // ---- fetching ----------------------------------------------------------

    function _fetch() {
        if (!root.location || root.busy)
            return;
        const age = Date.now() - root.fetchedAt;
        if (root.forecast && age < root.refreshMinutes * 60000)
            return;
        root.busy = true;
        fetch.command = ["curl", "-fsS", "--max-time", "15",
                         Forecast.forecastUrl(root.location.latitude, root.location.longitude, root.units)];
        fetch.running = false;
        fetch.running = true;
    }

    function _failed(what, code) {
        root.busy = false;
        root.error = `${what} failed (curl exit ${code})`;
        Log.warn("weather", root.error);
    }

    readonly property Process _locate: Process {
        id: locate
        // ipapi.co answers a bare GET with the caller's own city and
        // coordinates. Asked once, and only when nothing else says where we
        // are; the answer is cached like the forecast.
        command: ["curl", "-fsS", "--max-time", "10", "https://ipapi.co/json/"]
        stdout: StdioCollector {
            onStreamFinished: {
                let data = null;
                try {
                    data = JSON.parse(this.text);
                } catch (e) {
                    data = null;
                }
                if (!data || !Number.isFinite(Number(data.latitude))) {
                    root.error = "could not work out where this machine is; set a place in Settings -> Weather";
                    Log.warn("weather", root.error);
                    return;
                }
                root._located({
                    latitude: Number(data.latitude),
                    longitude: Number(data.longitude),
                    name: [data.city, data.country_name].filter(s => s).join(", "),
                    source: "ip"
                });
            }
        }
        onExited: code => { if (code !== 0) root._failed("locating this machine", code); }
    }

    readonly property Process _search: Process {
        id: search
        stdout: StdioCollector {
            onStreamFinished: {
                const found = Forecast.place(this.text);
                if (!found) {
                    root.error = `no place called "${root.wantedPlace}"`;
                    Log.warn("weather", root.error);
                    return;
                }
                root._located(Object.assign({ source: "place", query: root.wantedPlace }, found));
            }
        }
        onExited: code => { if (code !== 0) root._failed("looking up the place", code); }
    }

    readonly property Process _fetchProc: Process {
        id: fetch
        stdout: StdioCollector {
            onStreamFinished: {
                const parsed = Forecast.parse(this.text, Date.now());
                root.busy = false;
                if (!parsed) {
                    root.error = "the forecast could not be read";
                    Log.warn("weather", root.error);
                    return;
                }
                root.error = "";
                root.forecast = parsed;
                root.fetchedAt = Date.now();
                root._persist();
                Log.debug("weather", `${root.placeName}: ${root.condition.label}, ${root.temperatureText}`);
            }
        }
        onExited: code => { if (code !== 0) root._failed("fetching the forecast", code); }
    }

    // ---- when -------------------------------------------------------------

    readonly property Timer _timer: Timer {
        interval: root.refreshMinutes * 60000
        repeat: true
        running: root.enabled
        triggeredOnStart: true
        onTriggered: root._resolve()
    }

    // A setting changed: ask again now rather than at the next tick. The
    // location is dropped when what decides it changes, so a new place is not
    // answered with the old one's forecast.
    // Turned on in the settings window: ask now rather than at the timer's
    // next tick, which is half an hour of an empty card otherwise.
    onEnabledChanged: if (root.enabled) root.refresh(true)
    onWantedPlaceChanged: { root.location = null; root.refresh(true); }
    onWantedCoordinatesChanged: { root.location = null; root.refresh(true); }
    onUnitsChanged: root.refresh(true)

    // ---- the cache ---------------------------------------------------------

    function _persist() {
        Fs.ensureDir(Paths.stateDir);
        root._cache.setText(JSON.stringify({
            version: 1,
            fetchedAt: root.fetchedAt,
            units: root.units,
            location: root.location,
            forecast: root.forecast
        }, null, 4) + "\n");
    }

    readonly property FileView _cache: FileView {
        path: Paths.weatherCacheFile
        atomicWrites: true
        printErrors: false

        onSaveFailed: Fs.forget(Paths.stateDir)

        onLoaded: {
            try {
                const data = JSON.parse(text());
                // A cache in the other unit is not worth drawing: it would
                // show 21 next to °F for as long as the fetch takes.
                if (data?.units === root.units && data?.forecast) {
                    root.location = data.location ?? null;
                    root.forecast = data.forecast;
                    root.fetchedAt = Number(data.fetchedAt) || 0;
                }
            } catch (e) {
                Log.debug("weather", `cached forecast unreadable: ${e}`);
            }
        }
        onLoadFailed: { }   // nothing cached yet: the fetch fills it
    }
}

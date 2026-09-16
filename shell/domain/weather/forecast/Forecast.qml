pragma Singleton

// The weather, as arithmetic: what a WMO code means, and what one Open-Meteo
// answer contains. Pure, and a leaf module of its own so the tests can load it
// -- WeatherStatus beside it runs processes and would take the whole module
// with it (see scripts/lint-tests.sh).
//
// Open-Meteo answers with parallel arrays -- a `time` array and one array per
// measurement, aligned by index -- rather than a list of records. Turning that
// into records is most of what is here, and it is worth testing: an off-by-one
// between the two would put tomorrow's rain on today.
//
// The codes are the WMO 4677 present-weather table, which is what every
// forecast API in the world reports in. Only the values Open-Meteo actually
// sends are listed; anything else is drawn as "unknown" rather than guessed,
// because a wrong glyph is a confident lie about whether to take a coat.

import QtQuick

QtObject {
    id: root

    // code -> [label, day glyph, night glyph, freedesktop icon]. The glyphs
    // are Material Symbols names, as everywhere else in this shell; the icon
    // is the theme's, for a machine whose symbol font is missing.
    readonly property var codes: ({
        0:  ["Clear", "clear_day", "bedtime", "weather-clear"],
        1:  ["Mainly clear", "clear_day", "bedtime", "weather-few-clouds"],
        2:  ["Partly cloudy", "partly_cloudy_day", "partly_cloudy_night", "weather-few-clouds"],
        3:  ["Overcast", "cloud", "cloud", "weather-many-clouds"],
        45: ["Fog", "foggy", "foggy", "weather-fog"],
        48: ["Freezing fog", "foggy", "foggy", "weather-fog"],
        51: ["Light drizzle", "rainy_light", "rainy_light", "weather-showers-scattered"],
        53: ["Drizzle", "rainy_light", "rainy_light", "weather-showers-scattered"],
        55: ["Heavy drizzle", "rainy", "rainy", "weather-showers"],
        56: ["Freezing drizzle", "rainy", "rainy", "weather-freezing-rain"],
        57: ["Freezing drizzle", "rainy", "rainy", "weather-freezing-rain"],
        61: ["Light rain", "rainy_light", "rainy_light", "weather-showers-scattered"],
        63: ["Rain", "rainy", "rainy", "weather-showers"],
        65: ["Heavy rain", "rainy_heavy", "rainy_heavy", "weather-showers"],
        66: ["Freezing rain", "weather_mix", "weather_mix", "weather-freezing-rain"],
        67: ["Freezing rain", "weather_mix", "weather_mix", "weather-freezing-rain"],
        71: ["Light snow", "weather_snowy", "weather_snowy", "weather-snow-scattered"],
        73: ["Snow", "weather_snowy", "weather_snowy", "weather-snow"],
        75: ["Heavy snow", "snowing_heavy", "snowing_heavy", "weather-snow"],
        77: ["Snow grains", "weather_snowy", "weather_snowy", "weather-snow"],
        80: ["Showers", "rainy", "rainy", "weather-showers"],
        81: ["Showers", "rainy", "rainy", "weather-showers"],
        82: ["Heavy showers", "rainy_heavy", "rainy_heavy", "weather-showers"],
        85: ["Snow showers", "weather_snowy", "weather_snowy", "weather-snow"],
        86: ["Snow showers", "snowing_heavy", "snowing_heavy", "weather-snow"],
        95: ["Thunderstorm", "thunderstorm", "thunderstorm", "weather-storm"],
        96: ["Thunderstorm with hail", "thunderstorm", "thunderstorm", "weather-storm"],
        99: ["Thunderstorm with hail", "thunderstorm", "thunderstorm", "weather-storm"]
    })

    // { label, glyph, icon } for a code, by day or by night.
    function describe(code, isDay) {
        const row = root.codes[Number(code)];
        if (!row)
            return { label: "Unknown", glyph: "help", icon: "weather-none-available" };
        return { label: row[0], glyph: (isDay === false ? row[2] : row[1]), icon: row[3] };
    }

    // ---- what to ask for --------------------------------------------------

    readonly property var fields: ({
        current: ["temperature_2m", "apparent_temperature", "relative_humidity_2m",
                  "is_day", "weather_code", "wind_speed_10m", "precipitation"],
        hourly: ["temperature_2m", "weather_code", "precipitation_probability"],
        daily: ["weather_code", "temperature_2m_max", "temperature_2m_min",
                "precipitation_probability_max", "sunrise", "sunset"]
    })

    // The forecast URL for one place. Units are Open-Meteo's own names, so
    // nothing here converts a temperature: the answer arrives in what was
    // asked for, and the unit symbol comes back with it.
    function forecastUrl(latitude, longitude, units) {
        const imperial = String(units) === "imperial";
        const params = [
            `latitude=${Number(latitude).toFixed(4)}`,
            `longitude=${Number(longitude).toFixed(4)}`,
            `current=${root.fields.current.join(",")}`,
            `hourly=${root.fields.hourly.join(",")}`,
            `daily=${root.fields.daily.join(",")}`,
            "forecast_days=6",
            "timezone=auto",
            `temperature_unit=${imperial ? "fahrenheit" : "celsius"}`,
            `wind_speed_unit=${imperial ? "mph" : "kmh"}`,
            `precipitation_unit=${imperial ? "inch" : "mm"}`
        ];
        return `https://api.open-meteo.com/v1/forecast?${params.join("&")}`;
    }

    // Looking a place up by name, which is the alternative to an IP guess.
    function searchUrl(place) {
        return `https://geocoding-api.open-meteo.com/v1/search?name=${encodeURIComponent(String(place ?? "").trim())}&count=1&language=en&format=json`;
    }

    // "46.77, 23.60" -> { latitude, longitude }, or null. Accepts a comma or a
    // space between them, and refuses anything off the globe -- a typo must
    // not become a forecast for the middle of the sea.
    function coordinates(text) {
        const parts = String(text ?? "").trim().split(/[,\s]+/).filter(p => p.length > 0);
        if (parts.length !== 2)
            return null;
        const lat = Number(parts[0]);
        const lon = Number(parts[1]);
        if (!Number.isFinite(lat) || !Number.isFinite(lon))
            return null;
        if (Math.abs(lat) > 90 || Math.abs(lon) > 180)
            return null;
        return { latitude: lat, longitude: lon };
    }

    // ---- what came back ---------------------------------------------------

    // The first result of a geocoding search: { latitude, longitude, name },
    // or null when the place is not a place.
    function place(text) {
        let data;
        try {
            data = JSON.parse(String(text ?? ""));
        } catch (e) {
            return null;
        }
        const first = (data?.results ?? [])[0];
        if (!first || !Number.isFinite(Number(first.latitude)))
            return null;
        return {
            latitude: Number(first.latitude),
            longitude: Number(first.longitude),
            name: [first.name, first.admin1, first.country].filter(s => s).join(", ")
        };
    }

    // A whole forecast, or null. Records out of parallel arrays: `time` is the
    // spine, and every other array is read at the same index.
    //
    // `from` drops the hours already past, so "the next twelve hours" means
    // that rather than "the twelve hours this day started with".
    function parse(text, from) {
        let data;
        try {
            data = JSON.parse(String(text ?? ""));
        } catch (e) {
            return null;
        }
        const current = data?.current;
        if (!current || !Number.isFinite(Number(current.temperature_2m)))
            return null;

        const units = data.current_units ?? {};
        const now = Number.isFinite(Number(from)) ? Number(from) : Date.now();

        return {
            temperatureUnit: String(units.temperature_2m ?? "°C"),
            windUnit: String(data.hourly_units?.wind_speed_10m ?? units.wind_speed_10m ?? "km/h"),
            current: {
                temperature: Number(current.temperature_2m),
                feelsLike: Number(current.apparent_temperature),
                humidity: Number(current.relative_humidity_2m),
                wind: Number(current.wind_speed_10m),
                precipitation: Number(current.precipitation),
                code: Number(current.weather_code),
                isDay: Number(current.is_day) !== 0,
                when: root._time(current.time)
            },
            hours: root._hours(data.hourly, now),
            days: root._days(data.daily)
        };
    }

    // Open-Meteo stamps its times in the place's own zone with no offset
    // ("2026-09-16T18:00"), which Date parses as local time -- which is what
    // is wanted for a forecast read on the machine it is about.
    function _time(stamp) {
        const t = Date.parse(String(stamp ?? ""));
        return Number.isFinite(t) ? t : 0;
    }

    function _hours(hourly, now) {
        const times = hourly?.time ?? [];
        const out = [];
        for (let i = 0; i < times.length; i++) {
            const at = root._time(times[i]);
            // An hour is still "now" until it is over.
            if (at + 3600000 <= now)
                continue;
            out.push({
                when: at,
                temperature: Number((hourly.temperature_2m ?? [])[i]),
                code: Number((hourly.weather_code ?? [])[i]),
                rain: Number((hourly.precipitation_probability ?? [])[i] ?? 0),
                // Between sunrise and sunset would need the day's own pair;
                // the clock is close enough for an icon, and never wrong by
                // more than an hour or so.
                isDay: new Date(at).getHours() >= 7 && new Date(at).getHours() < 20
            });
            if (out.length >= 24)
                break;
        }
        return out;
    }

    function _days(daily) {
        const times = daily?.time ?? [];
        const out = [];
        for (let i = 0; i < times.length; i++) {
            out.push({
                when: root._time(times[i]),
                code: Number((daily.weather_code ?? [])[i]),
                high: Number((daily.temperature_2m_max ?? [])[i]),
                low: Number((daily.temperature_2m_min ?? [])[i]),
                rain: Number((daily.precipitation_probability_max ?? [])[i] ?? 0),
                sunrise: root._time((daily.sunrise ?? [])[i]),
                sunset: root._time((daily.sunset ?? [])[i])
            });
        }
        return out;
    }

    // ---- how it reads -----------------------------------------------------

    // A temperature as a person writes it: no decimal, and the degree sign
    // kept next to the number.
    function degrees(value, unit) {
        return Number.isFinite(Number(value)) ? `${Math.round(Number(value))}${unit ?? "°"}` : "--";
    }

    // The day of a forecast, "Today" for the one that is.
    function dayName(when, now, locale) {
        const day = new Date(Number(when));
        const today = new Date(Number(now));
        if (day.getFullYear() === today.getFullYear() && day.getMonth() === today.getMonth()
            && day.getDate() === today.getDate())
            return "Today";
        return day.toLocaleDateString(locale ?? Qt.locale(), "ddd");
    }

    // The forecast for one date out of the days list, or null: what the
    // calendar asks for when a day is chosen.
    function dayAt(days, when) {
        const wanted = new Date(Number(when));
        return (days ?? []).find(d => {
            const day = new Date(d.when);
            return day.getFullYear() === wanted.getFullYear() && day.getMonth() === wanted.getMonth()
                && day.getDate() === wanted.getDate();
        }) ?? null;
    }
}

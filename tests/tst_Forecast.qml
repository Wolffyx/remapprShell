import QtQuick
import QtTest
import qs.domain.weather.forecast

TestCase {
    name: "Forecast"

    // One Open-Meteo answer, cut down to the shape the real one has: parallel
    // arrays with `time` as the spine, and units carried beside the values.
    readonly property string answer: JSON.stringify({
        current_units: { temperature_2m: "°C", wind_speed_10m: "km/h" },
        current: { time: "2026-09-16T18:00", temperature_2m: 21.4, apparent_temperature: 20.6,
                   relative_humidity_2m: 54, is_day: 1, weather_code: 3, wind_speed_10m: 9.2,
                   precipitation: 0 },
        hourly: { time: ["2026-09-16T17:00", "2026-09-16T18:00", "2026-09-16T19:00"],
                  temperature_2m: [22.8, 21.4, 19.9], weather_code: [2, 3, 61],
                  precipitation_probability: [0, 10, 45] },
        daily: { time: ["2026-09-16", "2026-09-17"], weather_code: [3, 61],
                 temperature_2m_max: [23.1, 19.4], temperature_2m_min: [11.2, 10.8],
                 precipitation_probability_max: [10, 80],
                 sunrise: ["2026-09-16T07:02"], sunset: ["2026-09-16T19:41"] }
    })

    function test_a_code_is_a_picture_and_a_sentence() {
        compare(Forecast.describe(0, true).label, "Clear");
        compare(Forecast.describe(0, true).glyph, "clear_day");
        // The same weather at night is a different picture.
        verify(Forecast.describe(0, false).glyph !== Forecast.describe(0, true).glyph);
        compare(Forecast.describe(95, true).label, "Thunderstorm");
        // A code nobody knows is said to be unknown rather than guessed at.
        compare(Forecast.describe(4242, true).label, "Unknown");
    }

    function test_coordinates_are_refused_unless_they_are_on_the_globe() {
        compare(Forecast.coordinates("46.77, 23.60"), { latitude: 46.77, longitude: 23.60 });
        compare(Forecast.coordinates("46.77 23.60").latitude, 46.77);
        compare(Forecast.coordinates("91, 0"), null);
        compare(Forecast.coordinates("46.77"), null);
        compare(Forecast.coordinates("here, there"), null);
        compare(Forecast.coordinates(""), null);
    }

    function test_the_url_asks_for_what_was_chosen() {
        const metric = Forecast.forecastUrl(46.77, 23.6, "metric");
        verify(metric.indexOf("temperature_unit=celsius") > 0);
        verify(metric.indexOf("latitude=46.7700") > 0);
        verify(Forecast.forecastUrl(46.77, 23.6, "imperial").indexOf("temperature_unit=fahrenheit") > 0);
        verify(Forecast.searchUrl("Cluj-Napoca").indexOf("name=Cluj-Napoca") > 0);
    }

    function test_records_come_out_of_parallel_arrays() {
        const at = Date.parse("2026-09-16T18:10");
        const f = Forecast.parse(answer, at);
        compare(f.current.temperature, 21.4);
        compare(f.current.isDay, true);
        compare(f.temperatureUnit, "°C");

        // The hour already over is dropped; the one in progress is kept, and
        // every value lines up with its own time.
        compare(f.hours.length, 2);
        compare(f.hours[0].temperature, 21.4);
        compare(f.hours[1].temperature, 19.9);
        compare(f.hours[1].rain, 45);

        compare(f.days.length, 2);
        compare(f.days[1].high, 19.4);
        compare(f.days[1].low, 10.8);
        compare(f.days[1].rain, 80);
    }

    function test_an_answer_that_is_not_one_is_null() {
        compare(Forecast.parse("<html>502 Bad Gateway</html>", 0), null);
        compare(Forecast.parse(JSON.stringify({ error: true, reason: "no" }), 0), null);
        compare(Forecast.parse("", 0), null);
        compare(Forecast.place("nonsense"), null);
        compare(Forecast.place(JSON.stringify({ results: [] })), null);
        compare(Forecast.place(JSON.stringify({ results: [{ name: "Cluj-Napoca", latitude: 46.77, longitude: 23.6, country: "Romania" }] })).latitude, 46.77);
    }

    function test_how_it_reads() {
        compare(Forecast.degrees(21.4, "°C"), "21°C");
        compare(Forecast.degrees(undefined, "°C"), "--");
        const today = Date.parse("2026-09-16T09:00");
        compare(Forecast.dayName(Date.parse("2026-09-16T00:00"), today), "Today");
        verify(Forecast.dayName(Date.parse("2026-09-17T00:00"), today) !== "Today");

        const f = Forecast.parse(answer, Date.parse("2026-09-16T18:10"));
        compare(Forecast.dayAt(f.days, Date.parse("2026-09-17T15:00")).high, 19.4);
        compare(Forecast.dayAt(f.days, Date.parse("2026-10-01T15:00")), null);
    }
}

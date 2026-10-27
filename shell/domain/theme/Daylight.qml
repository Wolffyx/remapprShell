pragma Singleton

// Whether the sun is up, as `theme daylight` answers it.
//
// KDE first: Plasma's night time schedule, which KWin's Night Light warms the
// screen on and Plasma's own dark-at-night switch follows -- so the shell
// turns when the rest of the desktop does. Ours only when KDE has no answer
// to give: KNightTime uninstalled or not running, Night Light off on a Plasma
// without it, or KNightTime sitting on its 18:00/06:00 fallback because
// GeoClue was too slow for it at login and it never asked again. Then the
// answer is the sun itself, at the place GeoClue gives -- or gave last time,
// or the coordinates typed in for the weather.
//
// The chain is the CLI's (scripts/lib/daylight.py), not repeated here: the
// login unit asks the same command before any application starts, and two
// copies of it would be two opinions about when night is.
//
// `theme.daylight.source` set to "shell" skips KDE and always uses ours.

import QtQuick
import qs.core
import qs.platform.kde
import qs.platform.system
import qs.domain.config

QtObject {
    id: root

    // The command's answer: { known, daylight, source, location, next, why }.
    // Empty until it first answers; a run that fails leaves the last one.
    property var answer: ({})

    readonly property bool known: root.answer.known === true
    readonly property bool daylight: root.answer.daylight === true

    // "kde" or "shell": who said so.
    readonly property string source: root.answer.source ?? ""

    // When the answer changes, in ms since the epoch; 0 when nothing says.
    readonly property real next: Number(root.answer.next) || 0

    onKnownChanged: Log.info("theme", root.known
        ? `daylight: ${root.daylight ? "day" : "night"} (${root.answer.why})`
        : `daylight: nobody knows (${root.answer.why ?? "no answer yet"})`)

    onDaylightChanged: if (root.known)
        Log.info("theme", `daylight: ${root.daylight ? "day" : "night"} (${root.answer.why})`)

    function refresh(): void {
        if (!ask.running)
            ask.run(["theme", "daylight", "--json"]);
    }

    readonly property CtlRun _ask: CtlRun {
        id: ask
        tag: "theme"
        label: "theme daylight"
        onFinished: (code, stdout) => {
            try {
                const parsed = JSON.parse(stdout);
                if (parsed && typeof parsed.known === "boolean")
                    root.answer = parsed;
            } catch (e) {
                Log.warn("theme", `daylight: unreadable answer: ${e}`);
            }
        }
    }

    // The moment it changes, asked again rather than flipped here: KDE may
    // have moved its schedule since, and the command says by how much.
    readonly property Timer _atChange: Timer {
        interval: Math.max(1000, root.next - Date.now() + 2000)
        running: root.next > 0
        onTriggered: root.refresh()
    }

    // A clock that jumped -- a suspend over sunset, a time zone -- and a
    // GeoClue that answers later than login are both caught by asking again.
    readonly property Timer _poll: Timer {
        interval: 5 * 60 * 1000
        running: true
        repeat: true
        onTriggered: root.refresh()
    }

    // KDE moving its schedule shows on Night Light first: its day flips, or
    // its next transition moves when KNightTime finds the place it lost. Not
    // every property change -- the temperature ticks through a transition.
    readonly property string _kdeSchedule:
        `${NightLight.props.daylight}/${NightLight.props.scheduledTransitionDateTime}`
    on_KdeScheduleChanged: root.refresh()

    readonly property string _settings:
        `${ConfigStore.value("theme.daylight.source", "kde")}/${ConfigStore.value("weather.coordinates", "")}`
    on_SettingsChanged: root.refresh()

    Component.onCompleted: root.refresh()
}

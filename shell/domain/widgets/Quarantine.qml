pragma Singleton

// Keeps a third-party widget that kills the shell from killing it again on
// every restart.
//
// A Loader contains a widget that *throws*. It does nothing for one that hangs
// the render thread or crashes the process -- and that widget would take the
// shell down again immediately on restart, forever, with no way in through the
// settings UI to disable it.
//
// So an attempt is written to disk BEFORE the widget loads, and cleared once
// the shell has stayed up for a while. A widget still marked "attempting" at
// startup was in flight when the previous session died.
//
// Two deliberate limits on that, both learned by getting it wrong:
//
//   - Only third-party widgets are tracked. A built-in that kills the shell is
//     our bug; quarantining it would hide the bug while silently breaking the
//     user's panel.
//   - "It worked" means the shell survived `settleDelay`, not that a load
//     callback fired. Tying it to panel construction quarantined innocent
//     widgets whenever the shell was stopped early -- a logout, a restart, or
//     any unrelated crash looked exactly like a widget taking the shell down.
//   - An in-flight mark only counts as evidence if the previous session died
//     during early boot. A widget that kills the shell does so within seconds;
//     a session that ran for a minute and then stopped was ended by something
//     else. Without this a user who logged out three times in quick succession
//     would have every third-party widget disabled, with a message blaming
//     widgets that did nothing wrong.

import QtQuick
import Quickshell.Io
import qs.core
import qs.platform.system

QtObject {
    id: root

    // How many failed starts before a widget is disabled outright.
    readonly property int maxAttempts: 3

    // id -> { attempts, lastError, inFlight }
    property var health: ({})

    // Populated once at startup from the previous session's leftovers.
    property var quarantined: ({})

    property bool loaded: false

    function isQuarantined(id) {
        return !!root.quarantined[id];
    }

    function reasonFor(id) {
        return root.quarantined[id]?.reason ?? "";
    }

    // Called before a widget is instantiated.
    //
    // Idempotent within a session: one widget is instantiated once per screen,
    // and counting each instance would make the threshold depend on how many
    // monitors are attached -- on a three-monitor setup a single bad session
    // would exhaust it immediately. An attempt means "this session tried to
    // load it", so the in-flight mark doubles as the guard.
    function beginAttempt(id) {
        if (!root.loaded)
            return;
        const entry = root.health[id] ?? { attempts: 0, lastError: "" };
        if (entry.inFlight)
            return;
        entry.inFlight = true;
        entry.attempts = (entry.attempts ?? 0) + 1;
        root.health = Object.assign({}, root.health, { [id]: entry });
        root._persist();
    }

    // How long the shell must stay up before the widgets loaded into it are
    // considered good. Long enough that a widget which brings the shell down
    // will not reach it; short enough that a real session always does.
    // Overridable so the behaviour can be tested without waiting out a real
    // settle window.
    readonly property int settleDelay: Env.int(`${Branding.envPrefix}_SETTLE_MS`, 20000)

    // A shell taken down by a widget dies within a few seconds of starting.
    // Surviving this long means the stop, whenever it came, was not the doing
    // of anything loaded at boot.
    readonly property int bootGrace: Env.int(`${Branding.envPrefix}_BOOT_GRACE_MS`, 5000)

    // True from startup until bootGrace elapses. Persisted, so the next session
    // can see whether the previous one got past it.
    property bool booting: true

    readonly property Timer _bootTimer: Timer {
        interval: root.bootGrace
        repeat: false
        onTriggered: {
            root.booting = false;
            root._persist();
            Log.debug("quarantine", "past boot grace");
        }
    }

    readonly property Timer _settleTimer: Timer {
        interval: root.settleDelay
        repeat: false
        onTriggered: root.commitStartup()
    }

    // Clearing the in-flight marks -- and the attempt counts with them -- is
    // what stops a transient failure accumulating towards a permanent
    // quarantine across unrelated restarts.
    function commitStartup() {
        let changed = false;
        const next = {};
        for (const id of Object.keys(root.health)) {
            if (root.health[id].inFlight) {
                changed = true;
                continue; // healthy now: forget the attempt entirely
            }
            next[id] = root.health[id];
        }
        if (changed) {
            root.health = next;
            root._persist();
            Log.debug("quarantine", "shell settled; in-flight marks cleared");
        }
    }

    function recordFailure(id, error) {
        const entry = root.health[id] ?? { attempts: 1 };
        entry.lastError = String(error);
        root.health = Object.assign({}, root.health, { [id]: entry });

        if ((entry.attempts ?? 0) >= root.maxAttempts)
            root._quarantine(id, `failed to load ${entry.attempts} times: ${entry.lastError}`);

        root._persist();
    }

    // Lets the user undo a quarantine from settings without editing JSON.
    function release(id) {
        const q = Object.assign({}, root.quarantined);
        delete q[id];
        root.quarantined = q;

        const h = Object.assign({}, root.health);
        delete h[id];
        root.health = h;

        root._persist();
        Log.info("quarantine", `released '${id}'`);
    }

    function _quarantine(id, reason) {
        root.quarantined = Object.assign({}, root.quarantined, {
            [id]: { reason: reason, at: new Date().toISOString() }
        });
        Log.warn("quarantine", `'${id}' quarantined: ${reason}`);

        // The same reporter the systemd unit's OnFailure= runs. One report
        // format and one code path, whether the shell died or merely gave up
        // on a widget -- and it is written here, at the point a widget is
        // actually disabled, rather than on every failed attempt.
        root._report.running = false;
        root._report.command = [Branding.ctlBin, "report", "create",
                                "--reason", `widget '${id}' quarantined: ${reason}`];
        root._report.running = true;
    }

    // Nothing is sent anywhere: the report is a directory of text files under
    // the state directory, and every consumer of one is separately opt-in.
    // The reporter's own progress lines come back on stderr. They are logged
    // rather than dropped: a report that failed to be written is worth knowing
    // about precisely when something has already gone wrong. Read through a
    // collector rather than the `exited` signal, whose exit-status parameter
    // the linter cannot resolve -- and note that a comment line starting with
    // the linter's own name is parsed as a directive, so it cannot be named
    // at the start of one.
    readonly property Process _report: Process {
        stderr: StdioCollector {
            onStreamFinished: {
                const last = text.trim().split("\n").pop();
                if (last.length > 0)
                    Log.debug("quarantine", `report: ${last}`);
            }
        }
    }

    function _persist() {
        Fs.ensureDir(Paths.stateDir);
        root._view.setText(JSON.stringify({
            booting: root.booting,
            health: root.health,
            quarantined: root.quarantined
        }, null, 4) + "\n");
    }

    readonly property FileView _view: FileView {
        path: Paths.widgetHealthFile
        atomicWrites: true
        printErrors: false

        onLoaded: {
            try {
                const data = JSON.parse(text());
                root.quarantined = data.quarantined ?? {};

                // Anything still marked in-flight was loading when the previous
                // session died. That is the signature of a widget that took the
                // shell down rather than merely throwing.
                //
                // The mark is then cleared: it has served its purpose for the
                // previous session, and this session needs to set it afresh.
                // Leaving it set would make beginAttempt's per-session guard
                // suppress every later attempt, freezing the counter at one.
                const health = data.health ?? {};

                // Only a session that never got past boot grace is evidence of
                // a widget bringing the shell down. Anything else -- a logout,
                // a reboot, an unrelated crash an hour in -- clears the marks
                // without counting them.
                const diedDuringBoot = data.booting === true;

                for (const id of Object.keys(health)) {
                    if (!health[id].inFlight)
                        continue;

                    if (diedDuringBoot) {
                        if ((health[id].attempts ?? 0) >= root.maxAttempts)
                            root._quarantine(id, `the shell died while loading '${id}', ${health[id].attempts} time(s) in a row`);
                        else
                            Log.warn("quarantine", `'${id}' was loading when the shell died during startup (${health[id].attempts ?? 0}/${root.maxAttempts})`);
                    } else {
                        // The shell ran fine and was stopped later; this widget
                        // is not implicated, so the attempt does not count.
                        health[id].attempts = 0;
                    }

                    health[id].inFlight = false;
                }
                root.health = health;
            } catch (e) {
                Log.warn("quarantine", `health file unreadable, starting fresh: ${e}`);
                root.health = ({});
                root.quarantined = ({});
            }
            root.loaded = true;
            root.booting = true;
            root._bootTimer.restart();
            root._settleTimer.restart();
            root._persist();
        }

        onLoadFailed: {
            // No health file yet is the normal first-run case.
            root.health = ({});
            root.quarantined = ({});
            root.loaded = true;
            root.booting = true;
            root._bootTimer.restart();
            root._settleTimer.restart();
        }
    }
}

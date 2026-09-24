pragma Singleton

// Every application the shell starts is started here, in a systemd scope of
// its own -- never as the shell's child.
//
// On 2026-09-24 a restart of the shell took the user's game with it -- World
// of Tanks under Proton, its winedevice.exe killed outright -- and Steam
// beside it. Whatever was started from the start menu, the taskbar or a
// notification was a child of the shell, and so a process of the shell's
// systemd service, which ends every process in it when the shell stops,
// crashes or restarts. Plasma starts each application in a unit of its own in
// app.slice, and so does this now. `systemd-run --scope` makes the unit and
// then becomes the application, so it runs with the environment and in the
// directory it always had; only its cgroup is different. AppScope has the
// naming and why.
//
// Detached, always. A Process would hold the application as its child, and a
// Process ends its child when it goes -- the same death by another route. The
// two launchers that have to keep hold of what they start, to replace it on
// the next press, ask scoped() for the command line and run it themselves.
//
// Where no scope can be made -- no systemd-run, or no systemd user manager to
// ask, as for a shell started by hand outside a systemd session --
// applications start as they used to, the shell's own children. That is
// decided once, the first time anything is started, by trying: systemd-run
// runs `true` in a scope, and whatever was asked for meanwhile waits the
// moment that takes. The answer is logged once.
//
// Not everything the shell runs is an application. Its own CLI, busctl, a
// mkdir, notify-send are the shell's work and end with it by rights, and
// PlasmaServices hosts Plasma's applets as a service the shell owns.
// scripts/lint-launch.sh keeps the application-shaped calls coming here.

import QtQuick
import Quickshell
import Quickshell.Io
import qs.core

QtObject {
    id: root

    // A desktop entry, run as its execute() ran it: the command Quickshell
    // parsed from Exec, field codes dropped, in the entry's working
    // directory. Like execute(), it does not open a terminal for an entry
    // that asks for one.
    function entry(desktopEntry) {
        if (!desktopEntry)
            return;
        root._detached(desktopEntry.command, String(desktopEntry.id ?? ""), desktopEntry.workingDirectory);
    }

    // One of an entry's own actions -- "New Incognito Window" -- in the
    // entry's working directory, which is where DesktopAction.execute() ran
    // it. The action cannot name its entry, so the caller does; the scope is
    // named after it.
    function action(desktopAction, desktopEntry) {
        if (!desktopAction)
            return;
        root._detached(desktopAction.command, String(desktopEntry?.id ?? ""), desktopEntry?.workingDirectory ?? "");
    }

    // A program that is not a desktop entry: `systemsettings kcm_kscreen`, a
    // command line from the panel menu. `appId` names the scope -- a desktop
    // entry id where there is one -- and is the program's own name when left
    // out.
    function command(argv, appId) {
        root._detached(argv, appId, "");
    }

    // A file, a folder or a link, opened with whatever the desktop opens it
    // with. xdg-open starts that application as its own child, so it is in a
    // scope for the same reason as everything else here.
    function open(uri) {
        const target = String(uri ?? "");
        if (target.length === 0)
            return;
        root._detached(["xdg-open", target], "xdg-open", "");
    }

    // For a launcher that runs what it starts through a Process of its own,
    // so that the next press can stop it and start it again: `use` is called
    // with the command line to put on the Process -- inside a scope when
    // scopes can be made -- as soon as that is known.
    function scoped(argv, appId, use) {
        const command = root._list(argv);
        if (command.length === 0)
            return;
        root._whenKnown(() => use(root._wrap(command, appId)));
    }

    // Null until the first try has answered; then whether scopes can be
    // made here.
    property var _scoped: null

    // What was asked for before that answer, run once it comes. Nothing
    // binds to it, so it is changed in place.
    property var _waiting: []

    function _detached(argv, appId, workingDirectory) {
        const command = root._list(argv);
        if (command.length === 0)
            return;
        const dir = String(workingDirectory ?? "");
        root._whenKnown(() => {
            const run = root._wrap(command, appId);
            Quickshell.execDetached(dir.length > 0 ? { command: run, workingDirectory: dir } : { command: run });
            Log.debug("launch", run.join(" "));
        });
    }

    function _wrap(command, appId) {
        if (!root._scoped)
            return command;
        const id = String(appId ?? "") || AppScope.idOf(command);
        return AppScope.wrap(command, AppScope.unitName(Branding.slug, id, root._random()));
    }

    function _whenKnown(fn) {
        if (root._scoped !== null) {
            fn();
            return;
        }
        root._waiting.push(fn);
        if (!probe.running)
            probe.running = true;
    }

    function _decided(scoped) {
        root._scoped = scoped;
        if (scoped)
            Log.info("launch", "applications start in scopes of their own, in app.slice");
        else
            Log.warn("launch", "no scope could be made here (no systemd-run, or no systemd user manager); applications start as the shell's own children, and a restart of the shell ends them");
        const waiting = root._waiting;
        root._waiting = [];
        for (const fn of waiting)
            fn();
    }

    // Sixteen hex digits: the part of the name that tells two scopes of the
    // same application apart. Not a secret, so Math.random is enough.
    function _random() {
        let s = "";
        for (let i = 0; i < 16; i++)
            s += Math.floor(Math.random() * 16).toString(16);
        return s;
    }

    // A desktop entry's command is a list type of Qt's, not a JS array.
    function _list(a) {
        const out = [];
        for (let i = 0; i < (a?.length ?? 0); i++)
            out.push(String(a[i]));
        return out;
    }

    // The try: the same command line an application gets, running `true`.
    // It fails the same way an application would -- systemd-run missing, no
    // manager to ask, a manager that will not take this process -- and says
    // so by printing nothing.
    readonly property Process _probe: Process {
        id: probe
        command: ["sh", "-c", '"$@" >/dev/null 2>&1 && echo yes', "sh"]
            .concat(AppScope.wrap(["true"], AppScope.unitName(Branding.slug, "true", root._random())))
        stdout: StdioCollector {
            onStreamFinished: root._decided(this.text.trim() === "yes")
        }
    }
}

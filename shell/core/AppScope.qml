pragma Singleton

// The name and the command line of a systemd scope of an application's own,
// which is what every application the shell starts is run inside
// (platform/system/Launch.qml). Worked out here, pure, where the tests can
// load it.
//
// Why a scope at all. An application started from the shell used to be the
// shell's child, and so a process of the shell's systemd service -- and a
// service that stops, crashes or restarts takes every process in its cgroup
// with it. On 2026-09-24 a restart of the shell took the user's game (World
// of Tanks, under Proton) and Steam with it. In a scope of its own, in
// app.slice where Plasma puts the applications it starts, an application is
// a unit of its own, and the shell and what it started no longer share a
// fate.
//
// The name is the one systemd asks desktops to give the applications they
// start (systemd.io/DESKTOP_ENVIRONMENTS):
//
//     app-<launcher>-<ApplicationID>-<RANDOM>.scope
//
// the launcher being this shell's slug and the application id its desktop
// entry id, each escaped as `systemd-escape` escapes a string -- so a `-`
// inside either is \x2d, and the dashes left are the separators. That is what
// lets whatever reads the list (systemd-cgls, a task manager, Plasma) tell
// which application a scope holds and who started it.

import QtQuick

QtObject {
    id: root

    // A unit name longer than this is refused outright, and the application
    // then never starts -- saying so only on systemd-run's stderr, which
    // nobody reads. So an application id too long to fit is shortened.
    readonly property int nameMax: 255

    // What `systemd-escape <s>` prints: every byte that may not be in a unit
    // name, and `-` and `\` besides, as \xNN in lower-case hex, the UTF-8
    // bytes of a character one by one; `/` as `-`; and a leading `.` escaped
    // too, as systemd never makes a unit name that starts with one.
    function escaped(s) {
        const bytes = root._utf8(String(s ?? ""));
        let out = "";
        for (let i = 0; i < bytes.length; i++) {
            const b = bytes[i];
            const c = String.fromCharCode(b);
            if (b === 0x2f)
                out += "-";
            else if ((i === 0 && b === 0x2e) || b >= 0x80 || !/[A-Za-z0-9:_.]/.test(c))
                out += "\\x" + b.toString(16).padStart(2, "0");
            else
                out += c;
        }
        return out;
    }

    // app-<launcher>-<appId>-<random>.scope, with the launcher and the
    // application id escaped. `random` goes in as it is: it is the caller's,
    // and made of characters that need no escaping.
    function unitName(launcher, appId, random) {
        const head = `app-${root.escaped(launcher)}-`;
        const tail = `-${String(random ?? "")}.scope`;
        let id = root.escaped(appId);
        const room = root.nameMax - head.length - tail.length;
        if (id.length > room && room > 0) {
            id = id.slice(0, room);
            // Not through the middle of an escape: a cut `\x2` is not a
            // shorter name, it is an invalid one.
            const cut = id.lastIndexOf("\\");
            if (cut >= 0 && cut > id.length - 4)
                id = id.slice(0, cut);
        }
        return head + id + tail;
    }

    // The application id of a command that comes with none: the file name
    // of the program it runs -- "fuzzel" for ["/usr/bin/fuzzel", "--prompt"].
    function idOf(argv) {
        const first = String((argv ?? [])[0] ?? "");
        return first.split("/").pop();
    }

    // The command line that runs `argv` inside the scope named `unit`.
    //
    // --scope, not a service: systemd-run makes the scope, moves itself into
    // it and then becomes the program, which keeps the environment and the
    // working directory of whoever ran it -- a service would get the user
    // manager's instead. --collect, so a scope whose program failed is not
    // left behind as a failed unit. --quiet, so its "Running as unit" line is
    // not in the journal once per click.
    function wrap(argv, unit) {
        return ["systemd-run", "--user", "--scope", "--slice=app.slice", "--collect", "--quiet",
                `--unit=${unit}`, "--"].concat((argv ?? []).map(a => String(a)));
    }

    // A string as its UTF-8 bytes, which is what systemd-escape escapes.
    function _utf8(s) {
        const bytes = [];
        for (const ch of s) {
            const cp = ch.codePointAt(0);
            if (cp < 0x80)
                bytes.push(cp);
            else if (cp < 0x800)
                bytes.push(0xc0 | (cp >> 6), 0x80 | (cp & 0x3f));
            else if (cp < 0x10000)
                bytes.push(0xe0 | (cp >> 12), 0x80 | ((cp >> 6) & 0x3f), 0x80 | (cp & 0x3f));
            else
                bytes.push(0xf0 | (cp >> 18), 0x80 | ((cp >> 12) & 0x3f), 0x80 | ((cp >> 6) & 0x3f), 0x80 | (cp & 0x3f));
        }
        return bytes;
    }
}

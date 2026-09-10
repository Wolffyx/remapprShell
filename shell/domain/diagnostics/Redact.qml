pragma Singleton

// The privacy boundary, as a pure function.
//
// Everything a diagnostic report contains passes through here, and a report is
// the one thing in this project a person might paste into a chat window or hand
// to a model. So this is tested rather than trusted: tests/tst_Redact.qml runs
// it over tests/fixtures/redact-cases.json, and tests/test-redact.sh runs the
// shell implementation over the same file. Two implementations exist because
// the crash reporter has to work when the shell is dead; one fixture corpus is
// what stops them drifting.
//
// Three rules, in this order, and the order matters:
//
//   1. An object entry whose KEY looks like a secret loses its whole value,
//      whatever the value's type. A key named `auth` holding an object is the
//      case that a value-only scrub would leak entirely.
//   2. The home directory becomes `~`. Before the username, because the home
//      path contains it and replacing the username first would leave
//      `/home/<user>/...` behind rather than `~/...`.
//   3. The username becomes `<user>`, anywhere it appears -- window titles and
//      file paths included, which is where it actually shows up.
//
// The key pattern deliberately over-reaches: `key` matches `keyboardLayout` as
// well as `api_key`, so a keyboard layout is masked too. That is the correct
// direction to fail in. A report that withholds something harmless costs a
// question; one that leaks a token cannot be taken back.

import QtQuick

QtObject {
    id: root

    readonly property var secretKey: /token|key|password|secret|auth/i
    readonly property string mask: "<redacted>"
    readonly property string userMask: "<user>"

    // Set by whatever builds a report. Defaults are empty so that a missing
    // value redacts nothing rather than replacing every empty string.
    property string home: ""
    property string user: ""

    function isSecret(key) {
        return root.secretKey.test(String(key ?? ""));
    }

    // Plain substring replacement, not a word-boundary match: a username is
    // just as identifying in the middle of a path as it is on its own.
    function _replaceAll(text, needle, replacement) {
        if (!needle)
            return text;
        return text.split(needle).join(replacement);
    }

    function text(value) {
        let out = String(value);
        out = root._replaceAll(out, root.home, "~");
        out = root._replaceAll(out, root.user, root.userMask);
        return out;
    }

    // Recurses objects and arrays; leaves numbers, booleans and null alone.
    function value(input) {
        if (input === null || input === undefined)
            return input;

        if (Array.isArray(input))
            return input.map(item => root.value(item));

        if (typeof input === "object") {
            const out = {};
            for (const key of Object.keys(input))
                out[key] = root.isSecret(key) ? root.mask : root.value(input[key]);
            return out;
        }

        if (typeof input === "string")
            return root.text(input);

        return input;
    }
}

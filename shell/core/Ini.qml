pragma Singleton

// INI files as KDE writes them -- kdeglobals, plasmanotifyrc,
// kglobalshortcutsrc, plasmashellrc -- read the one way.
//
// Five places parsed these by hand, each a little differently: one trimmed
// keys and one did not, one skipped comments, one matched a key in any group
// at all. They are read here only to learn what KDE already says, never
// written, so small and forgiving is the right size: no escapes are decoded
// and no `$e` expansion is done -- nothing read through this needs either.
//
// Pure, and in core, so anything can use it and the tests can load it.
//
//   [Group]            a group, named by what is between the outer brackets;
//                      KDE's nested "[services][org.kde.krunner.desktop]" is
//                      the one group "services][org.kde.krunner.desktop"
//   Key=Value          both trimmed
//   # a comment        skipped, as are blank lines, lines with no "=", and
//                      anything before the first group

import QtQuick

QtObject {
    id: root

    // The group a header line names, or null when the line is not a header.
    function _group(line) {
        return line.startsWith("[") ? line.replace(/^\[|\]$/g, "") : null;
    }

    // { group: { key: value } }, every value a string.
    //
    // A key written twice keeps the last of its values, as every reader of a
    // whole file here always did; a group written twice is one group.
    function parse(text) {
        const groups = {};
        let current = "";
        for (const raw of String(text ?? "").split("\n")) {
            const line = raw.trim();
            if (line.length === 0 || line.startsWith("#"))
                continue;
            const group = root._group(line);
            if (group !== null) {
                current = group;
                groups[current] = groups[current] ?? {};
                continue;
            }
            const eq = line.indexOf("=");
            if (eq < 0 || current === "")
                continue;
            groups[current][line.slice(0, eq).trim()] = line.slice(eq + 1).trim();
        }
        return groups;
    }

    // One key of one group, or "" when it is not there.
    //
    // The FIRST value written, unlike parse(), and on purpose: this is what
    // the callers that ask for a single key have always been given, and a
    // file KDE wrote has each key once anyway.
    function value(text, group, key) {
        let inGroup = false;
        for (const raw of String(text ?? "").split("\n")) {
            const line = raw.trim();
            const header = root._group(line);
            if (header !== null) {
                inGroup = header === group;
                continue;
            }
            if (!inGroup)
                continue;
            const eq = line.indexOf("=");
            if (eq > 0 && line.slice(0, eq).trim() === key)
                return line.slice(eq + 1).trim();
        }
        return "";
    }
}

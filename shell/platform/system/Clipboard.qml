pragma Singleton

// Puts something on the clipboard: text, or the contents of a file.
//
// Always through wl-copy's stdin. Text handed over as an argument would sit
// in the process's command line, where any local user can read it from /proc
// -- and what people copy is passwords as often as anything. A file is
// redirected into it by a shell, its path an argument and never part of the
// script.
//
// A copy made while the last is still starting replaces it rather than
// waiting behind it: the process is stopped and started again, and whatever
// was asked for last is what it is given once it is up. The clipboard
// history and the launcher's sums each kept a wl-copy of their own, and the
// history's waited instead.

import QtQuick
import Quickshell.Io

QtObject {
    id: root

    function copyText(text) {
        root._pending = String(text ?? "");
        textProc.running = false;
        textProc.stdinEnabled = true;
        textProc.running = true;
    }

    // The file's contents as `mime` -- "image/png" -- or, when that is empty,
    // as whatever type wl-copy makes of them.
    function copyFile(path, mime) {
        const type = String(mime ?? "");
        fileProc.running = false;
        fileProc.command = type.length > 0
            ? ["sh", "-c", 'wl-copy --type "$2" < "$1"', "--", String(path), type]
            : ["sh", "-c", 'wl-copy < "$1"', "--", String(path)];
        fileProc.running = true;
    }

    // What the text process writes once it has started. Held for that moment
    // only, and cleared as soon as it is written.
    property string _pending: ""

    readonly property Process _text: Process {
        id: textProc
        command: ["wl-copy"]
        stdinEnabled: true
        onStarted: {
            textProc.write(root._pending);
            root._pending = "";
            textProc.stdinEnabled = false;
        }
    }

    readonly property Process _file: Process {
        id: fileProc
    }
}

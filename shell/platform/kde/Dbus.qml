pragma Singleton

// Shared DBus plumbing.
//
// Quickshell exposes no generic DBus API to QML, so calls go through busctl,
// which speaks JSON (`--json=short`) and therefore needs no GVariant parsing.
// Keeping that decision in one place means the rest of the shell never builds
// a busctl command line.

import QtQuick
import Quickshell
import qs.core

QtObject {
    id: root

    readonly property var busctl: ["busctl", "--user", "--json=short"]

    function propertyArgs(service, path, iface, name) {
        return root.busctl.concat(["get-property", service, path, iface, name]);
    }

    // `value` is written in busctl's own notation for `signature`: "s" and a
    // string, "b" and "true".
    function setPropertyArgs(service, path, iface, name, signature, value) {
        return root.busctl.concat(["set-property", service, path, iface, name, signature, String(value)]);
    }

    function callArgs(service, path, iface, method, signature, args) {
        return root.busctl.concat(["call", service, path, iface, method, signature ?? ""])
                          .concat((args ?? []).map(a => String(a)));
    }

    // ---- fire and forget -----------------------------------------------------
    //
    // For a call whose answer nobody reads, and which means the same thing
    // however many times it is made: switch to this desktop, show that
    // runner, invoke this shortcut. A detached process per call, because the
    // other way -- one Process kept per caller and started again -- drops a
    // call made while the last one is still running: `running = true` on a
    // running process does nothing. Scrolling quickly over the workspaces
    // lost switches exactly that way.
    //
    // Anything whose reply is read, or whose calls must arrive in order, is
    // not this: it keeps a Process of its own.

    function send(service, path, iface, method, signature, args) {
        Quickshell.execDetached(root.callArgs(service, path, iface, method, signature, args));
    }

    function setProperty(service, path, iface, name, signature, value) {
        Quickshell.execDetached(root.setPropertyArgs(service, path, iface, name, signature, value));
    }

    // A global shortcut, invoked as its key would: kglobalaccel runs the
    // component's own action, so a button and the key cannot behave
    // differently. `component` is KWin's unless named.
    function invokeShortcut(name, component) {
        root.send("org.kde.kglobalaccel", `/component/${component ?? "kwin"}`,
                  "org.kde.kglobalaccel.Component", "invokeShortcut", "s", [name]);
    }

    // busctl returns { "type": "...", "data": ... }. Only `data` is ever
    // interesting; the type tag is there for the caller that already knows it.
    function unwrap(text, context) {
        if (!text || text.trim().length === 0)
            return undefined;
        try {
            return JSON.parse(text).data;
        } catch (e) {
            Log.warn("dbus", `${context}: unparseable reply: ${e}`);
            return undefined;
        }
    }
}

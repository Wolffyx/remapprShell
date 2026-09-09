pragma Singleton

// Shared DBus plumbing.
//
// Quickshell exposes no generic DBus API to QML, so calls go through busctl,
// which speaks JSON (`--json=short`) and therefore needs no GVariant parsing.
// Keeping that decision in one place means the rest of the shell never builds
// a busctl command line.

import QtQuick
import qs.core

QtObject {
    id: root

    readonly property var busctl: ["busctl", "--user", "--json=short"]

    function propertyArgs(service, path, iface, name) {
        return root.busctl.concat(["get-property", service, path, iface, name]);
    }

    function callArgs(service, path, iface, method, signature, args) {
        return root.busctl.concat(["call", service, path, iface, method, signature ?? ""])
                          .concat((args ?? []).map(a => String(a)));
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

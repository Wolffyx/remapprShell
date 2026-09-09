// Loads one widget instance and isolates its failures.
//
// Three layers of containment, because a third-party widget must not be able
// to take the panel down:
//
//   1. A Loader, not createObject: an object parented straight onto the host
//      propagates its exceptions into the host.
//   2. Quarantine, for the failures a Loader cannot catch -- a widget that
//      hangs or crashes the process rather than throwing.
//   3. A visible placeholder, so a broken widget leaves a gap the user can see
//      and click rather than silently disappearing.

import QtQuick
import qs.core
import qs.domain.widgets

Loader {
    id: root

    required property var entry
    required property var bar
    required property string screenName
    required property var widgetConfig

    readonly property string widgetId: root.entry.id ?? ""
    readonly property bool builtin: WidgetRegistry.isBuiltin(root.widgetId)
    readonly property url widgetSource: WidgetRegistry.entryUrl(root.widgetId)

    // Built-ins load synchronously so the panel does not visibly reflow as each
    // one appears. Third-party widgets load asynchronously: a slow plugin must
    // not hold up startup.
    asynchronous: !root.builtin

    function reload() {
        // Both the registry and the health file load asynchronously. Loading a
        // widget before the health file has arrived silently discards the
        // attempt record, which is exactly the bookkeeping that detects a
        // widget killing the shell -- so wait for both.
        if (!WidgetRegistry.ready || !Quarantine.loaded)
            return;

        if (!WidgetRegistry.exists(root.widgetId)) {
            Log.warn("panel", `no widget named '${root.widgetId}' is installed`);
            root.setSource("");
            return;
        }

        if (!root.builtin && Quarantine.isQuarantined(root.widgetId)) {
            Log.warn("panel", `skipping quarantined widget '${root.widgetId}': ${Quarantine.reasonFor(root.widgetId)}`);
            root.setSource("");
            return;
        }

        if (!root.widgetSource) {
            Log.warn("panel", `widget '${root.widgetId}' has no Quickshell renderer`);
            root.setSource("");
            return;
        }

        // Recorded before loading, cleared once the shell has stayed up. A
        // widget still marked in flight next time round is one that took the
        // shell with it. Built-ins are exempt: one of those failing is our bug
        // to fix, not something to silently disable.
        if (!root.builtin)
            Quarantine.beginAttempt(root.widgetId);

        // The widget contract declares its injected properties `required`, and
        // required properties must be supplied at construction -- assigning
        // them in onLoaded is too late.
        root.setSource(root.widgetSource, {
            bar: root.bar,
            widgetConfig: root.widgetConfig,
            screenName: root.screenName
        });
    }

    Component.onCompleted: root.reload()
    onWidgetSourceChanged: root.reload()

    Connections {
        target: WidgetRegistry
        function onChanged() { root.reload(); }
    }

    Connections {
        target: Quarantine
        function onLoadedChanged() { root.reload(); }
    }

    // Config edits update the live instance rather than rebuilding it, so a
    // widget keeps its internal state across a settings change.
    onWidgetConfigChanged: if (root.item) root.item.widgetConfig = root.widgetConfig

    onStatusChanged: {
        if (root.status === Loader.Error) {
            Log.error("panel", `widget '${root.widgetId}' failed to load from ${root.widgetSource}`);
            if (!root.builtin)
                Quarantine.recordFailure(root.widgetId, "component failed to load");
        } else if (root.status === Loader.Ready) {
            Log.debug("panel", `widget '${root.widgetId}' loaded`);
        }
    }
}

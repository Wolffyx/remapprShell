// Loads one widget instance and isolates its failures.
//
// A Loader rather than Qt.createComponent + createObject: an object parented
// straight onto the host propagates its exceptions into the host, so one bad
// widget takes the whole panel down. A Loader contains both compile and
// creation errors, which is what makes third-party widgets survivable.

import QtQuick
import qs.core

Loader {
    id: root

    required property var entry
    required property var bar
    required property string screenName
    required property var widgetConfig

    // Where the widget's QML lives. Phase 2 resolves this through the registry,
    // which also searches the user's widget directory.
    readonly property url widgetSource: Qt.resolvedUrl(`../../widgets/${entry.id}/Widget.qml`)

    // Built-ins load synchronously to avoid the panel visibly reflowing as each
    // one appears. Third-party widgets will load asynchronously in Phase 2,
    // where a slow plugin must not delay startup.
    asynchronous: false

    // setSource rather than a `source` binding: the widget contract declares
    // its injected properties `required`, and required properties must be
    // supplied at construction. Assigning them in onLoaded is too late -- the
    // component has already failed to instantiate by then.
    function reload() {
        root.setSource(root.widgetSource, {
            bar: root.bar,
            widgetConfig: root.widgetConfig,
            screenName: root.screenName
        });
    }

    Component.onCompleted: root.reload()
    onWidgetSourceChanged: root.reload()

    // Config edits update the live instance instead of rebuilding it, so a
    // widget keeps its internal state across a settings change.
    onWidgetConfigChanged: if (root.item) root.item.widgetConfig = root.widgetConfig

    onStatusChanged: {
        if (root.status === Loader.Error)
            Log.error("panel", `widget '${root.entry.id}' failed to load from ${root.widgetSource}`);
        else if (root.status === Loader.Ready)
            Log.debug("panel", `widget '${root.entry.id}' loaded`);
    }
}

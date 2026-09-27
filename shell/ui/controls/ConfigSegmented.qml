// Segmented buttons that are one configuration key: the value picked is the
// value written, as a string.
//
// See ConfigToggleRow for `path`, `fallback` and `screen`.

import QtQuick
import qs.domain.config

Segmented {
    id: root

    required property string path
    property var fallback: undefined
    property string screen: ""

    readonly property var _value: root.screen.length > 0 ? ConfigStore.valueFor(root.screen, root.path, root.fallback)
                                                         : ConfigStore.value(root.path, root.fallback)

    current: root._value === undefined || root._value === null ? "" : String(root._value)

    onPicked: value => {
        if (root.screen.length > 0)
            ConfigStore.setForScreen(root.screen, root.path, value);
        else
            ConfigStore.set(root.path, value);
    }
}

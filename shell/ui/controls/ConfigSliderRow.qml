// A SliderRow that is one configuration key, written as a whole number.
//
// See ConfigToggleRow for `path`, `fallback` and `screen`. Every slider on
// the settings pages stores an integer -- a thickness, a count, a number of
// seconds -- so the value is rounded before it is written, as each page did
// by hand. With nothing to show yet and no fallback, it sits at `from`
// rather than being handed a value a number cannot hold.

import QtQuick
import qs.domain.config

SliderRow {
    id: root

    required property string path
    property var fallback: undefined
    property string screen: ""

    value: Number((root.screen.length > 0 ? ConfigStore.valueFor(root.screen, root.path, root.fallback)
                                          : ConfigStore.value(root.path, root.fallback)) ?? root.from)

    onMoved: value => {
        const rounded = Math.round(value);
        if (root.screen.length > 0)
            ConfigStore.setForScreen(root.screen, root.path, rounded);
        else
            ConfigStore.set(root.path, rounded);
    }
}

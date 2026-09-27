// A ToggleRow that is one configuration key: it shows the key and writes it.
//
// The settings pages wired two dozen switches to ConfigStore by hand, each
// saying the path twice -- once to read, once to write -- and a copy that
// changed one and not the other would show one key and write another. Here
// the path is said once.
//
//   path      the key, "panel.autoHide"
//   fallback  what to show before the configuration has been read; the
//             shipped defaults answer for every key they have, so this is
//             only for one they do not
//   screen    an output name, for a key set per monitor; empty for the
//             shared value

import QtQuick
import qs.domain.config

ToggleRow {
    id: root

    required property string path
    property var fallback: undefined
    property string screen: ""

    checked: (root.screen.length > 0 ? ConfigStore.valueFor(root.screen, root.path, root.fallback)
                                     : ConfigStore.value(root.path, root.fallback)) === true

    onToggled: value => {
        if (root.screen.length > 0)
            ConfigStore.setForScreen(root.screen, root.path, value);
        else
            ConfigStore.set(root.path, value);
    }
}

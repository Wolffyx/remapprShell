pragma ComponentBehavior: Bound

// Turns a schema into controls.
//
// This is the whole settings mechanism. Every page that edits configuration
// hands it a set of keys and gets back rows bound to ConfigStore -- so adding a
// setting means adding it to the schema, and a widget that ships its own
// `config` block gets a settings page without this file knowing it exists.
//
// The alternative, a hand-maintained list of Components kept index-aligned with
// a list of pages, is the single worst thing to maintain in a shell like this:
// it works until someone inserts a page in the middle.

import QtQuick
import qs.domain.config
import qs.ui.controls

Column {
    id: root

    // { "path.to.key": { type, label, description, default, ... } }
    required property var keys

    // Prefix applied to every key. Widgets pass "widgets.<id>." so their
    // manifest can use bare names.
    property string prefix: ""

    // Where a value is read from and written to. Overridable so a widget's
    // rows can be bound to its own subtree.
    property var readValue: (path, fallback) => ConfigStore.value(path, fallback)
    property var writeValue: (path, value) => ConfigStore.set(path, value)
    property var isOverridden: path => ConfigStore.isOverridden(path)
    property var resetValue: path => ConfigStore.reset(path)

    spacing: 2

    Repeater {
        model: Object.keys(root.keys ?? {})

        SettingRow {
            id: row

            required property string modelData

            // The model updates a moment before the delegates do, so a page
            // change is briefly a key of the previous section against the keys
            // of the next one. Without a fallback that is a handful of
            // TypeErrors on every page switch.
            readonly property var spec: root.keys[row.modelData] ?? ({})
            readonly property string path: root.prefix + row.modelData
            readonly property var current: root.readValue(row.path, row.spec.default)

            width: root.width
            label: row.spec.label ?? row.modelData
            description: row.spec.description ?? ""
            overridden: root.isOverridden(row.path)
            onResetRequested: root.resetValue(row.path)

            Loader {
                width: parent.width
                sourceComponent: {
                    switch (row.spec.type) {
                        case "bool": return boolControl;
                        case "enum": return enumControl;
                        case "int":
                        case "number": return numberControl;
                        default: return textControl;
                    }
                }
            }

            // One component per schema type, not per setting. A type that has
            // no component falls back to a text field rather than rendering
            // nothing, so an unrecognised setting is still editable.
            Component {
                id: boolControl
                Toggle {
                    checked: row.current === true
                    onToggled: value => root.writeValue(row.path, value)
                }
            }

            Component {
                id: enumControl
                Select {
                    values: row.spec.values ?? []
                    currentIndex: Math.max(0, (row.spec.values ?? []).indexOf(row.current))
                    onPicked: value => root.writeValue(row.path, value)
                }
            }

            Component {
                id: numberControl
                NumberSlider {
                    width: parent.width
                    from: row.spec.min ?? 0
                    to: row.spec.max ?? 100
                    stepSize: row.spec.step ?? 1
                    value: Number(row.current ?? row.spec.default ?? 0)
                    onMoved: value => root.writeValue(row.path, Math.round(value))
                }
            }

            Component {
                id: textControl
                TextInputRow {
                    width: parent.width
                    text: String(row.current ?? "")
                    onCommitted: value => root.writeValue(row.path, value)
                }
            }
        }
    }
}

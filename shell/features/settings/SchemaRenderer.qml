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
//
// The rows are drawn in cards, because a page in this design is a set of named
// groups rather than one long list -- a card per `group` in the schema, in the
// order the schema gives them, and anything with no group in a card of its own
// at the top. A section that never names a group is one card, which is what
// every page looked like before and is still right for a short one.

import QtQuick
import qs.domain.config
import qs.domain.settings.groups
import qs.domain.theme
import qs.ui.controls
import qs.ui.primitives

CardGrid {
    id: root

    // { "path.to.key": { type, label, description, default, group, ... } }
    required property var keys

    // The cards' background. A renderer nested inside another card -- a
    // widget's own settings, opened on its row -- says what it is sitting on.
    property color cardColor: Theme.s2

    // The label over the card holding keys that name no group. Empty draws no
    // label at all, which is right when the page's own heading already says it.
    property string title: ""

    // Prefix applied to every key. Widgets pass "widgets.<id>." so their
    // manifest can use bare names.
    property string prefix: ""

    // Where a value is read from and written to. Overridable so a widget's
    // rows can be bound to its own subtree.
    property var readValue: (path, fallback) => ConfigStore.value(path, fallback)
    property var writeValue: (path, value) => ConfigStore.set(path, value)
    property var isOverridden: path => ConfigStore.isOverridden(path)
    property var resetValue: path => ConfigStore.reset(path)

    // The keys split into cards, in schema order: [{ label, keys: [...] }].
    // The rules, and the reasons for them, are in SettingGroups.
    readonly property var groups: SettingGroups.split(root.keys, root.title)

    count: root.groups.length

    Repeater {
        model: root.groups

        Card {
            id: group

            required property var modelData

            width: root.cellWidth
            color: root.cardColor
            spacing: 4

            SectionLabel {
                visible: group.modelData.label.length > 0
                text: group.modelData.label
            }

            Repeater {
                model: group.modelData.keys

                SettingRow {
                    id: row

                    required property string modelData

                    // The model updates a moment before the delegates do, so a
                    // page change is briefly a key of the previous section
                    // against the keys of the next one. Without a fallback that
                    // is a handful of TypeErrors on every page switch.
                    readonly property var spec: root.keys[row.modelData] ?? ({})
                    readonly property string path: root.prefix + row.modelData
                    readonly property var current: root.readValue(row.path, row.spec.default)

                    width: group.contentWidth
                    controlWidth: {
                        switch (row.spec.type) {
                            case "bool": return 48;
                            case "enum": return 200;
                            default: return -1;
                        }
                    }
                    // A switch is always beside its label. A dropdown is too,
                    // until the card is narrow enough that keeping it there
                    // would leave the description a column three words wide.
                    stacked: row.spec.type !== "bool"
                             && (row.spec.type !== "enum" || row.width < 420)
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

                    // One component per schema type, not per setting. A type
                    // that has no component falls back to a text field rather
                    // than rendering nothing, so an unrecognised setting is
                    // still editable.
                    //
                    // A Loader resizes what it loads, so a switch put straight
                    // into one is stretched across the whole control slot and
                    // reads as a bar. The ones that have a size of their own
                    // are wrapped and pushed to the right; a slider and a text
                    // field keep filling it.
                    Component {
                        id: boolControl
                        Item {
                            implicitHeight: 26

                            Toggle {
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                checked: row.current === true
                                onToggled: value => root.writeValue(row.path, value)
                            }
                        }
                    }

                    Component {
                        id: enumControl
                        Item {
                            implicitHeight: 36

                            Select {
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width
                                values: row.spec.values ?? []
                                currentIndex: Math.max(0, (row.spec.values ?? []).indexOf(row.current))
                                onPicked: value => root.writeValue(row.path, value)
                            }
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
    }
}

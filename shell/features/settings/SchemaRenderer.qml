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
                                case "set": return setControl;
                                // A list with its members named is a choice of
                                // them that keeps its order; one without is
                                // typed. Both store a real list -- a text field
                                // here once saved `"a,b"`, a string, and the
                                // sidebar threw on it.
                                case "list": return (row.spec.values ?? []).length > 0 ? setControl : listControl;
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
                                labels: row.spec.labels ?? []
                                currentIndex: Math.max(0, (row.spec.values ?? []).indexOf(row.current))
                                onPicked: value => root.writeValue(row.path, value)
                            }
                        }
                    }

                    // A fixed set of named things, any of which may be on:
                    // which tiles the quick settings draws, and anything else
                    // shaped like that. The value stored is the list of the
                    // ones that are on, in the schema's own order -- so a
                    // machine that gains a choice later starts with it in the
                    // place the schema puts it rather than at the end.
                    //
                    // A `list` with no `values` is still free-form text: the
                    // tray's pinned ids are not a set, they are whatever the
                    // machine happens to have.
                    Component {
                        id: setControl

                        Column {
                            id: set

                            readonly property var values: row.spec.values ?? []
                            readonly property var labels: row.spec.labels ?? []
                            readonly property bool ordered: row.spec.type === "list"
                            readonly property var chosen: Array.isArray(row.current) ? row.current
                                : typeof row.current === "string" && row.current.length > 0
                                    ? SettingGroups.parseList(row.current, "items") : set.values

                            width: parent.width
                            spacing: 0

                            function labelFor(value, i) {
                                return set.labels[i] ?? value;
                            }

                            // The rule, and why it is not an append, is in
                            // SettingGroups.chooseFrom.
                            function put(value, on) {
                                root.writeValue(row.path, set.ordered
                                    ? SettingGroups.chooseInOrder(set.values, row.current, value, on)
                                    : SettingGroups.chooseFrom(set.values, row.current, value, on));
                            }

                            Repeater {
                                model: set.values

                                ToggleRow {
                                    required property string modelData
                                    required property int index

                                    width: set.width
                                    label: set.labelFor(modelData, index)
                                    checked: set.chosen.indexOf(modelData) >= 0
                                    onToggled: value => set.put(modelData, value)
                                }
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

                    // `format: "words"` for a command line, items split on
                    // commas otherwise. See SettingGroups.parseList.
                    Component {
                        id: listControl
                        TextInputRow {
                            width: parent.width
                            text: SettingGroups.formatList(row.current ?? [], row.spec.format)
                            onCommitted: value => root.writeValue(row.path, SettingGroups.parseList(value, row.spec.format))
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

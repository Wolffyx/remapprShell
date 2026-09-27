pragma ComponentBehavior: Bound

// What Install is about to do, said once more in plain words before it is
// pressed -- the terminal setup's summary, and its one-way door.

import QtQuick
import qs.domain.theme
import qs.ui.primitives
import qs.ui.controls

Column {
    id: root

    required property var answers
    property var keys: []
    signal answered(string key, var value)
    signal jump(int step)

    spacing: 12

    readonly property var lines: [
        { step: 1, text: ({ quickshell: "This shell draws the panel",
                            plasma: "Plasma draws the panel, in this shell's layout",
                            none: "The panel is left as it is" })[root.answers.renderer] },
        { step: 1, text: root.answers.windowList ? "The taskbar lists the open windows"
                                                  : "The taskbar does not list windows" },
        { step: 1, text: ({ plasma: "KWin switches windows with Alt+Tab, in this shell's layout",
                            shell: "This shell switches windows with Alt+Tab",
                            none: "Alt+Tab is left alone" })[root.answers.alttab] },
        { step: 2, text: root.answers.keys.length === 0 ? "No keys are taken"
                         : "Keys: " + root.keys.filter(k => root.answers.keys.indexOf(k.id) >= 0)
                                              .map(k => `${k.key} for ${k.what}`).join(", ") },
        { step: 3, text: root.answers.theme ? "The look and feel is applied" : "The look and feel is left alone" },
        { step: 3, text: root.answers.previews ? "Window previews are built" : "Window previews are not built" },
        { step: 3, text: root.answers.autostart ? "It starts at login, and now" : "It runs now, not at login" },
        { step: 3, text: root.answers.mode === "link" ? "Linked to this source, for development" : "" }
    ].filter(l => l.text.length > 0)

    Card {
        width: parent.width

        Repeater {
            model: root.lines

            Row {
                id: line
                required property var modelData
                width: parent.width
                spacing: 10

                Glyph {
                    anchors.verticalCenter: parent.verticalCenter
                    name: "arrow_right"
                    fallback: "arrow-right"
                    size: 18
                    color: Theme.mut
                }

                PanelText {
                    width: parent.width - 28 - change.width - 20
                    anchors.verticalCenter: parent.verticalCenter
                    wrapMode: Text.WordWrap
                    text: line.modelData.text
                    font.pixelSize: 14
                }

                PanelText {
                    id: change
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Change"
                    font.pixelSize: 12
                    color: Theme.acc
                    TapHandler { onTapped: root.jump(line.modelData.step) }
                    HoverHandler { cursorShape: Qt.PointingHandCursor }
                }
            }
        }
    }

    Card {
        width: parent.width
        ToggleRow {
            label: "Take a restore point first"
            description: "A copy of every file this changes, so it can all be put back as it was."
            checked: root.answers.snapshot
            onToggled: value => root.answered("snapshot", value)
        }
    }
}

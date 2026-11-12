pragma ComponentBehavior: Bound

// The clipboard history: one card, wherever it is opened. Meta+V draws it at
// the pointer (ClipboardOverlay) and the panel's clipboard button in its
// popout; both are this, so what one learns works in the other.
//
// The search field has the keyboard from the moment the card appears, so
// typing searches and nothing needs a click. Everything else is a key on the
// field:
//
//   Up, Down               move; PageUp, PageDown a page; Ctrl+Home, Ctrl+End
//   Return                 copy the selected entry, and close
//   Alt+1 ... Alt+9        copy that visible row, and close
//   Tab, Shift+Tab         the next or previous filter
//   Ctrl+P                 pin or unpin
//   Shift+Delete           remove the entry
//   Escape                 clear the search, then close
//
// Choosing copies. It does not paste: a shell cannot type into somebody
// else's window on Wayland, and Klipper does not either.
//
// An Item without a frame: whoever shows it draws the glass round it, so the
// popout's card and the overlay's are each the one their place draws.

import QtQuick
import QtQuick.Controls
import qs.domain.config
import qs.domain.status
import qs.domain.status.icons
import qs.domain.theme
import qs.ui.controls
import qs.ui.primitives

Item {
    id: card

    // Whether the selected entry is shown whole beside the list.
    property bool preview: ConfigStore.value("clipboard.preview", true) !== false

    signal closeRequested

    readonly property int listWidth: 372
    readonly property int rowHeight: 48
    readonly property int rowGap: 4
    readonly property int pageRows: 7

    implicitWidth: card.preview ? 728 : card.listWidth + 4
    implicitHeight: 506

    // ---- what is shown ------------------------------------------------------

    property string filter: "all"
    property int index: 0
    readonly property string query: field.text
    readonly property var results: ClipboardHistory.clipboardFind(ClipboardStatus.entries, card.filter, card.query)
    readonly property var counts: ClipboardHistory.clipboardCounts(ClipboardStatus.entries)
    readonly property var selected: card.results[card.index] ?? null

    // Ages are worked out against this, and it moves on while the card is
    // open so "now" does not stay "now".
    property real now: Date.now()
    Timer {
        interval: 30000
        repeat: true
        running: card.visible
        onTriggered: card.now = Date.now()
    }

    readonly property var filters: [
        { id: "all", label: "All" },
        { id: "pinned", label: "Pinned" },
        { id: "text", label: "Text" },
        { id: "links", label: "Links" },
        { id: "images", label: "Images" }
    ]

    // The first row the list shows, for the digits Alt picks with.
    readonly property int firstShown: Math.max(0, Math.floor(list.contentY / (card.rowHeight + card.rowGap)))

    onResultsChanged: card.go(Math.min(card.index, card.results.length - 1))
    onFilterChanged: card.go(0)
    onQueryChanged: card.go(0)

    function focusField() {
        field.forceActiveFocus();
    }

    function go(i) {
        card.index = Math.max(0, Math.min(card.results.length - 1, i));
        list.positionViewAtIndex(card.index, ListView.Contain);
    }

    function choose(entry) {
        if (!entry || !ClipboardStatus.pickable(entry))
            return;
        ClipboardStatus.pick(entry);
        card.closeRequested();
    }

    function cycleFilter(step) {
        const at = card.filters.findIndex(f => f.id === card.filter);
        card.filter = card.filters[(at + step + card.filters.length) % card.filters.length].id;
    }

    function stepBack() {
        if (field.text.length > 0) {
            field.text = "";
            return;
        }
        card.closeRequested();
    }

    // Where the pointer last moved to. A row under a pointer that has not
    // moved is hovered the moment it is drawn there -- and every key draws
    // the rows again -- so hovering selects only when the pointer has really
    // moved; otherwise the arrows would fight a resting pointer.
    property point _pointer: Qt.point(-1, -1)

    function pointerMoved(scenePos, i) {
        if (scenePos.x === card._pointer.x && scenePos.y === card._pointer.y)
            return;
        const first = card._pointer.x < 0;
        card._pointer = scenePos;
        if (!first)
            card.index = i;
    }

    // ---- keys ---------------------------------------------------------------

    readonly property var _keyNames: ({
        [Qt.Key_Down]: "Down", [Qt.Key_Up]: "Up", [Qt.Key_PageDown]: "PageDown", [Qt.Key_PageUp]: "PageUp",
        [Qt.Key_Home]: "Home", [Qt.Key_End]: "End", [Qt.Key_Return]: "Return", [Qt.Key_Enter]: "Return",
        [Qt.Key_Tab]: "Tab", [Qt.Key_Backtab]: "Backtab", [Qt.Key_P]: "P", [Qt.Key_Delete]: "Delete",
        [Qt.Key_Escape]: "Escape"
    })

    readonly property var _keys: ({
        "Down": () => card.go(card.index + 1),
        "Up": () => card.go(card.index - 1),
        "PageDown": () => card.go(card.index + card.pageRows),
        "PageUp": () => card.go(card.index - card.pageRows),
        "Ctrl+Home": () => card.go(0),
        "Ctrl+End": () => card.go(card.results.length - 1),
        "Return": () => card.choose(card.selected),
        "Tab": () => card.cycleFilter(1),
        "Backtab": () => card.cycleFilter(-1),
        "Shift+Backtab": () => card.cycleFilter(-1),
        "Ctrl+P": () => ClipboardStatus.togglePin(card.selected),
        "Shift+Delete": () => ClipboardStatus.remove(card.selected),
        "Escape": () => card.stepBack()
    })

    function _combo(event) {
        const mods = event.modifiers;
        return `${mods & Qt.ControlModifier ? "Ctrl+" : ""}${mods & Qt.AltModifier ? "Alt+" : ""}`
             + `${mods & Qt.ShiftModifier ? "Shift+" : ""}${card._keyNames[event.key] ?? ""}`;
    }

    function handleKey(event) {
        // Alt and a digit: the row with that digit beside it.
        const digit = event.key - Qt.Key_0;
        if ((event.modifiers & Qt.AltModifier) && digit >= 1 && digit <= 9) {
            card.choose(card.results[card.firstShown + digit - 1]);
            event.accepted = true;
            return;
        }
        if (!(event.key in card._keyNames))
            return;
        const run = card._keys[card._combo(event)];
        if (!run)
            return;
        run();
        event.accepted = true;
    }

    // Keys reach the card from whoever holds the keyboard -- the overlay, or
    // the panel's popout -- and go on to the field.
    focus: true
    Keys.forwardTo: [field]
    Component.onCompleted: Qt.callLater(card.focusField)

    // ---- the field ----------------------------------------------------------

    Item {
        id: header
        width: parent.width
        height: 40

        Rectangle {
            id: box
            anchors.left: parent.left
            anchors.right: clear.visible ? clear.left : parent.right
            anchors.rightMargin: clear.visible ? 8 : 0
            height: parent.height
            radius: Theme.radiusTiny + 2
            color: Theme.s1
            border.width: 2
            border.color: Theme.acc

            Glyph {
                id: lens
                x: 12
                anchors.verticalCenter: parent.verticalCenter
                name: "search"
                fallback: "search"
                size: 18
                color: Theme.mut
            }

            TextField {
                id: field
                anchors.left: lens.right
                anchors.leftMargin: 8
                anchors.right: count.left
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                focus: true
                background: null
                padding: 0
                color: Theme.fg
                selectionColor: Theme.accC
                selectedTextColor: Theme.accCFg
                placeholderText: "Search the clipboard"
                placeholderTextColor: Theme.mut
                font.family: Theme.fontFamily
                font.pixelSize: 14
                Accessible.name: "Search the clipboard"

                Keys.onPressed: event => card.handleKey(event)
            }

            PanelText {
                id: count
                anchors.right: parent.right
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                font.pixelSize: 12
                color: Theme.mut
                text: card.results.length === card.counts.all
                    ? (card.counts.all === 1 ? "1 entry" : `${card.counts.all} entries`)
                    : `${card.results.length} of ${card.counts.all}`
            }
        }

        IconButton {
            id: clear
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            visible: card.counts.all > card.counts.pinned
            glyph: "delete_sweep"
            iconName: "edit-clear-history"
            color: Theme.mut
            tooltip: ClipboardStatus.editable ? "Clear history, keep pinned" : "Clear Plasma's history"
            onActivated: {
                ClipboardStatus.clear();
                card.focusField();
            }
        }
    }

    // ---- the filters --------------------------------------------------------

    Row {
        id: chips
        anchors.top: header.bottom
        anchors.topMargin: 12
        spacing: 6

        Repeater {
            model: card.filters

            Rectangle {
                id: chip

                required property var modelData
                readonly property bool chosen: card.filter === chip.modelData.id

                width: chipRow.implicitWidth + 24
                height: 30
                radius: height / 2
                color: chip.chosen ? Theme.acc : chipHover.hovered ? Theme.s3 : Theme.s2
                Behavior on color { ColorAnimation { duration: Theme.durationFast } }

                Accessible.role: Accessible.Button
                Accessible.name: chip.modelData.label
                Accessible.checked: chip.chosen

                Row {
                    id: chipRow
                    anchors.centerIn: parent
                    spacing: 6

                    PanelText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: chip.modelData.label
                        color: chip.chosen ? Theme.accFg : Theme.fg
                    }

                    PanelText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: String(card.counts[chip.modelData.id] ?? 0)
                        font.family: Theme.monoFamily
                        font.pixelSize: 11
                        color: chip.chosen ? Theme.accFg : Theme.mut
                    }
                }

                HoverHandler { id: chipHover; cursorShape: Qt.PointingHandCursor }
                TapHandler {
                    onTapped: {
                        card.filter = chip.modelData.id;
                        card.focusField();
                    }
                }
            }
        }
    }

    // ---- the list, and the selected entry whole -----------------------------

    Item {
        id: body
        anchors.top: chips.bottom
        anchors.topMargin: 12
        anchors.bottom: footer.top
        anchors.bottomMargin: 12
        width: parent.width

        ListView {
            id: list
            width: card.listWidth
            height: Math.min(parent.height, card.pageRows * (card.rowHeight + card.rowGap) - card.rowGap)
            clip: true
            spacing: card.rowGap
            boundsBehavior: Flickable.StopAtBounds
            model: card.results

            delegate: ClipboardRow {
                required property var modelData
                required property int index

                width: list.width - 8
                entry: modelData
                current: index === card.index
                now: card.now
                digit: index - card.firstShown >= 0 && index - card.firstShown < 9
                       ? String(index - card.firstShown + 1) : ""
                onPointed: pos => card.pointerMoved(pos, index)
                onChosen: card.choose(modelData)
            }
        }

        // A thin bar where the list scrolls, for how much more there is.
        Rectangle {
            visible: list.contentHeight > list.height
            x: card.listWidth - 3
            width: 3
            height: list.height
            radius: 1.5
            color: Theme.hover

            Rectangle {
                width: parent.width
                radius: parent.radius
                y: list.contentHeight > 0 ? parent.height * list.contentY / list.contentHeight : 0
                height: list.contentHeight > 0 ? parent.height * Math.min(1, list.height / list.contentHeight) : 0
                color: Theme.mut
                opacity: 0.6
            }
        }

        Column {
            width: card.listWidth
            anchors.verticalCenter: list.verticalCenter
            visible: card.results.length === 0
            spacing: 6

            readonly property bool emptyAll: card.counts.all === 0

            Glyph {
                anchors.horizontalCenter: parent.horizontalCenter
                name: parent.emptyAll ? "content_paste" : "search_off"
                fallback: parent.emptyAll ? "edit-paste" : "edit-find"
                size: 32
                color: Theme.mut
            }

            PanelText {
                anchors.horizontalCenter: parent.horizontalCenter
                font.pixelSize: 14
                font.weight: Font.Medium
                text: parent.emptyAll ? "Nothing copied yet" : "No matches"
            }

            Hint {
                horizontalAlignment: Text.AlignHCenter
                text: parent.emptyAll ? "Copy some text or a picture and it shows here."
                                      : "Tab changes the filter · esc clears the search"
            }
        }

        Rectangle {
            visible: card.preview
            x: card.listWidth + 16
            width: 1
            height: parent.height
            color: Theme.out
        }

        ClipboardPreview {
            visible: card.preview
            x: card.listWidth + 33
            width: parent.width - x
            height: parent.height
            entry: card.selected
            now: card.now
            onCopyRequested: card.choose(card.selected)
            onPinRequested: {
                ClipboardStatus.togglePin(card.selected);
                card.focusField();
            }
            onRemoveRequested: {
                ClipboardStatus.remove(card.selected);
                card.focusField();
            }
        }
    }

    // ---- the foot -----------------------------------------------------------

    Item {
        id: footer
        anchors.bottom: parent.bottom
        width: parent.width
        height: 26

        Glyph {
            id: source
            anchors.verticalCenter: parent.verticalCenter
            name: "history"
            fallback: "view-history"
            size: 16
            color: Theme.mut
        }

        PanelText {
            anchors.left: source.right
            anchors.leftMargin: 8
            anchors.right: hints.left
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            elide: Text.ElideRight
            font.pixelSize: 12
            color: Theme.mut
            text: ClipboardStatus.source === "klipper" ? "Plasma's history" : "This shell's history"
        }

        Row {
            id: hints
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6

            KeyCap { anchors.verticalCenter: parent.verticalCenter; text: "↑" }
            KeyCap { anchors.verticalCenter: parent.verticalCenter; text: "↓" }
            PanelText { anchors.verticalCenter: parent.verticalCenter; text: "Move"; font.pixelSize: 12; color: Theme.mut }
            PanelText { anchors.verticalCenter: parent.verticalCenter; text: "·"; font.pixelSize: 12; color: Theme.mut }
            KeyCap { anchors.verticalCenter: parent.verticalCenter; text: "↵" }
            PanelText { anchors.verticalCenter: parent.verticalCenter; text: "Copy"; font.pixelSize: 12; color: Theme.mut }
            PanelText { anchors.verticalCenter: parent.verticalCenter; text: "·"; font.pixelSize: 12; color: Theme.mut }
            KeyCap { anchors.verticalCenter: parent.verticalCenter; visible: card.preview; text: "Tab" }
            PanelText { visible: card.preview; anchors.verticalCenter: parent.verticalCenter; text: "Filter"; font.pixelSize: 12; color: Theme.mut }
            PanelText { visible: card.preview; anchors.verticalCenter: parent.verticalCenter; text: "·"; font.pixelSize: 12; color: Theme.mut }
            KeyCap { anchors.verticalCenter: parent.verticalCenter; text: "esc" }
            PanelText { anchors.verticalCenter: parent.verticalCenter; text: "Close"; font.pixelSize: 12; color: Theme.mut }
        }
    }
}

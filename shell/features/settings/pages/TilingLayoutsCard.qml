pragma ComponentBehavior: Bound

// Snap layouts of the user's own: drawn here, shown in the snap layouts
// panel after the six, as FancyZones has its editor. Start from a preset or
// from the whole screen, choose a zone and split it side by side or top and
// bottom, merge it into its neighbour, drag the edge two zones share; name
// it and save it.
//
// A layout is for any screen -- drawn wide, and turned on its side on a tall
// one, as the six are -- or for wide or tall screens only, drawn that shape
// and shown on no other.
//
// Read and written through `rmpr windows snap layouts`, which keeps them in
// kwin/snap's group of kwinrc, through the ledger, and refuses a zone KWin
// would not make: `behaviour revert` takes them away with the rest. What a
// split or a drag does is SnapEditor's, which tests/tst_SnapEditor.qml holds
// to what the script accepts.

import QtQuick
import qs.domain.theme
import qs.domain.windows.snap
import qs.platform.system
import qs.ui.primitives
import qs.ui.controls

Card {
    id: root

    readonly property CtlSession ctl: CtlSession {
        prefix: ["windows", "snap", "layouts"]
        readFailed: "Could not read your snap layouts."
        logLabel: "windows snap layouts"
    }

    readonly property var saved: root.ctl.state?.layouts ?? []
    readonly property bool full: root.saved.length >= SnapEditor.maxLayouts

    // The layout being drawn, or null: { name, screen, tree, was } -- `was`
    // the name it was saved under, "" for a new one.
    property var draft: null
    property var selected: []
    // What the CLI said when it refused the last save or removal.
    property string problem: ""

    readonly property var screens: ["any", "wide", "tall"]
    readonly property bool tall: root.draft !== null && SnapEditor.tall(root.draft.screen)
    readonly property bool drawable: root.draft !== null && SnapEditor.isLayout(root.draft.tree)
    // The drawing, for a preview to drive.
    readonly property alias canvasItem: canvas

    readonly property bool nameTaken: root.draft !== null && root.draft.name !== root.draft.was
        && root.saved.some(l => l.name === root.draft.name)

    function begin(name, screen, tree, was) {
        root.problem = "";
        root.draft = { name: name, screen: screen, tree: SnapEditor.copy(tree), was: was };
        root.selected = SnapEditor.zones(tree)[0].path;
        // Set, not bound: typing in the field breaks a binding to it.
        nameField.text = name;
    }

    function change(fields) {
        root.draft = Object.assign({}, root.draft, fields);
    }

    // A new tree, and a zone of it chosen: the one at the same path, or the
    // first, when that one has gone.
    function reshape(tree) {
        root.change({ tree: tree });
        if (SnapEditor.zoneAt(tree, root.selected) === null)
            root.selected = SnapEditor.zones(tree)[0].path;
    }

    // Changed to or from tall screens only, the drawing turns with it, so
    // it stays what a screen of that shape would show.
    function setScreen(screen) {
        const turn = SnapEditor.tall(screen) !== root.tall;
        root.change({ screen: screen, tree: turn ? SnapEditor.transpose(root.draft.tree) : root.draft.tree });
    }

    // The first of the two halves stays chosen: at the same path when the
    // split folded into its parent's, a level down when it nested.
    function split(dir) {
        const tree = SnapEditor.split(root.draft.tree, root.selected, dir);
        if (SnapEditor.zoneAt(tree, root.selected) === null)
            root.selected = root.selected.concat([0]);
        root.reshape(tree);
    }

    function merge() {
        const into = SnapEditor.neighbour(root.selected);
        root.reshape(SnapEditor.merge(root.draft.tree, root.selected));
        if (SnapEditor.zoneAt(root.draft.tree, into) !== null)
            root.selected = into;
    }

    // What saving runs: the name, the tree as JSON, the screens, and the
    // name it had, so a rename replaces it where it was.
    function saveArgs() {
        const tree = JSON.stringify(SnapEditor.tidy(root.draft.tree));
        return ["windows", "snap", "layouts", "save", root.draft.name, tree, root.draft.screen, root.draft.was];
    }

    function save() {
        writer.closing = true;
        writer.run(root.saveArgs());
    }

    function remove(name) {
        writer.closing = true;
        writer.run(["windows", "snap", "layouts", "remove", name]);
    }

    readonly property CtlRun _write: CtlRun {
        id: writer

        property bool closing: false

        tag: "settings"
        onFinished: (code, stdout, stderr) => {
            const errors = stderr.split("\n").filter(l => /error/i.test(l));
            root.problem = code === 0 ? "" : (errors.pop() ?? "").replace(/^.*error:?\s*/i, "");
            if (code === 0 && writer.closing)
                root.draft = null;
            writer.closing = false;
            root.ctl.refresh();
        }
    }

    Component.onCompleted: root.ctl.refresh()

    SectionLabel { text: "Your layouts" }

    Hint {
        width: root.contentWidth
        text: root.saved.length === 0
            ? "Draw layouts of your own: they are shown in the snap layouts panel after the six, numbered after them, and Snap Assist fills them as it fills the others."
            : `Shown in the snap layouts panel after the six. ${root.saved.length} of ${SnapEditor.maxLayouts}: the most the panel has room for.`
    }

    Hint {
        visible: root.ctl.status.length > 0 || root.problem.length > 0
        width: root.contentWidth
        text: root.problem.length > 0 ? root.problem : root.ctl.status
        tone: "error"
    }

    Flow {
        visible: root.saved.length > 0
        width: root.contentWidth
        spacing: 10

        Repeater {
            model: root.saved

            SnapLayoutThumb {
                required property var modelData

                tree: modelData.tree
                tall: SnapEditor.tall(modelData.screen)
                label: modelData.name
                chosen: root.draft !== null && root.draft.was === modelData.name
                onActivated: root.begin(modelData.name, modelData.screen ?? "any", modelData.tree, modelData.name)
            }
        }
    }

    TextButton {
        visible: root.draft === null
        enabled: !root.full
        opacity: enabled ? 1 : 0.45
        glyph: "add"
        iconName: "list-add"
        text: root.full ? "Six layouts: remove one to draw another" : "New layout…"
        onActivated: root.begin("", "any", SnapEditor.blank(), "")
    }

    // ---- the editor ---------------------------------------------------------

    Column {
        visible: root.draft !== null
        width: root.contentWidth
        spacing: 12

        TextInputRow {
            id: nameField

            width: Math.min(parent.width, 360)
            placeholderText: "Name"
            maximumLength: 40
            onTextEdited: root.change({ name: nameField.text.trim() })
        }

        Segmented {
            width: parent.width
            values: root.screens
            labels: ["Any screen", "Wide screens only", "Tall screens only"]
            current: root.draft?.screen ?? "any"
            onPicked: value => root.setScreen(value)
        }

        Hint {
            width: parent.width
            text: root.draft?.screen === "any"
                ? "Drawn for a wide screen. On a tall one it is turned on its side, as the six are."
                : `Shown only on ${root.tall ? "tall" : "wide"} screens, as drawn.`
        }

        PanelText {
            text: "Start from"
            font.pixelSize: 12
            color: Theme.mut
        }

        Flow {
            width: parent.width
            spacing: 6

            SnapLayoutThumb {
                tree: SnapEditor.blank()
                tall: root.tall
                label: "The screen"
                onActivated: root.reshape(SnapEditor.blank())
            }

            Repeater {
                model: SnapEditor.presets

                SnapLayoutThumb {
                    required property var modelData

                    tree: root.tall ? SnapEditor.transpose(modelData.tree) : modelData.tree
                    tall: root.tall
                    label: modelData.label
                    onActivated: root.reshape(root.tall ? SnapEditor.transpose(modelData.tree) : modelData.tree)
                }
            }
        }

        SnapLayoutCanvas {
            id: canvas

            anchors.horizontalCenter: parent.horizontalCenter
            width: root.tall ? Math.min(parent.width, 300) : Math.min(parent.width, 560)
            height: implicitHeight
            tree: root.draft?.tree ?? SnapEditor.blank()
            tall: root.tall
            selected: root.selected
            onEdited: tree => root.change({ tree: tree })
            onPicked: path => root.selected = path
        }

        Flow {
            width: parent.width
            spacing: 8

            TextButton {
                enabled: root.draft !== null && SnapEditor.canSplit(root.draft.tree, root.selected, "h")
                opacity: enabled ? 1 : 0.45
                glyph: "vertical_split"
                iconName: "view-split-left-right"
                text: "Split side by side"
                onActivated: root.split("h")
            }

            TextButton {
                enabled: root.draft !== null && SnapEditor.canSplit(root.draft.tree, root.selected, "v")
                opacity: enabled ? 1 : 0.45
                glyph: "horizontal_split"
                iconName: "view-split-top-bottom"
                text: "Split top and bottom"
                onActivated: root.split("v")
            }

            TextButton {
                enabled: root.draft !== null && SnapEditor.canMerge(root.draft.tree, root.selected)
                opacity: enabled ? 1 : 0.45
                glyph: "cell_merge"
                iconName: "edit-table-cell-merge"
                text: "Merge into its neighbour"
                onActivated: root.merge()
            }
        }

        Hint {
            width: parent.width
            text: `Click a zone to choose it, and drag the line between two zones to move it. No zone can be ${Math.round(SnapEditor.minZone * 100)}% of the screen or less either way: KWin makes no smaller tile, so a zone too small to halve does not split, and a line stops short.`
        }

        Hint {
            visible: root.nameTaken
            width: parent.width
            text: "Another of your layouts has that name."
            tone: "error"
        }

        Row {
            spacing: 8

            TextButton {
                primary: true
                enabled: root.drawable && (root.draft?.name ?? "").length > 0 && !root.nameTaken && !writer.running
                opacity: enabled ? 1 : 0.45
                glyph: "check"
                iconName: "document-save"
                text: "Save"
                onActivated: root.save()
            }

            TextButton {
                glyph: "close"
                iconName: "dialog-cancel"
                text: "Cancel"
                onActivated: {
                    root.draft = null;
                    root.problem = "";
                }
            }

            TextButton {
                visible: (root.draft?.was ?? "") !== ""
                enabled: !writer.running
                glyph: "delete"
                iconName: "edit-delete"
                text: "Delete"
                onActivated: root.remove(root.draft.was)
            }
        }
    }
}

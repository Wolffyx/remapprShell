pragma ComponentBehavior: Bound

// Taskbar: the right-click menu card -- which application its System monitor
// row opens, and the entries of the person's own below it: an installed
// application to open, or a name and a command line.
//
// A card of the taskbar page, apart from it because it is the one card with
// state and logic of its own: the choices the monitor row offers, the
// application picker both parts open, and the entries edited in place and
// written back as one list. It writes only `panel.menu.` keys, and needs
// nothing of the page's but a width.

import QtQuick
import qs.domain.config
import qs.domain.panel.menu
import qs.domain.theme
import qs.domain.windows
import qs.ui.primitives
import qs.ui.controls

Card {
    id: root

    // Which application picker is open: "monitor", "entry", or none.
    property string choosing: ""

    // The right-click menu. The monitor row offers the system monitors that
    // are installed -- PanelMenuModel is the one place that knows -- first,
    // then any other application, through the picker: a monitor is whatever
    // somebody wants that row to open, and a terminal running btop is as
    // good an answer as any. Plus the two answers that are not an
    // application: follow what is installed, or no row.
    readonly property string monitorSetting: ConfigStore.value("panel.menu.systemMonitor", "auto")
    readonly property var monitorChoices: {
        const installed = PanelMenuModel.installedMonitors;
        const out = [{ id: "auto", label: installed.length > 0 ? `Automatic (${installed[0].name})` : "Automatic" }];
        for (const m of installed)
            out.push({ id: m.id, label: m.name });
        // Chosen through the picker: an application that is not a monitor
        // by its own account is still the one that was asked for.
        const want = root.monitorSetting;
        const listed = out.findIndex(c => c.id === want) >= 0 || want === "none";
        const chosen = listed ? null : WindowsService.entryById(want);
        if (chosen)
            out.push({ id: want, label: chosen.name || want });
        out.push({ id: "__other", label: "Other application…" });
        out.push({ id: "none", label: "Do not show the row" });
        // A monitor named in the profile that is no longer installed would
        // otherwise leave the dropdown showing the first choice while the
        // setting said something else -- so it is offered, and named as gone.
        if (!listed && !chosen)
            out.push({ id: want, label: `${want} (not installed)` });
        return out;
    }

    function monitorIndex() {
        return Math.max(0, root.monitorChoices.findIndex(c => c.id === root.monitorSetting));
    }

    // The raw list as written, not PanelMenuModel's normalised view: a half
    // finished entry must stay on the page to be finished, and normalising
    // would drop it the moment the name was typed and the command was not.
    readonly property var customEntries: {
        const raw = ConfigStore.value("panel.menu.entries", []);
        return Array.isArray(raw) ? raw : [];
    }

    function writeEntries(list): void {
        ConfigStore.set("panel.menu.entries", list);
    }

    function updateEntry(index, patch): void {
        const list = root.customEntries.map(e => Object.assign({}, e));
        if (index < 0 || index >= list.length)
            return;
        root.writeEntries(list.map((e, i) => i === index ? Object.assign(e, patch) : e));
    }

    function removeEntry(index): void {
        root.writeEntries(root.customEntries.filter((e, i) => i !== index));
    }

    function addCommand(): void {
        root.choosing = "";
        root.writeEntries(root.customEntries.concat([{ label: "", command: "", glyph: "terminal" }]));
    }

    // An application's row is called what the application calls itself
    // until somebody names it otherwise, so the label is left empty.
    function addApp(app): void {
        root.choosing = "";
        root.writeEntries(root.customEntries.concat([{ label: "", app: String(app.id) }]));
    }

    SectionLabel { text: "Right-click menu" }

    Hint {
        text: "The menu a right click on empty panel opens. Its first rows -- settings, widgets, reloading -- are fixed; the monitor it offers and anything below it are yours."
    }

    SettingRow {
        width: root.contentWidth
        label: "System monitor"
        description: PanelMenuModel.installedMonitors.length > 0
            ? "Which application the System monitor row opens: one of the monitors installed here, or any other application."
            : "No system monitor is installed. Choose any application for the row, or leave it off."
        controlWidth: 220
        overridden: ConfigStore.isOverridden("panel.menu.systemMonitor")
        onResetRequested: ConfigStore.set("panel.menu.systemMonitor", "auto")

        Select {
            id: monitorSelect
            implicitWidth: 220
            values: root.monitorChoices.map(c => c.id)
            labels: root.monitorChoices.map(c => c.label)
            currentIndex: root.monitorIndex()
            onPicked: value => {
                // The ComboBox moved its own index when it was chosen, which
                // undoes the binding: put it back, so it keeps following the
                // setting -- and stays on it while the picker is open.
                monitorSelect.currentIndex = Qt.binding(() => root.monitorIndex());
                if (value === "__other") {
                    root.choosing = "monitor";
                    return;
                }
                root.choosing = "";
                ConfigStore.set("panel.menu.systemMonitor", value);
            }
        }
    }

    Loader {
        width: root.contentWidth
        active: root.choosing === "monitor"
        visible: active

        sourceComponent: AppPicker {
            preferred: PanelMenuModel.installedMonitors.map(m => m.id)
            currentId: root.monitorSetting
            placeholder: "Search for the application the row opens"
            onPicked: app => {
                root.choosing = "";
                ConfigStore.set("panel.menu.systemMonitor", String(app.id));
            }
            onCancelled: root.choosing = ""
        }
    }

    SectionLabel { text: "Your own entries" }

    Hint {
        text: "Each row opens an installed application, or runs a command line the way a terminal would -- pipes, arguments and $HOME all work, and it is run detached, so a script that keeps going is not stopped when the menu closes. A command row with no name or no command is not drawn."
    }

    Repeater {
        model: root.customEntries

        // One entry: what it is called, what it opens or runs, and a way to
        // remove it. Written back on losing focus or on Enter, never per
        // keystroke -- see TextInputRow.
        Row {
            id: entryRow

            required property var modelData
            required property int index

            readonly property string appId: String(entryRow.modelData.app ?? "").trim()
            readonly property var app: entryRow.appId.length > 0 ? WindowsService.entryById(entryRow.appId) : null
            readonly property real detailWidth: Math.round((entryRow.width - removeButton.width - entryRow.spacing * 2) * 0.55)

            // The card's inner width: `root.width - 32` was four pixels
            // wider than the card has room for, and the remove button
            // hung over its edge.
            width: root.contentWidth
            spacing: 8

            TextInputRow {
                width: parent.width - entryRow.detailWidth - removeButton.width - parent.spacing * 2
                text: String(entryRow.modelData.label ?? "")
                placeholderText: entryRow.appId.length > 0 ? (entryRow.app?.name || entryRow.appId) : "Name"
                onCommitted: value => root.updateEntry(entryRow.index, { label: value })
            }

            // An application: which one, with its icon, in place of a command.
            Rectangle {
                visible: entryRow.appId.length > 0
                width: entryRow.detailWidth
                height: 36
                radius: Theme.radiusTiny + 2
                color: Theme.s1
                border.width: 1
                border.color: Theme.out

                PanelIcon {
                    id: appIcon
                    x: 10
                    anchors.verticalCenter: parent.verticalCenter
                    implicitSize: 20
                    iconName: String(entryRow.app?.icon ?? "")
                }

                PanelText {
                    anchors.left: appIcon.right
                    anchors.leftMargin: 10
                    anchors.right: parent.right
                    anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    elide: Text.ElideRight
                    color: entryRow.app ? Theme.fg : Theme.error
                    text: entryRow.app ? `Opens ${entryRow.app.name || entryRow.appId}`
                                       : `${entryRow.appId} is not installed`
                }
            }

            TextInputRow {
                visible: entryRow.appId.length === 0
                width: entryRow.detailWidth
                text: String(entryRow.modelData.command ?? "")
                placeholderText: "Command"
                onCommitted: value => root.updateEntry(entryRow.index, { command: value })
            }

            IconButton {
                id: removeButton
                anchors.verticalCenter: parent.verticalCenter
                glyph: "delete"
                iconName: "edit-delete"
                tooltip: "Remove this entry"
                color: Theme.error
                onActivated: root.removeEntry(entryRow.index)
            }
        }
    }

    Row {
        spacing: 8

        TextButton {
            glyph: "apps"
            iconName: "list-add"
            text: "Add an application"
            checked: root.choosing === "entry"
            onActivated: root.choosing = root.choosing === "entry" ? "" : "entry"
        }

        TextButton {
            glyph: "terminal"
            iconName: "list-add"
            text: "Add a command"
            onActivated: root.addCommand()
        }
    }

    Loader {
        width: root.contentWidth
        active: root.choosing === "entry"
        visible: active

        sourceComponent: AppPicker {
            placeholder: "Search for an application to add"
            onPicked: app => root.addApp(app)
            onCancelled: root.choosing = ""
        }
    }
}

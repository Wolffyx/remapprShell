pragma ComponentBehavior: Bound

// Taskbar: the right-click menu card -- which system monitor its row opens,
// and the entries of the person's own below it, each a name and a command
// line.
//
// A card of the taskbar page, apart from it because it is the one card with
// state and logic of its own: the choices the monitor row offers, and the
// entries edited in place and written back as one list. It writes only
// `panel.menu.` keys, and needs nothing of the page's but a width.

import QtQuick
import qs.domain.config
import qs.domain.panel.menu
import qs.domain.theme
import qs.ui.primitives
import qs.ui.controls

Card {
    id: root

    // The right-click menu. What the monitor row can be set to is what is
    // installed -- PanelMenuModel is the one place that knows -- plus the two
    // answers that are not an application: follow what is installed, or no row.
    readonly property string monitorSetting: ConfigStore.value("panel.menu.systemMonitor", "auto")
    readonly property var monitorChoices: {
        const installed = PanelMenuModel.installedMonitors;
        const out = [{ id: "auto", label: installed.length > 0 ? `Automatic (${installed[0].name})` : "Automatic" }];
        for (const m of installed)
            out.push({ id: m.id, label: m.name });
        out.push({ id: "none", label: "Do not show the row" });
        // A monitor named in the profile that is no longer installed would
        // otherwise leave the dropdown showing the first choice while the
        // setting said something else -- so it is offered, and named as gone.
        if (out.findIndex(c => c.id === root.monitorSetting) < 0)
            out.push({ id: root.monitorSetting, label: `${root.monitorSetting} (not installed)` });
        return out;
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

    function addEntry(): void {
        root.writeEntries(root.customEntries.concat([{ label: "", command: "", glyph: "terminal" }]));
    }

    SectionLabel { text: "Right-click menu" }

    Hint {
        text: "The menu a right click on empty panel opens. Its first rows -- settings, widgets, reloading -- are fixed; the monitor it offers and anything below it are yours."
    }

    SettingRow {
        label: "System monitor"
        description: root.monitorChoices.length > 1
            ? "Which one the System monitor row opens. Only what is installed is offered."
            : "No system monitor is installed, so the row is left off the menu."
        controlWidth: 190
        enabled: root.monitorChoices.length > 1
        overridden: ConfigStore.isOverridden("panel.menu.systemMonitor")
        onResetRequested: ConfigStore.set("panel.menu.systemMonitor", "auto")

        Select {
            implicitWidth: 190
            values: root.monitorChoices.map(c => c.label)
            currentIndex: Math.max(0, root.monitorChoices.findIndex(c => c.id === root.monitorSetting))
            onPicked: label => {
                const choice = root.monitorChoices.find(c => c.label === label);
                if (choice)
                    ConfigStore.set("panel.menu.systemMonitor", choice.id);
            }
        }
    }

    SectionLabel { text: "Your own entries" }

    Hint {
        text: "Each row runs a command line, the way a terminal would -- pipes, arguments and $HOME all work. It is run detached, so a script that keeps going is not stopped when the menu closes. A row with no name or no command is not drawn."
    }

    Repeater {
        model: root.customEntries

        // One entry: what it is called, what it runs, and a way to remove
        // it. Written back on losing focus or on Enter, never per
        // keystroke -- see TextInputRow.
        Column {
            id: entryRow

            required property var modelData
            required property int index

            // The card's inner width: `root.width - 32` was four pixels
            // wider than the card has room for, and the remove button
            // hung over its edge.
            width: root.contentWidth
            spacing: 6

            Row {
                width: parent.width
                spacing: 8

                TextInputRow {
                    id: labelField
                    width: parent.width - commandField.width - removeButton.width - parent.spacing * 2
                    text: String(entryRow.modelData.label ?? "")
                    placeholderText: "Name"
                    onCommitted: value => root.updateEntry(entryRow.index, { label: value })
                }

                TextInputRow {
                    id: commandField
                    width: Math.round((parent.width - removeButton.width - parent.spacing * 2) * 0.55)
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
    }

    TextButton {
        glyph: "add"
        iconName: "list-add"
        text: "Add an entry"
        onActivated: root.addEntry()
    }
}

pragma Singleton

// What the panel's right-click menu offers beyond its fixed rows: which system
// monitor it opens, and the entries someone has added themselves.
//
// Here rather than in the menu because two things need the same answers -- the
// menu draws them and the settings page edits them -- and a second reading of
// the configuration in the page is what drifts from the one in the menu.
//
// It says what the rows are, and runs what they run -- here rather than in the
// menu, which is gone the moment a row is chosen (runCtl says what that cost).

import QtQuick
import Quickshell
import qs.platform.system
import qs.domain.config
import qs.domain.launcher.apps
import qs.domain.windows

QtObject {
    id: root

    // Plasma's own system monitor, offered first where it is installed, and
    // so what `auto` opens on a Plasma desktop. Named, because it files
    // itself under System alone and no category finds it.
    //
    // A desktop entry id -- the .desktop basename -- with a hyphen: written
    // with a dot it matches nothing, which is how the row came to be hidden
    // on every machine that had the application.
    readonly property string plasmaMonitor: "org.kde.plasma-systemmonitor"

    // The monitors worth offering, best first: Plasma's, then whatever the
    // installed desktop entries say is a system monitor. `auto` takes the
    // first. No other program is named: the entries say what they are.
    readonly property var _monitors: Apps.monitors(DesktopEntries.applications.values, [root.plasmaMonitor])

    // The same, as `{ id, name }`. The settings page offers exactly this: a
    // monitor that is not installed is not a choice, so it cannot be chosen
    // and then silently do nothing.
    readonly property var installedMonitors: root._monitors.map(entry => ({
        id: String(entry.id), name: entry.name || String(entry.id)
    }))

    readonly property string monitorSetting: String(ConfigStore.value("panel.menu.systemMonitor", "auto"))

    // The entry the System monitor row opens, or null for no row at all --
    // because the setting says `none`, because nothing is installed, or
    // because what was named is not installed any more.
    readonly property var monitorEntry: {
        const want = root.monitorSetting;
        if (want === "none" || want.length === 0)
            return null;
        if (want !== "auto")
            return WindowsService.entryById(want);
        return root._monitors[0] ?? null;
    }

    // The rows someone has added, normalised: a label, a command, and an icon.
    //
    // An entry with no label or no command is dropped rather than drawn, since
    // a nameless row and a row that runs nothing are both a menu that looks
    // broken. Hand-editing the profile is a supported way to set these, so
    // this has to survive whatever is in the file.
    readonly property var entries: {
        const raw = ConfigStore.value("panel.menu.entries", []);
        if (!Array.isArray(raw))
            return [];
        const out = [];
        for (const item of raw) {
            if (!item || typeof item !== "object")
                continue;
            const label = String(item.label ?? "").trim();
            const command = String(item.command ?? "").trim();
            if (label.length === 0 || command.length === 0)
                continue;
            out.push({
                label: label,
                command: command,
                glyph: String(item.glyph ?? "").trim() || "terminal"
            });
        }
        return out;
    }

    // Run one of them. Detached, so a script that keeps running is not tied to
    // the menu that started it -- the menu closes the moment it is chosen --
    // and in a scope of its own, so it is not tied to the shell either: these
    // start applications as often as scripts (see Launch). The scope is named
    // after the program the line starts with.
    // Through `sh -c` because these are command lines people write, with pipes
    // and arguments and `$HOME` in them, not argv arrays.
    function runEntry(command): void {
        const line = String(command ?? "").trim();
        if (line.length === 0)
            return;
        Launch.command(["sh", "-c", line], line.split(/\s+/)[0].split("/").pop());
    }

    // One of the shell's own actions, through the CLI: `rmpr` is the one
    // implementation of each of them, and a second one in QML is what drifts.
    //
    // The process lives here, on a singleton, and not on the menu that asks
    // for it. Choosing a row closes the menu, the menu is built by a
    // LazyLoader, and closing it destroys everything the loader made -- so a
    // Process owned by the menu was destroyed in the same synchronous turn it
    // was told to start, before Quickshell had spawned anything. Every row
    // that went through it did nothing at all, silently, while the one row
    // that launched a desktop entry worked. Nothing on screen said why.
    function runCtl(args): void {
        ctl.run(args);
    }

    // A row that does nothing and says nothing is what sent a whole session
    // looking for a missing click. An action that fails says so in the log,
    // with the line it failed on.
    readonly property CtlRun _ctl: CtlRun {
        id: ctl
        tag: "panel"
        label: `panel menu: ${ctl.args.join(" ")}`
    }
}

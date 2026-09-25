pragma ComponentBehavior: Bound

// What the shell answers over IPC -- `rmpr <thing>`, and `quickshell ipc
// call` underneath it: what the services, the tray, the panel and the status
// widgets are reading, the runtime layer of the configuration, the
// notifications, the weather, the surfaces and the launcher.
//
// The targets and their functions are the CLI's to call and must keep their
// names. The three that open a window -- `settings`, `wizard`, `ask` -- are in
// ShellWindows, beside the windows.

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.SystemTray
import qs.core
import qs.features.panel.model
import qs.domain.launcher
import qs.domain.config
import qs.domain.notifications
import qs.domain.status
import qs.domain.backend
import qs.domain.windows
import qs.domain.surfaces
import qs.domain.weather

Scope {
    IpcHandler {
        target: "services"

        function status(): string { return JSON.stringify(PlasmaServices.summary()); }
        function reconcile(): void { PlasmaServices.reconcile(); }
        function rehost(): void { PlasmaServices.rehost(); }
    }

    // What the tray host can see, which is otherwise only knowable by looking
    // at the panel. `doctor` reads it, and so does anyone working out why an
    // application's icon is not where they expected.
    IpcHandler {
        target: "tray"

        function list(): string {
            const out = [];
            for (const item of SystemTray.items?.values ?? []) {
                if (!item)
                    continue;
                out.push({
                    id: item.id,
                    title: item.title,
                    tooltip: item.tooltipTitle,
                    status: item.status,
                    category: item.category,
                    hasMenu: item.hasMenu,
                    onlyMenu: item.onlyMenu
                });
            }
            return JSON.stringify(out);
        }

        function count(): string { return String(SystemTray.items?.values?.length ?? 0); }
    }

    // A left click on a widget by name: opens its popout, or does whatever
    // that widget does when clicked. The screen defaults to the first one.
    IpcHandler {
        target: "panel"

        function click(widgetId: string, screen: string): string {
            const name = screen || (Quickshell.screens[0]?.name ?? "");
            PanelModel.clickRequested(widgetId, name);
            return name;
        }

        // Its tooltip, for a few seconds, as if the pointer had rested on it.
        function tooltip(widgetId: string, screen: string): string {
            const name = screen || (Quickshell.screens[0]?.name ?? "");
            PanelModel.tooltipRequested(widgetId, name);
            return name;
        }

        // The panel's own right-click menu, as if the pointer had opened it on
        // empty panel. `at` is how far along the panel the click was; -1, the
        // default, centres it. The only way to open this without a mouse, and
        // the only way a session with no pointer can see whether it opens at
        // all -- which is how "a right click on the bottom of the taskbar does
        // nothing" was told apart from "it opens the menu I did not expect".
        function menu(screen: string, at: string): string {
            const name = screen || (Quickshell.screens[0]?.name ?? "");
            const along = at ? parseFloat(at) : -1;
            PanelModel.menuRequested(name, isNaN(along) ? -1 : along);
            return name;
        }

        function closeMenu(): void { PanelModel.closeOpenMenu(); }

        function screens(): string { return Quickshell.screens.map(s => s.name).join("\n"); }

        // Where each shown widget is on that screen's panel, in screen
        // coordinates, in the order the zones hold them.
        function layout(screen: string): string {
            const name = screen || (Quickshell.screens[0]?.name ?? "");
            return JSON.stringify(PanelModel.slots
                .filter(s => s && s.screenName === name && s.visible)
                .map(s => {
                    const p = s.mapToItem(null, 0, 0);
                    return { id: s.entry?.id ?? "", x: Math.round(p.x), y: Math.round(p.y),
                             w: Math.round(s.width), h: Math.round(s.height) };
                }));
        }
    }

    // What the status widgets are reading, as they read it. The same question
    // as the tray's: when an icon on the panel looks wrong, this says whether
    // the widget is drawing its input wrongly or the input is what is wrong.
    IpcHandler {
        target: "status"

        function audio(): string { return JSON.stringify(AudioStatus.summary()); }
        function network(): string { return JSON.stringify(NetworkStatus.summary()); }
        function bluetooth(): string { return JSON.stringify(BluetoothStatus.summary()); }
        function power(): string { return JSON.stringify(PowerStatus.summary()); }
        function media(): string { return JSON.stringify(MediaStatus.summary()); }
        function clipboard(): string { return JSON.stringify(ClipboardStatus.summary()); }
        function brightness(): string { return JSON.stringify(BrightnessStatus.summary()); }
        function keyboard(): string { return JSON.stringify(KeyboardStatus.summary()); }
        function privacy(): string { return JSON.stringify(PrivacyStatus.summary()); }

        // Which window each monitor's panel names, and which windows are
        // asking for attention.
        function windows(): string {
            return JSON.stringify({
                count: WindowsService.windows.length,
                perScreen: Object.keys(WindowsService.lastActiveByOutput).map(o => ({
                    screen: o,
                    title: WindowsService.windowFor(o)?.title ?? ""
                })),
                attention: WindowsService.windows.filter(w => w.attention).map(w => w.title)
            });
        }
    }

    // What the brightness widget does on a scroll and a middle click, for
    // working on it without a pointer. Both go through the widget's own
    // service, so they prove the same path a hand on the wheel would take.
    IpcHandler {
        target: "brightness"

        function step(steps: string, percent: string): string {
            BrightnessStatus.step(parseFloat(steps) || 0, parseInt(percent, 10) || 5);
            return JSON.stringify(BrightnessStatus.displays.map(d => [d.name, d.brightness]));
        }
        function nightLight(): string {
            BrightnessStatus.toggleNightLight();
            return BrightnessStatus.nightState;
        }
    }

    // Opens the clipboard widget's popout, for a shortcut: the first one on
    // any panel, since a keypress has no position to say which screen.
    IpcHandler {
        target: "clipboard"

        function toggle(): string {
            const slot = PanelModel.slots.find(s => s && s.visible && s.entry?.id === "clipboard");
            if (!slot)
                return "no clipboard widget on the panel";
            PanelModel.clickRequested("clipboard", slot.screenName);
            return slot.screenName;
        }
    }

    // The runtime layer of the configuration: in memory only, above the
    // profile, gone when the shell stops. Nothing set here is written
    // anywhere, which makes it the way to try a layout without committing to
    // it -- or to have a second copy of the shell draw a panel while the
    // profile says another renderer is in charge.
    //
    // `quickshell ipc call` reads an argument that starts with `[` as a list
    // of arguments, so a JSON array must be passed with a leading space:
    // `setRuntime bar.entries ' [{"id":"clock","zone":"middle"}]'`.
    IpcHandler {
        target: "config"

        function get(path: string): string { return JSON.stringify(ConfigStore.value(path, null)); }

        function setRuntime(path: string, json: string): string {
            let value;
            try {
                value = JSON.parse(json);
            } catch (e) {
                return `not JSON: ${e.message}`;
            }
            ConfigStore.setRuntime(path, value);
            return JSON.stringify(ConfigStore.value(path, null));
        }

        function clearRuntime(): void { ConfigStore.clearRuntime(); }
    }

    IpcHandler {
        target: "notifications"

        // JSON, because a notification is a record and IPC returns strings.
        function at(index: string): string {
            const entry = NotificationWatch.entries[parseInt(index, 10) || 0];
            return entry ? JSON.stringify(entry) : "";
        }
        function last(): string { return at("0"); }
        function count(): string { return String(NotificationWatch.entries.length); }
        function list(): string { return JSON.stringify(NotificationWatch.entries); }
        function clear(): void { NotificationWatch.clear(); }

        // What a click on an entry in the centre does: the file it named, or
        // the application that sent it, raised or started. Here as well as on
        // the row because a pointer is the one thing a terminal has not got,
        // and this is the half that can be wrong without anybody seeing it.
        function open(index: string): string {
            const entry = NotificationWatch.entries[parseInt(index, 10) || 0];
            if (!entry)
                return "no such notification";
            if (!NotificationWatch.openable(entry))
                return "that notification names nothing to open";
            const target = NotificationWatch.targetOf(entry);
            NotificationWatch.go(target);
            return target.value ? `${target.kind}: ${target.value}` : target.kind;
        }

        // This shell's own server (notifications.server "shell").
        function server(): string { return JSON.stringify(ShellNotifications.summary()); }
        function dnd(state: string): string { return ShellNotifications.setDnd(state) ? "on" : "off"; }
        function dismissAll(): void { ShellNotifications.dismissAll(); }
        // renderer.sh, before switching to a renderer with a Plasma tray.
        function release(): void { PlasmaServices.releaseNotifications(); }
    }

    // The weather, for the CLI and for a report: what it thinks the place is
    // and when it last asked. No coordinates, for the reason WeatherStatus
    // gives -- a located machine is somebody's home.
    IpcHandler {
        target: "weather"

        function status(): string { return JSON.stringify(WeatherStatus.summary()); }
        function refresh(): void { WeatherStatus.refresh(true); }
    }

    // Quickshell reloads by itself only for files the config imported when it
    // loaded. A widget's own files come in later, through a Loader, and so
    // does a singleton only a widget uses; editing one of those changes
    // nothing on screen until this is called. Measured, not assumed: an edit
    // to the show-desktop widget and to Desktops.qml sat unloaded for minutes
    // while the running shell looked current.
    IpcHandler {
        target: "shell"

        function reload(): void { Quickshell.reload(false); }

        // Debug logging, without a restart. The faults worth logging are the
        // ones that happen on a real keyboard under real load, and restarting
        // to enable logging is restarting away the state that caused them.
        function debug(on: string): string {
            Log.debugEnabled = on !== "false" && on !== "0" && on !== "off";
            return Log.debugEnabled ? "debug logging on" : "debug logging off";
        }
    }

    // The sidebar, the key sheet and the session screen, from a key: `rmpr
    // sidebar`, `rmpr keys`, bound with `rmpr shortcuts set`.
    IpcHandler {
        target: "surfaces"

        function sidebar(): void { Surfaces.toggleSidebar(""); }

        // The clipboard menu, at a position given in the compositor's own
        // coordinates. What the KWin script's route ends in -- and what makes
        // the placement testable from a terminal, since a pointer cannot be
        // moved from one.
        function clipboardAt(x: string, y: string, output: string): void {
            Surfaces.openClipboardAt(parseInt(x, 10) || 0, parseInt(y, 10) || 0, output ?? "");
        }
        function keys(): void { Surfaces.toggleKeys(""); }
        function session(kind: string): void { Surfaces.openSession(kind || "promptAll", ""); }
        function switcher(): void { Surfaces.openWindowSwitcher("", 1); }
        function switcherReverse(): void { Surfaces.openWindowSwitcher("", -1); }
        function overview(): void { Surfaces.openOverview("", 1); }
        function overviewReverse(): void { Surfaces.openOverview("", -1); }

        // The switcher's key coming up, from the session daemon. See
        // Surfaces.commitHeld.
        function switcherCommit(): void { Surfaces.commitHeld(); }
        function close(): void { Surfaces.closeAll(); }
    }

    // Lets a keybinding or `rmpr launcher` open whatever the panel button
    // would open. Reimplementing the choice in the CLI would let the two drift
    // apart, which is exactly the sort of thing nobody notices until it is
    // confusing.
    IpcHandler {
        target: "launcher"

        function toggle(): void { LauncherService.toggle("apps"); }
        function open(): void { LauncherService.open("apps"); }
        function search(): void { LauncherService.toggle("search"); }
        function close(): void { LauncherService.close(); }
        function query(text: string): void { LauncherService.openWithQuery(text); }
        function provider(): string { return LauncherService.appsProvider.providerId; }

        // What the built-in search would draw for what has been typed.
        //
        // The only way to check a search from outside the session: a result
        // list is a window holding the keyboard, which no screenshot survives
        // and no test can type into. `query <text>` then `results` is how the
        // ranking was checked on the machine it was built for.
        function results(): string {
            return JSON.stringify(LauncherService.builtin.results.map(r => ({
                kind: r.kind, group: r.group ?? "", name: r.name, description: r.description ?? ""
            })));
        }
        function searchProvider(): string { return LauncherService.searchProvider.providerId; }
    }
}

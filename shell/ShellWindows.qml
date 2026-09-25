pragma ComponentBehavior: Bound

// The windows the shell opens only when asked: the settings, the first-run
// wizard, and the consent window for AI assist. Each is built on request and
// unloaded when it closes, and the IPC targets that open them -- `settings`,
// `wizard`, `ask` -- are here beside them, since they are the only other
// thing that touches the loaders.

import QtQuick
import Quickshell
import Quickshell.Io
import qs.domain.config
import qs.features.diagnostics
import qs.features.settings
import qs.features.wizard

Scope {
    id: root

    // Built only when first opened: a settings window nobody has asked for
    // should cost nothing at startup.
    LazyLoader {
        id: settings
        loading: false

        SettingsWindow {
            id: settingsWindow
            visible: true
            sections: Schema.sections

            // FloatingWindow has no `closed` signal; the window going invisible
            // is how a close reaches us, and unloading then means reopening
            // starts fresh rather than restoring the last page.
            onVisibleChanged: if (!visible) settings.activeAsync = false
        }
    }

    // Shown once, on a machine that has never been set up. Which machines
    // those are is FirstRun's question, and it is a harder one than it looks
    // -- see the note at the top of that file for the day it was got wrong.
    LazyLoader {
        id: wizard
        loading: false

        WizardWindow {
            visible: true
            onFinished: wizard.activeAsync = false
            onVisibleChanged: if (!visible) wizard.activeAsync = false
        }
    }

    Connections {
        target: FirstRun
        function onWantedChanged(): void {
            if (FirstRun.wanted)
                wizard.activeAsync = true;
        }
    }

    // The consent window for AI assist, on one report. Opened by `rmpr ask`
    // when it has no terminal to ask in, and by the widget's Ask button
    // through the same command -- so there is exactly one way to send.
    LazyLoader {
        id: ask
        loading: false

        AskWindow {
            visible: true
            reportName: askReport.name
            onVisibleChanged: if (!visible) ask.activeAsync = false
        }
    }

    QtObject {
        id: askReport
        property string name: ""
    }

    // Settings opened or put away, by a key as well as by `rmpr settings
    // toggle`: one function, so the two cannot come to do different things.
    function toggleSettings(): void {
        settings.activeAsync = !settings.activeAsync;
    }

    // ---- asked for over IPC ------------------------------------------------

    IpcHandler {
        target: "ask"

        function open(report: string): void {
            // A fresh window each time: the report it shows is a property set
            // at construction, and reopening on a different one must not show
            // the old bundle for a frame.
            ask.activeAsync = false;
            askReport.name = report;
            ask.activeAsync = true;
        }
        function close(): void { ask.activeAsync = false; }
    }

    IpcHandler {
        target: "wizard"

        function open(): void { wizard.activeAsync = true; }
        function close(): void { wizard.activeAsync = false; }
    }

    IpcHandler {
        target: "settings"

        function open(): void { settings.activeAsync = true; }
        function close(): void { settings.activeAsync = false; }
        function toggle(): void { root.toggleSettings(); }

        // Opens on a named page. The names are the schema's section ids, which
        // are also the headings in the generated configuration reference, so
        // there is one set of names for the window, the CLI and the docs.
        function page(name: string): string {
            const sections = Schema.sections ?? [];

            // Asked for in the first seconds after the shell starts, the
            // schema file has not been read yet and no page exists to find.
            // The window remembers the name and lands on it when the file
            // arrives; saying "no such page" here was a lie about the name.
            if (sections.length === 0) {
                settings.activeAsync = true;
                settings.item.requestedPage = name;
                return `${name} (opening once the schema loads)`;
            }

            const index = sections.findIndex(s => s && s.id === name);
            if (index < 0)
                return `no such page: ${name} (${sections.map(s => s.id).join(", ")})`;
            settings.activeAsync = true;
            settings.item.currentIndex = index;
            return name;
        }

        // The page names, for `rmpr settings pages`. Empty is not an answer,
        // so it says why it has none rather than printing nothing.
        function pages(): string {
            const sections = Schema.sections ?? [];
            if (sections.length === 0)
                return "the settings schema has not loaded yet";
            return sections.map(s => s.id).join("\n");
        }
    }
}

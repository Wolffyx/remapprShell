pragma Singleton

// The installer window's two conversations with scripts/setup.sh, as data.
//
// Out: the answers, as the flags setup.sh takes them -- every question given,
// so it asks none and applies exactly what the review page showed.
// In: its --progress lines (`::step <what>`, `::ok <what>`, `::fail <what>`,
// `::done <failures>`), folded into the list of tasks the progress page draws
// -- and `::exit <code>`, which the window's own runner adds after setup.sh
// ends, so a script that stopped without saying done is still noticed.
//
// In a module of its own, with no Quickshell import, so it can be tested
// without a running shell -- the reason qs.domain.windows.events exists.

import QtQuick

QtObject {
    id: root

    // The answers the window starts from: setup.sh's own defaults, which are
    // the setup this project is developed against.
    function defaults(keys) {
        return {
            mode: "copy",
            renderer: "quickshell",
            keys: (keys ?? []).filter(k => k.on).map(k => k.id),
            alttab: "plasma",
            windowList: true,
            previews: true,
            theme: true,
            autostart: true,
            snapshot: true
        };
    }

    // setup.sh's arguments for a set of answers. `--unattended` because the
    // window has no terminal behind it; `--no-preflight` because the window's
    // first page was the preflight.
    function setupArgs(a) {
        const yn = v => v ? "yes" : "no";
        const args = ["--unattended", "--progress", "--no-preflight",
                      "--mode", a.mode,
                      "--renderer", a.renderer,
                      "--keys", (a.keys ?? []).length > 0 ? a.keys.join(" ") : "none",
                      "--alttab", a.alttab,
                      "--window-list", yn(a.windowList),
                      "--previews", yn(a.previews),
                      "--theme", yn(a.theme),
                      "--autostart", yn(a.autostart)];
        if (a.snapshot === false)
            args.push("--no-snapshot");
        return args;
    }

    // One progress line, or null for anything else setup.sh prints -- which
    // is most of it, and goes to the details instead.
    function parse(line) {
        const m = /^::(step|ok|fail|done|exit) ?(.*)$/.exec(String(line ?? ""));
        if (!m)
            return null;
        return { kind: m[1], text: m[2].trim() };
    }

    // The tasks after one event: a step starts a running task; ok and fail
    // settle the latest running task of that name. A new array every time,
    // so a binding on it sees the change.
    function apply(tasks, ev) {
        const next = (tasks ?? []).slice();
        if (!ev)
            return next;
        if (ev.kind === "step") {
            next.push({ label: ev.text, state: "running" });
        } else if (ev.kind === "ok" || ev.kind === "fail") {
            for (let i = next.length - 1; i >= 0; i--) {
                if (next[i].label === ev.text && next[i].state === "running") {
                    next[i] = { label: ev.text, state: ev.kind === "ok" ? "done" : "failed" };
                    break;
                }
            }
        }
        return next;
    }

    // What `::done <n>` says: finished, and how many steps failed. -1 while
    // it has not come.
    function failures(ev) {
        if (!ev || ev.kind !== "done")
            return -1;
        const n = parseInt(ev.text, 10);
        return Number.isFinite(n) ? n : 0;
    }
}

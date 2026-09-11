pragma Singleton

// The launcher's actions: what typing the action prefix (">" unless set
// otherwise) offers instead of applications -- the shell's colours, the
// wallpaper, the session -- and the calculator. Pure, and a module of its own
// so the tests can load it; what each action does is LauncherService's.

import QtQuick

QtObject {
    id: root

    readonly property var all: [
        { id: "scheme", name: "Scheme", glyph: "palette", keywords: "colour color theme mode light dark auto",
          description: "Change the colour scheme: follow Plasma, light, or dark" },
        { id: "variant", name: "Variant", glyph: "colors", keywords: "accent colour color",
          description: "Change the accent the colours are worked out from" },
        { id: "wallpaper", name: "Wallpaper", glyph: "image", keywords: "background desktop",
          description: "Change the wallpaper, in Plasma's settings" },
        { id: "dark", name: "Dark", glyph: "dark_mode", keywords: "scheme night",
          description: "Change the scheme to dark mode" },
        { id: "light", name: "Light", glyph: "light_mode", keywords: "scheme day",
          description: "Change the scheme to light mode" },
        { id: "calculator", name: "Calculator", glyph: "calculate", keywords: "math sum calc",
          description: "Do simple math equations" },
        { id: "settings", name: "Settings", glyph: "tune", keywords: "preferences configure shell",
          description: "Open the shell's settings" },
        { id: "taskview", name: "Task view", glyph: "grid_view", keywords: "overview windows desktops",
          description: "Every window and desktop, in KWin's Overview" },
        { id: "sidebar", name: "Sidebar", glyph: "view_sidebar", keywords: "media weather stats",
          description: "Media and the machine at a glance" },
        { id: "keys", name: "Keyboard shortcuts", glyph: "keyboard", keywords: "keys cheatsheet help",
          description: "What the keys do" },
        { id: "lock", name: "Lock", glyph: "lock", keywords: "screen session",
          description: "Lock the session" },
        { id: "suspend", name: "Sleep", glyph: "bedtime", keywords: "suspend session",
          description: "Suspend the machine" },
        { id: "logout", name: "Log out", glyph: "logout", keywords: "session sign out",
          description: "End the session, after Plasma asks" },
        { id: "reboot", name: "Restart", glyph: "restart_alt", keywords: "reboot session",
          description: "Restart the machine, after Plasma asks" },
        { id: "shutdown", name: "Shut down", glyph: "power_settings_new", keywords: "power off halt session",
          description: "Turn the machine off, after Plasma asks" }
    ]

    // What was typed: { actions, text }. `actions` when it starts with the
    // prefix, and `text` is the rest.
    function parse(query, prefix) {
        const q = String(query ?? "");
        const p = String(prefix ?? ">");
        if (p.length > 0 && q.startsWith(p))
            return { actions: true, text: q.slice(p.length).trim() };
        return { actions: false, text: q.trim() };
    }

    // The actions `text` names, best first: an exact name, then a prefix of
    // it, then anywhere in it, then a keyword. Everything for no text.
    function match(text) {
        const t = String(text ?? "").toLowerCase().trim();
        if (t.length === 0)
            return root.all.slice();
        const scored = [];
        for (const a of root.all) {
            const name = a.name.toLowerCase();
            let s = -1;
            if (a.id === t || name === t)
                s = 0;
            else if (a.id.startsWith(t) || name.startsWith(t))
                s = 1;
            else if (name.includes(t))
                s = 2;
            else if (a.keywords.split(" ").some(k => k.startsWith(t)))
                s = 3;
            if (s >= 0)
                scored.push({ a: a, s: s });
        }
        return scored.sort((x, y) => x.s - y.s).map(x => x.a);
    }

    // ---- the calculator ----------------------------------------------------
    //
    // Arithmetic and nothing else: numbers, + - * / % ^ and brackets, parsed
    // by hand. Nothing typed ever reaches an evaluator of code.

    function evaluate(expression) {
        const s = String(expression ?? "").replace(/\s+/g, "").replace(/×/g, "*").replace(/÷/g, "/").replace(/,/g, ".");
        if (s.length === 0 || !/^[0-9+\-*/%^().]+$/.test(s) || !/[0-9]/.test(s))
            return null;
        let i = 0;
        const peek = () => s[i];
        const number = () => {
            const m = /^(\d+\.?\d*|\.\d+)/.exec(s.slice(i));
            if (!m)
                throw new Error("number");
            i += m[0].length;
            return parseFloat(m[0]);
        };
        let expr;
        const factor = () => {
            if (peek() === "+") {
                i++;
                return factor();
            }
            if (peek() === "-") {
                i++;
                return -factor();
            }
            let v;
            if (peek() === "(") {
                i++;
                v = expr();
                if (peek() !== ")")
                    throw new Error("bracket");
                i++;
            } else {
                v = number();
            }
            if (peek() === "^") {
                i++;
                v = Math.pow(v, factor());
            }
            return v;
        };
        const term = () => {
            let v = factor();
            while (peek() === "*" || peek() === "/" || peek() === "%") {
                const op = s[i++];
                const r = factor();
                v = op === "*" ? v * r : op === "/" ? v / r : v % r;
            }
            return v;
        };
        expr = () => {
            let v = term();
            while (peek() === "+" || peek() === "-") {
                const op = s[i++];
                const r = term();
                v = op === "+" ? v + r : v - r;
            }
            return v;
        };
        try {
            const v = expr();
            return i === s.length && Number.isFinite(v) ? v : null;
        } catch (e) {
            return null;
        }
    }

    // Worth offering as a sum: it evaluates, and it has an operator in it --
    // a number alone is a number, not a question.
    function isSum(text) {
        const t = String(text ?? "");
        return /[0-9)]\s*[+\-*/%^×÷]/.test(t) && root.evaluate(t) !== null;
    }

    function formatNumber(v) {
        if (!Number.isFinite(v))
            return "";
        return Number.isInteger(v) ? String(v) : String(Number(v.toPrecision(12)));
    }
}

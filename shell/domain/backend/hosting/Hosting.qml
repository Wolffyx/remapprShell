pragma Singleton

// Whether to host Plasma's tray-only services, as a pure function of what was
// found -- so the rule that decides whether to start a second copy of
// something is tested rather than trusted. See PlasmaServices for why these
// services need hosting at all.

import QtQuick

QtObject {
    // Whether a service is already provided: its bus name has an owner, or
    // plasmawindowed already shows it in the tray -- whose item it names
    // "plasmawindowed_<applet>". The second covers an applet with no name of
    // its own to hold (the device notifier), and an applet that is running but
    // whose name went to someone else: starting it again would not help.
    function provided(service, ownedNames, hostedIds) {
        if (!service)
            return true;
        if (service.name && (ownedNames ?? {})[service.name] === true)
            return true;
        return (hostedIds ?? []).indexOf(`plasmawindowed_${service.applet}`) >= 0;
    }

    // s: {
    //   enabled       the user has not turned it off
    //   renderer      panel.renderer
    //   shellPackage  what plasmashell is on, from plasmashellrc
    //   ourPackage    our quickshell renderer's shell package
    //   services      [{ applet, name, owned }]
    //   notificationServer  notifications.server: "plasma" or "shell"
    // }
    //
    // Returns { start: [applet], reason }: the applets to host, and, when
    // there are none, why not.
    function decide(s) {
        if (!s?.enabled)
            return { start: [], reason: "turned off (services.hostPlasma)" };
        if (s.renderer !== "quickshell")
            return { start: [], reason: `the ${s.renderer} renderer: Plasma's own tray provides them` };
        // Only on our package is there certainly no Plasma tray. On any other
        // one a tray may still be loading, and hosting now would start a
        // second notification server or a second Klipper beside it.
        if (!s.shellPackage || s.shellPackage !== s.ourPackage)
            return { start: [], reason: `plasmashell is on ${s.shellPackage || "an unknown package"}, which may have a tray of its own` };
        // A shell serving notifications itself has no use for Plasma's server
        // beside it, and a hosted one would take the name first.
        const start = (s.services ?? [])
            .filter(x => x && !x.owned)
            .filter(x => !(s.notificationServer === "shell" && x.name === "org.freedesktop.Notifications"))
            .map(x => x.applet);
        return { start: start, reason: start.length > 0 ? "" : "every service already has an owner" };
    }

    // Whether this shell serves notifications itself. Only when asked
    // (notifications.server "shell"), and only with the same certainty the
    // hosting needs -- our renderer, plasmashell on our package -- that no
    // Plasma tray is about to serve them. `released` is renderer.sh asking
    // for the name back before a switch, which it writes into the config only
    // after plasmashell has changed package. Turning the hosting off
    // (`enabled`) is about Plasma's applets, and does not enter into it.
    //
    // Returns { serve, reason }.
    // Which windows belong to the applets this shell started, and so should be
    // closed on sight.
    //
    // `plasmawindowed --statusnotifier` keeps an applet alive after its window
    // is closed -- that is the flag's whole purpose -- but it opens the window
    // first. On every start of the shell that put the clipboard history and
    // the device notifier on screen as though the user had asked for them.
    //
    // Identifying them is harder than it looks, and two obvious answers are
    // wrong:
    //
    // - **The pid is not ours to know.** plasmawindowed is a unique
    //   application: the second invocation hands its applet to the first
    //   process and exits, so the pid of the command we ran belongs to
    //   something already gone, while one surviving process owns a window per
    //   applet.
    // - **The title is the applet's name in the user's language**, which is a
    //   translation catalogue away from anything this shell can read.
    //
    // So: the application id, which every plasmawindowed window shares, while
    // we are *expecting* windows -- for a few seconds after hosting, and no
    // more of them than the applets we started. The same programme opened
    // deliberately from a popout's "..." button comes later than that, and
    // even if it did not, the cost is a window closing and the applet staying
    // in the tray.
    function windowsToClose(s) {
        const closed = s.closed ?? ({});
        const appId = s.appId ?? "";
        let remaining = s.remaining ?? 0;
        if (!s.armed || remaining <= 0 || appId.length === 0)
            return [];

        const out = [];
        for (const window of s.windows ?? []) {
            if (remaining <= 0)
                break;
            if (!window || !window.uuid || closed[window.uuid])
                continue;
            if (String(window.appId ?? "") !== appId)
                continue;
            out.push(window.uuid);
            remaining -= 1;
        }
        return out;
    }

    function serveNotifications(s) {
        if (s?.notificationServer !== "shell")
            return { serve: false, reason: "Plasma draws them (notifications.server)" };
        if (s.released)
            return { serve: false, reason: "let go of for a switch to a renderer with a Plasma tray" };
        if (s.renderer !== "quickshell")
            return { serve: false, reason: `the ${s.renderer} renderer: Plasma's own tray serves them` };
        if (!s.shellPackage || s.shellPackage !== s.ourPackage)
            return { serve: false, reason: `plasmashell is on ${s.shellPackage || "an unknown package"}, which may have a tray of its own` };
        return { serve: true, reason: "" };
    }
}

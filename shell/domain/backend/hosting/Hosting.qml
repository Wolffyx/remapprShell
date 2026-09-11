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

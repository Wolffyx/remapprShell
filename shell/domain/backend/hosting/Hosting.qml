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
        const start = (s.services ?? []).filter(x => x && !x.owned).map(x => x.applet);
        return { start: start, reason: start.length > 0 ? "" : "every service already has an owner" };
    }
}

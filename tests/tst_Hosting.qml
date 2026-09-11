// Tests for when Plasma's tray-only services are hosted.
//
// Getting this wrong in one direction drops every notification on the floor
// -- which is what our renderer did until this existed. Getting it wrong in
// the other starts a second notification server or a second Klipper beside
// Plasma's own, two programs fighting over one bus name and one clipboard.

import QtQuick
import QtTest
import qs.domain.backend.hosting

TestCase {
    name: "Hosting"

    function state(over) {
        return Object.assign({
            enabled: true,
            renderer: "quickshell",
            shellPackage: "ours.desktop",
            ourPackage: "ours.desktop",
            services: [
                { applet: "org.kde.plasma.notifications", name: "org.freedesktop.Notifications", owned: false },
                { applet: "org.kde.plasma.clipboard", name: "org.kde.klipper", owned: false }
            ]
        }, over);
    }

    // Our renderer, our package, nobody serving: exactly the case that was
    // losing notifications.
    function test_everything_unowned_is_hosted() {
        compare(Hosting.decide(state({})).start,
                ["org.kde.plasma.notifications", "org.kde.plasma.clipboard"]);
    }

    function test_an_owned_service_is_left_alone() {
        const s = state({});
        s.services[0].owned = true;
        compare(Hosting.decide(s).start, ["org.kde.plasma.clipboard"]);
    }

    function test_nothing_when_everything_is_owned() {
        const s = state({});
        s.services.forEach(x => x.owned = true);
        const d = Hosting.decide(s);
        compare(d.start, []);
        verify(d.reason.length > 0);
    }

    // Plasma's renderer draws Plasma's tray, which has both.
    function test_not_under_another_renderer() {
        compare(Hosting.decide(state({ renderer: "plasma" })).start, []);
        compare(Hosting.decide(state({ renderer: "caelestia" })).start, []);
    }

    // The case this machine is in right now: the profile and plasmashell
    // disagree. A package that is not ours may have a tray still loading.
    function test_not_when_plasmashell_is_on_another_package() {
        const d = Hosting.decide(state({ shellPackage: "caelestia.desktop" }));
        compare(d.start, []);
        verify(d.reason.indexOf("caelestia.desktop") >= 0);
    }

    function test_not_when_the_package_is_unknown() {
        compare(Hosting.decide(state({ shellPackage: "" })).start, []);
    }

    function test_an_owned_name_is_provided() {
        verify(Hosting.provided({ applet: "a", name: "org.x" }, { "org.x": true }, []));
        verify(!Hosting.provided({ applet: "a", name: "org.x" }, { "org.x": false }, []));
    }

    // The device notifier holds no bus name; its tray item is the only sign
    // that it is already there.
    function test_a_nameless_applet_is_provided_by_its_tray_item() {
        const dn = { applet: "org.kde.plasma.devicenotifier", name: "" };
        verify(!Hosting.provided(dn, {}, []));
        verify(Hosting.provided(dn, {}, ["plasmawindowed_org.kde.plasma.devicenotifier"]));
    }

    // Running, but its name went elsewhere: starting it again would not help.
    function test_a_hosted_applet_counts_even_without_its_name() {
        verify(Hosting.provided({ applet: "org.kde.plasma.notifications", name: "org.freedesktop.Notifications" },
                                {}, ["plasmawindowed_org.kde.plasma.notifications"]));
    }

    function test_not_when_turned_off() {
        compare(Hosting.decide(state({ enabled: false })).start, []);
        compare(Hosting.decide(null).start, []);
    }

    // ---- this shell's own notification server ---------------------------

    // Plasma's server beside ours would take the name first.
    function test_plasmas_notifications_are_not_hosted_while_the_shell_serves_them() {
        compare(Hosting.decide(state({ notificationServer: "shell" })).start, ["org.kde.plasma.clipboard"]);
        compare(Hosting.decide(state({ notificationServer: "plasma" })).start,
                ["org.kde.plasma.notifications", "org.kde.plasma.clipboard"]);
    }

    function serving(over) {
        return Object.assign({
            notificationServer: "shell",
            renderer: "quickshell",
            shellPackage: "ours.desktop",
            ourPackage: "ours.desktop"
        }, over);
    }

    function test_the_shell_serves_notifications_only_when_asked() {
        verify(Hosting.serveNotifications(serving({})).serve);
        verify(!Hosting.serveNotifications(serving({ notificationServer: "plasma" })).serve);
        verify(!Hosting.serveNotifications(serving({ notificationServer: undefined })).serve);
        verify(!Hosting.serveNotifications(null).serve);
    }

    function test_not_where_a_plasma_tray_may_serve_them() {
        verify(!Hosting.serveNotifications(serving({ renderer: "plasma" })).serve);
        verify(!Hosting.serveNotifications(serving({ shellPackage: "" })).serve);
        const d = Hosting.serveNotifications(serving({ shellPackage: "caelestia.desktop" }));
        verify(!d.serve);
        verify(d.reason.indexOf("caelestia.desktop") >= 0);
    }

    // renderer.sh asks for the name back before switching to a renderer with
    // a Plasma tray; the config says so only after plasmashell has switched.
    function test_not_once_let_go_of() {
        verify(!Hosting.serveNotifications(serving({ released: true })).serve);
    }

    function test_serving_does_not_depend_on_the_hosting_switch() {
        verify(Hosting.serveNotifications(serving({ enabled: false })).serve);
    }
}

pragma Singleton

// The panel described independently of how it is drawn.
//
// Zones and ordered entries live here, not in the Quickshell renderer, because
// the Plasma renderer must be able to generate its panel containment from the
// same description. Building this as renderer-agnostic from the start is much
// cheaper than retrofitting it once one renderer has grown roots.

import QtQuick
import qs.core
import qs.domain.config
import qs.domain.widgets

QtObject {
    id: root

    readonly property string renderer: ConfigStore.value("panel.renderer", "quickshell")

    // A left click on a widget, asked for by name rather than by a pointer.
    // Every slot holding `widgetId` on `screen` answers, exactly as it would
    // to the click. For keybindings, and for checking a popout on a machine
    // nobody is sitting at.
    signal clickRequested(string widgetId, string screen)

    // Shows that widget's tooltip for a few seconds, as if the pointer had
    // rested on it.
    signal tooltipRequested(string widgetId, string screen)

    // The panel's own right-click menu, on `screen`, `at` pixels along the
    // panel -- the one thing on the panel a pointer opens that no key and no
    // command could, and therefore the one thing no session without a hand on
    // the mouse could check. It was built, shipped, and never opened once.
    signal menuRequested(string screen, real at)

    // Every slot on every panel, so `panel layout` can say where each one
    // actually is -- the question a screenshot answers badly and a person
    // without a pointer cannot answer at all. Slots add and remove
    // themselves; nothing binds to this.
    property var slots: []

    function addSlot(slot) {
        root.slots = root.slots.concat([slot]);
    }

    function removeSlot(slot) {
        root.slots = root.slots.filter(s => s !== slot);
    }

    // The slot whose popout is open, or null. One at a time across every
    // panel, the way menus behave everywhere else: opening one closes the
    // last, and a press anywhere but on its own widget closes it. Popouts
    // that follow the pointer do not take part (`popoutClosesOnOutsideClick`).
    property var openPopoutSlot: null

    function popoutOpened(slot) {
        const previous = root.openPopoutSlot;
        root.openPopoutSlot = slot;
        if (previous && previous !== slot)
            previous.closePopout();
    }

    function popoutClosed(slot) {
        if (root.openPopoutSlot === slot)
            root.openPopoutSlot = null;
    }

    function closeOpenPopout() {
        root.openPopoutSlot?.closePopout();
    }

    // A press on the panel: on a widget (`slot`), or between widgets (null).
    // The popout's own widget toggles it itself, so that press is left alone.
    function pressed(slot) {
        if (root.openPopoutSlot && root.openPopoutSlot !== slot)
            root.closeOpenPopout();
    }

    // The panel's own right-click menu is the other thing that can be open,
    // and it is not a popout: it belongs to a panel rather than to a slot, so
    // it never passed through any of the above.
    //
    // It is held here anyway. "One of these on screen at a time" is a single
    // rule, and it was split across two owners that knew nothing of each
    // other -- which is exactly how a right click on the panel and then on a
    // task button left a jump list and the panel menu open side by side.
    property var openMenuPanel: null

    function menuOpened(panel) {
        const previous = root.openMenuPanel;
        root.openMenuPanel = panel;
        if (previous && previous !== panel)
            previous.closeMenu();
        // The other direction: whatever popout was up is not wanted beside it.
        root.closeOpenPopout();
    }

    function menuClosed(panel) {
        if (root.openMenuPanel === panel)
            root.openMenuPanel = null;
    }

    function closeOpenMenu() {
        root.openMenuPanel?.closeMenu();
    }

    // Per-output values. A panel reads these rather than the ones above, so a
    // monitor override reaches the panel it describes; the globals remain for
    // anything not drawn per screen.
    function positionFor(name) { return ConfigStore.valueFor(name, "panel.position", "bottom"); }
    function thicknessFor(name) { return ConfigStore.valueFor(name, "panel.thickness", 52); }

    // Hiding is per output as much as position is: a panel worth hiding on a
    // laptop screen is often worth keeping on a second monitor.
    function autoHideFor(name) { return ConfigStore.valueFor(name, "panel.autoHide", false) === true; }
    function revealOnHoverFor(name) { return ConfigStore.valueFor(name, "panel.revealOnHover", true) !== false; }

    // Whether the panel steps aside for a full-screen window on its monitor
    // (ours), or is left to KWin's stacking ("kwin"). Anything else is ours.
    function hidesForFullScreen(name) { return ConfigStore.valueFor(name, "panel.fullScreen", "hide") !== "kwin"; }

    // How it is drawn: a strip along the whole edge, a bar floating clear
    // of it, or each zone as an island of its own. Anything else is "full".
    function styleFor(name) {
        const s = ConfigStore.valueFor(name, "panel.style", "full");
        return s === "floating" || s === "islands" ? s : "full";
    }
    function spacingFor(name) { return ConfigStore.valueFor(name, "panel.spacing", 5); }
    function iconSizeFor(name) { return ConfigStore.valueFor(name, "panel.iconSize", 18); }
    function horizontalFor(name) {
        const p = root.positionFor(name);
        return p === "top" || p === "bottom";
    }
    // Entries for one zone of one screen's panel, enabled only, in config
    // order.
    //
    // An entry with no `zone` is a config error rather than a silent default:
    // a widget quietly appearing in the left zone because a key was misspelled
    // is a confusing bug to chase.
    function entriesForScreen(name, zone) {
        const entries = ConfigStore.valueFor(name, "bar.entries", []) ?? [];
        const way = root.horizontalFor(name) ? "horizontal" : "vertical";
        return entries.filter(e => {
            if (!e || e.enabled === false)
                return false;
            if (!e.zone) {
                root._sayOnce("warn", `entry '${e.id ?? "?"}' has no zone; ignoring it`);
                return false;
            }
            if (e.zone !== zone)
                return false;
            // A manifest names the orientations a widget can be drawn in, and
            // one that cannot be drawn this way round -- the task list is a
            // row of buttons with titles -- is left off rather than drawn
            // broken across a panel forty pixels wide. Until the registry has
            // loaded there is no manifest to ask, and the entry stays.
            const ways = WidgetRegistry.manifest(e.id)?.orientation;
            if (Array.isArray(ways) && ways.indexOf(way) < 0) {
                root._sayOnce("info", `'${e.id}' is not drawn on a ${way} panel (${name}); its manifest says ${ways.join(", ")}`);
                return false;
            }
            return true;
        });
    }

    // What entriesForScreen has already said. It runs inside ZoneRow's
    // binding, which is read again on every configuration change -- folding a
    // sidebar card is one -- so an entry with no zone was reported once per
    // zone, per screen, per write, for the rest of the session. Each thing is
    // said once now, and again only once the entries themselves have changed.
    property var _said: ({})
    readonly property string entriesKey: JSON.stringify(root.entries ?? [])
    onEntriesKeyChanged: root._said = ({})

    function _sayOnce(level, message) {
        if (root._said[message])
            return;
        root._said[message] = true;
        if (level === "warn")
            Log.warn("panel", message);
        else
            Log.info("panel", message);
    }

    // The raw ordered list from config. Order within a zone is significant, so
    // it is preserved exactly as written rather than sorted.
    readonly property var entries: ConfigStore.value("bar.entries", [])

    // Per-widget configuration, lowest precedence first:
    //
    //   1. the defaults the widget's own manifest declares
    //   2. the user's `widgets.<id>` block
    //   3. anything the entry carries inline, for two instances of one widget
    //      configured differently
    //
    // Manifest defaults are the base so that a widget's defaults live with the
    // widget. Repeating them in the shipped shell.json would mean every new
    // option had to be added in two places, and third-party widgets could not
    // have defaults at all.
    function configFor(entry) {
        return Obj.deepMerge(
            WidgetRegistry.configDefaults(entry.id),
            ConfigStore.value(`widgets.${entry.id}`, {}) ?? {},
            entry.config ?? {}
        );
    }
}

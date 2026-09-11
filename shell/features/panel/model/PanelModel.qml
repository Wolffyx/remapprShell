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

    readonly property var zones: ["left", "middle", "right"]

    readonly property string position: ConfigStore.value("panel.position", "bottom")
    readonly property int thickness: ConfigStore.value("panel.thickness", 40)
    readonly property string renderer: ConfigStore.value("panel.renderer", "quickshell")

    readonly property bool horizontal: root.position === "top" || root.position === "bottom"

    // A left click on a widget, asked for by name rather than by a pointer.
    // Every slot holding `widgetId` on `screen` answers, exactly as it would
    // to the click. For keybindings, and for checking a popout on a machine
    // nobody is sitting at.
    signal clickRequested(string widgetId, string screen)

    // Shows that widget's tooltip for a few seconds, as if the pointer had
    // rested on it.
    signal tooltipRequested(string widgetId, string screen)

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

    // Per-output values. A panel reads these rather than the ones above, so a
    // monitor override reaches the panel it describes; the globals remain for
    // anything not drawn per screen.
    function positionFor(name) { return ConfigStore.valueFor(name, "panel.position", "bottom"); }
    function thicknessFor(name) { return ConfigStore.valueFor(name, "panel.thickness", 40); }

    // Hiding is per output as much as position is: a panel worth hiding on a
    // laptop screen is often worth keeping on a second monitor.
    function autoHideFor(name) { return ConfigStore.valueFor(name, "panel.autoHide", false) === true; }
    function horizontalFor(name) {
        const p = root.positionFor(name);
        return p === "top" || p === "bottom";
    }
    function entriesForScreen(name, zone) {
        const entries = ConfigStore.valueFor(name, "bar.entries", []) ?? [];
        const way = root.horizontalFor(name) ? "horizontal" : "vertical";
        return entries.filter(e => {
            if (!e || e.enabled === false)
                return false;
            if (!e.zone) {
                Log.warn("panel", `entry '${e.id ?? "?"}' has no zone; ignoring it`);
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
                Log.info("panel", `'${e.id}' is not drawn on a ${way} panel (${name}); its manifest says ${ways.join(", ")}`);
                return false;
            }
            return true;
        });
    }

    // The raw ordered list from config. Order within a zone is significant, so
    // it is preserved exactly as written rather than sorted.
    readonly property var entries: ConfigStore.value("bar.entries", [])

    // Entries for one zone, enabled only, in config order.
    //
    // An entry with no `zone` is a config error rather than a silent default:
    // a widget quietly appearing in the left zone because a key was misspelled
    // is a confusing bug to chase.
    function entriesFor(zone) {
        return (root.entries ?? []).filter(e => {
            if (!e || e.enabled === false)
                return false;
            if (!e.zone) {
                Log.warn("panel", `entry '${e.id ?? "?"}' has no zone; ignoring it`);
                return false;
            }
            return e.zone === zone;
        });
    }

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

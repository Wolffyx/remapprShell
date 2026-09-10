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
        return entries.filter(e => {
            if (!e || e.enabled === false)
                return false;
            if (!e.zone) {
                Log.warn("panel", `entry '${e.id ?? "?"}' has no zone; ignoring it`);
                return false;
            }
            return e.zone === zone;
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

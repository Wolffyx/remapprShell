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

QtObject {
    id: root

    readonly property var zones: ["left", "middle", "right"]

    readonly property string position: ConfigStore.value("panel.position", "bottom")
    readonly property int thickness: ConfigStore.value("panel.thickness", 40)
    readonly property string renderer: ConfigStore.value("panel.renderer", "quickshell")

    readonly property bool horizontal: root.position === "top" || root.position === "bottom"

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

    // Per-widget configuration: the widget's own subtree of the config, merged
    // over whatever the entry carries inline.
    function configFor(entry) {
        const fromConfig = ConfigStore.value(`widgets.${entry.id}`, {}) ?? {};
        return Obj.deepMerge(fromConfig, entry.config ?? {});
    }
}

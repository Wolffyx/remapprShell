pragma Singleton

// What the first-run wizard's answers write, and what it draws on the desktop
// while they are still being given -- as pure functions of what is in hand, so
// "the preview is what Finish would write" is tested rather than trusted.
//
// Finish writes `writes()` and the preview draws it, from the one list: two
// lists would come to disagree, and a preview that shows something Finish then
// does not write is worse than none.

import QtQuick
import qs.core

QtObject {
    // Setting path -> value, for every answer that changes this shell and
    // nothing outside it. The renderer and the desktop theme are not here:
    // they change KDE's own settings, so they are not previewed and are
    // written by the window at Finish.
    //
    // `a` is { position, thickness, launcher, ai }, `ai` being "off" or a
    // provider id. The provider is written only when there is one: "off"
    // leaves whichever was chosen before, for the day it is turned back on.
    function writes(a) {
        const out = {
            "panel.position": a.position,
            "panel.thickness": a.thickness,
            "launcher.provider": a.launcher,
            "ai.enabled": a.ai !== "off"
        };
        if (a.ai !== "off")
            out["ai.provider"] = a.ai;
        return out;
    }

    // The profile to draw while the wizard is open. A preset takes the saved
    // profile's place, because at Finish it replaces it rather than merging;
    // the answers go on top, because at Finish they are written after it.
    // `preset` is null when none is picked, or its configuration has not
    // been read yet.
    function preview(saved, preset, writes) {
        let out = Obj.clone(preset ?? saved ?? {});
        for (const path of Object.keys(writes ?? {}))
            out = Obj.set(out, path, writes[path]);
        return out;
    }
}

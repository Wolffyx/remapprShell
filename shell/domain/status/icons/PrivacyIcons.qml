pragma Singleton

// What the privacy indicator shows, as pure functions of PipeWire's links:
// who is recording from a microphone or a camera, what hovering says about
// it, and the theme icon and Material Symbols glyph for it.
//
// StatusIcons forwards to every function here, so a widget that asks it keeps
// working; the icon names are Breeze's, for the reason given there.

import QtQuick

QtObject {
    id: root

    // Which applications are recording from a microphone or a camera, from
    // PipeWire's link groups as plain descriptors:
    //   [{ active, source: { mediaClass, api, role }, target: { mediaClass, app } }]
    // Result: { microphone: [app], camera: [app] }, each sorted, no repeats.
    //
    // Recording is an *active* link from a device into an application's
    // capture stream. Three things that look like it are not:
    //   - reading a speaker's monitor (the source is an Audio/Sink): a
    //     visualiser, or a recorder taking the desktop's sound;
    //   - PipeWire's own plumbing, whose streams are marked /Internal -- an
    //     interface split into several virtual microphones is one;
    //   - a screencast, which is a Video/Source too but not a camera.
    function recorders(links) {
        const mic = new Set();
        const cam = new Set();
        for (const l of links ?? []) {
            if (!l || !l.active)
                continue;
            const from = String(l.source?.mediaClass ?? "");
            const to = String(l.target?.mediaClass ?? "");
            const app = String(l.target?.app ?? "");
            if (!app || to.endsWith("/Internal"))
                continue;
            if (to.startsWith("Stream/Input/Audio")
                    && (from.startsWith("Audio/Source") || from.startsWith("Audio/Duplex")))
                mic.add(app);
            else if (to.startsWith("Stream/Input/Video") && from.startsWith("Video/Source")
                     && (l.source.api === "v4l2" || l.source.api === "libcamera" || l.source.role === "Camera"))
                cam.add(app);
        }
        return { microphone: Array.from(mic).sort(), camera: Array.from(cam).sort() };
    }

    function privacyTooltip(users, micMuted) {
        const lines = [];
        if (users?.camera?.length > 0)
            lines.push(`Camera in use by ${users.camera.join(", ")}`);
        if (users?.microphone?.length > 0)
            lines.push(`Microphone in use by ${users.microphone.join(", ")}${micMuted ? " (muted)" : ""}`);
        return lines.join("\n");
    }

    // The tooltip of a widget that mutes the microphone on a middle click:
    // who is recording, and then how to stop it being heard -- the hint only
    // while something is using the microphone.
    function privacyHint(users, micMuted) {
        return [root.privacyTooltip(users, micMuted),
                users?.microphone?.length > 0
                    ? (micMuted ? "Middle-click to unmute the microphone" : "Middle-click to mute the microphone")
                    : ""].filter(s => s).join("\n");
    }

    // One icon for both, where there is room for only one: the camera outranks
    // the microphone, because a camera nobody knew was on is the worse
    // surprise of the two. The privacy widget itself has room for both and
    // shows both.
    function privacyIcon(users, micMuted) {
        if (users?.camera?.length > 0)
            return "camera-on";
        if (users?.microphone?.length > 0)
            return micMuted ? "microphone-sensitivity-muted" : "microphone-sensitivity-high";
        return "";
    }

    // ---- glyphs ----------------------------------------------------------
    //
    // The same state as a Material Symbols name, which is what the shell's
    // own look draws. It follows the theme-icon rule above it, the camera
    // first, so the two can never say different things about one state.

    function privacyGlyph(users, micMuted) {
        if (users?.camera?.length > 0)
            return "videocam";
        if (users?.microphone?.length > 0)
            return micMuted ? "mic_off" : "mic";
        return "";
    }
}

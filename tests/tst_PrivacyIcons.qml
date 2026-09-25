// Tests for the privacy indicator: who is recording from a microphone or a
// camera, read off PipeWire's links, and what the indicator says about it.
//
// Several things look like recording and are not -- a visualiser reading the
// speakers, PipeWire's own plumbing, a screencast -- and an indicator that
// lights for them is one nobody believes when it matters.

import QtQuick
import QtTest
import qs.domain.status.icons

TestCase {
    name: "PrivacyIcons"

    function link(from, to, app, active, source) {
        return {
            active: active !== false,
            source: Object.assign({ mediaClass: from, api: "", role: "" }, source ?? {}),
            target: { mediaClass: to, app: app }
        };
    }

    // The four link shapes that turn up together: a browser recording a
    // microphone (two links, one per channel), another shell reading the
    // speakers' monitor for a visualiser, and an interface's own split
    // feeding its virtual sources. Only the browser is recording anyone.
    function test_only_a_microphone_being_recorded_counts() {
        const r = PrivacyIcons.recorders([
            link("Audio/Source", "Stream/Input/Audio", "Google Chrome input"),
            link("Audio/Source", "Stream/Input/Audio", "Google Chrome input"),
            link("Audio/Sink", "Stream/Input/Audio", "another-shell"),
            link("Audio/Source/Internal", "Stream/Input/Audio/Internal", "alsa_input.Mic1.split")
        ]);
        compare(r.microphone, ["Google Chrome input"]);
        compare(r.camera, []);
    }

    // A stream opened and paused is not listening.
    function test_a_paused_link_is_not_recording() {
        compare(PrivacyIcons.recorders([link("Audio/Source", "Stream/Input/Audio", "App", false)]).microphone, []);
    }

    // A screencast is a Video/Source too; only a camera device counts.
    function test_a_camera_is_not_a_screencast() {
        const r = PrivacyIcons.recorders([
            link("Video/Source", "Stream/Input/Video", "Zoom", true, { api: "v4l2" }),
            link("Video/Source", "Stream/Input/Video", "OBS", true, { api: "libcamera" }),
            link("Video/Source", "Stream/Input/Video", "Meet", true, { role: "Camera" }),
            link("Video/Source", "Stream/Input/Video", "Screen share", true)
        ]);
        compare(r.camera, ["Meet", "OBS", "Zoom"]);
        compare(r.microphone, []);
    }

    function test_nothing_recording() {
        compare(PrivacyIcons.recorders(null).microphone, []);
        compare(PrivacyIcons.privacyTooltip(PrivacyIcons.recorders([]), false), "");
    }

    function test_privacy_tooltip() {
        const users = { microphone: ["Chrome", "Discord"], camera: ["Zoom"] };
        compare(PrivacyIcons.privacyTooltip(users, false),
                "Camera in use by Zoom\nMicrophone in use by Chrome, Discord");
        compare(PrivacyIcons.privacyTooltip({ microphone: ["Chrome"], camera: [] }, true),
                "Microphone in use by Chrome (muted)");
    }

    // The middle-click hint comes only with a microphone in use, and says
    // which way a click would go.
    function test_privacy_hint() {
        compare(PrivacyIcons.privacyHint({ microphone: ["Chrome"], camera: [] }, false),
                "Microphone in use by Chrome\nMiddle-click to mute the microphone");
        compare(PrivacyIcons.privacyHint({ microphone: ["Chrome"], camera: [] }, true),
                "Microphone in use by Chrome (muted)\nMiddle-click to unmute the microphone");
        compare(PrivacyIcons.privacyHint({ microphone: [], camera: ["Zoom"] }, false), "Camera in use by Zoom");
        compare(PrivacyIcons.privacyHint({ microphone: [], camera: [] }, false), "");
        compare(PrivacyIcons.privacyHint(undefined, false), "");
    }

    // Where there is room for one icon, the camera outranks the microphone --
    // the worse surprise of the two -- and the glyph says the same.
    function test_the_camera_outranks_the_microphone() {
        const both = { microphone: ["Chrome"], camera: ["Zoom"] };
        const mic = { microphone: ["Chrome"], camera: [] };
        compare(PrivacyIcons.privacyIcon(both, false), "camera-on");
        compare(PrivacyIcons.privacyGlyph(both, false), "videocam");
        compare(PrivacyIcons.privacyIcon(mic, true), "microphone-sensitivity-muted");
        compare(PrivacyIcons.privacyGlyph(mic, true), "mic_off");
        compare(PrivacyIcons.privacyIcon(mic, false), "microphone-sensitivity-high");
        compare(PrivacyIcons.privacyGlyph(mic, false), "mic");
        compare(PrivacyIcons.privacyIcon({ microphone: [], camera: [] }, false), "");
        compare(PrivacyIcons.privacyGlyph(undefined, false), "");
    }
}

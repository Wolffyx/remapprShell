pragma Singleton

// What the status widgets show, as pure functions of the state they read.
//
// Kept apart from the singletons that read PipeWire, NetworkManager, BlueZ and
// UPower, in a module of its own, so qmltestrunner can load it: a module with
// one Quickshell import in it cannot be imported by the tests at all, and
// every pure function beside it becomes untestable by association.
//
// The icon names are Breeze's, and they are the ones Plasma's own applets ask
// for -- so a panel drawn by us and one drawn by Plasma show the same glyph
// for the same state, and an icon theme that styles one styles both.

import QtQuick

QtObject {
    id: root

    // ---- audio -----------------------------------------------------------

    // 0..1 is 0..100%. Above 1 is amplification, which Plasma marks in two
    // steps so a boosted output never looks like an ordinary loud one.
    function volumeIcon(volume, muted) {
        if (muted || !(volume > 0))
            return "audio-volume-muted";
        if (volume <= 0.25)
            return "audio-volume-low";
        if (volume <= 0.75)
            return "audio-volume-medium";
        if (volume <= 1.0)
            return "audio-volume-high";
        if (volume <= 1.25)
            return "audio-volume-high-warning";
        return "audio-volume-high-danger";
    }

    function micIcon(volume, muted) {
        if (muted || !(volume > 0))
            return "microphone-sensitivity-muted";
        if (volume <= 0.25)
            return "microphone-sensitivity-low";
        if (volume <= 0.75)
            return "microphone-sensitivity-medium";
        return "microphone-sensitivity-high";
    }

    // The volume after `steps` wheel notches of `step` percent each. Steps can
    // be fractional -- a touchpad reports a fraction of a notch -- so the
    // result is rounded to a whole percent rather than snapped to the step
    // grid, which would make every small scroll jump a full step.
    //
    // `max` caps what scrolling can reach, not what the volume may be: an
    // output already boosted past it elsewhere scrolls down from where it is
    // rather than jumping to the cap on the first notch.
    function stepVolume(volume, steps, step, max) {
        const current = volume > 0 ? volume : 0;
        const next = Math.round((current + steps * step / 100) * 100) / 100;
        return Math.max(0, Math.min(Math.max(max, current), next));
    }

    // ---- network ---------------------------------------------------------

    // Signal strength 0..1.
    function wifiIcon(strength) {
        if (!(strength > 0.05))
            return "network-wireless-signal-none";
        if (strength < 0.3)
            return "network-wireless-signal-weak";
        if (strength < 0.55)
            return "network-wireless-signal-ok";
        if (strength < 0.8)
            return "network-wireless-signal-good";
        return "network-wireless-signal-excellent";
    }

    // Whether NetworkManager's connectivity check says the connection does not
    // reach the internet. "Unknown" is what it says when the check is off, and
    // is not a problem worth a warning glyph.
    function isLimited(connectivity) {
        return connectivity === "Limited" || connectivity === "Portal" || connectivity === "None";
    }

    // s: { wired, wifi, strength, connectivity }. A wired link wins when both
    // are up, because that is the one NetworkManager routes through by default
    // and the one Plasma's applet shows.
    function networkIcon(s) {
        const limited = root.isLimited(s?.connectivity ?? "Unknown");
        if (s?.wired)
            return limited ? "network-wired-activated-limited" : "network-wired-activated";
        if (s?.wifi)
            return limited ? "network-limited" : root.wifiIcon(s.strength ?? 0);
        return "network-offline";
    }

    // Mbit/s, as NetworkManager reports it. Zero means unknown, not slow.
    function linkSpeed(mbps) {
        if (!(mbps > 0))
            return "";
        return mbps >= 1000 ? `${mbps / 1000} Gbit/s` : `${mbps} Mbit/s`;
    }

    // ---- bluetooth -------------------------------------------------------

    function bluetoothIcon(enabled, connected) {
        if (!enabled)
            return "network-bluetooth-inactive-symbolic";
        return connected > 0 ? "network-bluetooth-activated" : "network-bluetooth";
    }

    // ---- power -----------------------------------------------------------

    // Quickshell documents a battery's charge as 0..1; UPower itself says
    // 0..100 on the bus. Both are accepted, because which one arrives is a
    // detail of a library version and a battery at "100" drawn as empty is
    // the kind of bug nobody on a desktop machine would ever see to fix.
    function fraction(p) {
        if (!(p > 0))
            return 0;
        return p > 1 ? Math.min(1, p / 100) : p;
    }

    function batteryIcon(fraction, charging) {
        const level = Math.max(0, Math.min(100, Math.round(root.fraction(fraction) * 10) * 10));
        const padded = String(level).padStart(3, "0");
        return `battery-${padded}${charging ? "-charging" : ""}`;
    }

    // "PowerSaver" | "Balanced" | "Performance", as power-profiles-daemon names them.
    function profileIcon(profile) {
        switch (profile) {
        case "PowerSaver":
            return "battery-profile-powersave";
        case "Performance":
            return "battery-profile-performance";
        default:
            return "battery-profile-balanced";
        }
    }

    function profileLabel(profile) {
        switch (profile) {
        case "PowerSaver":
            return "Power saver";
        case "Performance":
            return "Performance";
        default:
            return "Balanced";
        }
    }

    // ---- media -----------------------------------------------------------

    // Which players to offer, and which one to show.
    //
    // `players` are plain descriptors -- { bus, playing, title, artist, pid }
    // -- in the order the bus lists them; the result is indices into that
    // list: { list, current }, current -1 when there is nothing.
    //
    // Some entries are not players of their own. playerctld is a proxy that
    // repeats whichever player it saw last. And a browser with Plasma's
    // integration appears twice: as itself (`...chromium.instance3434`, the
    // tab title with " - YouTube" on the end, no artist) and as the
    // integration, which says whose it is with `kde:pid` 3434 and carries the
    // clean title and the artist. The browser's own entry is dropped when the
    // integration claims its process -- the same rule Plasma's applet uses --
    // and, failing that, a track an earlier entry already offers is not
    // offered again.
    //
    // The one shown: the one the user chose, while it plays; otherwise
    // whatever is playing; otherwise the one the user chose; otherwise the
    // first. Starting something elsewhere follows the music, the way Plasma's
    // own applet does, without a paused choice being forgotten.
    function pickPlayer(players, chosen) {
        const all = players ?? [];
        const list = [];
        const seen = new Set();
        const claimed = new Set(all.filter(p => p && p.pid > 0).map(p => String(p.pid)));
        all.forEach((p, i) => {
            if (!p || String(p.bus ?? "").indexOf("playerctld") >= 0)
                return;
            const instance = /\.instance(\d+)$/.exec(String(p.bus ?? ""));
            if (instance && !(p.pid > 0) && claimed.has(instance[1]))
                return;
            const key = p.title ? `${p.title}\u0000${p.artist ?? ""}` : "";
            if (key && seen.has(key))
                return;
            if (key)
                seen.add(key);
            list.push(i);
        });
        const chosenAt = chosen ? list.find(i => all[i].bus === chosen) : undefined;
        const playingAt = list.find(i => all[i].playing);
        let current = -1;
        if (chosenAt !== undefined && all[chosenAt].playing)
            current = chosenAt;
        else if (playingAt !== undefined)
            current = playingAt;
        else if (chosenAt !== undefined)
            current = chosenAt;
        else if (list.length > 0)
            current = list[0];
        return { list: list, current: current };
    }

    // Seconds to "3:07", or "1:02:03" past the hour.
    function trackTime(seconds) {
        const s = Math.floor(seconds > 0 ? seconds : 0);
        const h = Math.floor(s / 3600);
        const m = Math.floor((s % 3600) / 60);
        const ss = String(s % 60).padStart(2, "0");
        return h > 0 ? `${h}:${String(m).padStart(2, "0")}:${ss}` : `${m}:${ss}`;
    }

    // ---- clipboard -------------------------------------------------------

    // A history with `text` at the top: an entry already in it moves up
    // rather than appearing twice, and the oldest fall off past `limit`.
    function clipboardAdd(list, text, limit) {
        const rest = (list ?? []).filter(e => e && e.text !== text);
        return [{ text: text, image: false }].concat(rest).slice(0, Math.max(1, limit));
    }

    // One line to show for an entry: runs of whitespace, newlines included,
    // collapsed to a space, and cut at `max` characters.
    function clipboardPreview(text, max) {
        const one = String(text ?? "").replace(/\s+/g, " ").trim();
        return one.length > max ? `${one.slice(0, Math.max(1, max - 1))}…` : one;
    }

    // Klipper's history, as its DBus interface gives it: a list of strings,
    // where an image is a text that starts with "▨". An image cannot be put
    // back on the clipboard as text, so it is marked rather than offered.
    // Empty entries are dropped.
    function klipperEntries(items) {
        return (items ?? [])
            .filter(s => typeof s === "string" && s.length > 0)
            .map(s => ({ text: s, image: s.charAt(0) === "▨" }));
    }

    // ---- brightness ------------------------------------------------------

    // An a{sv} as `busctl --json=short` renders it -- [{ Name: { type, data } }]
    // -- as a plain { Name: value }. Anything else is an empty object.
    function busProps(data) {
        const first = Array.isArray(data) ? data[0] : null;
        const out = {};
        if (!first || typeof first !== "object")
            return out;
        for (const key of Object.keys(first))
            out[key] = first[key]?.data;
        return out;
    }

    // powerdevil's displays, from lines of "<name> <GetAll reply>", one per
    // display. A line that does not parse, or a display with no range, is
    // dropped rather than drawn as a screen at 0%.
    function brightnessDisplays(lines) {
        const out = [];
        for (const line of lines ?? []) {
            const s = String(line ?? "").trim();
            const space = s.indexOf(" ");
            if (space <= 0)
                continue;
            let props;
            try {
                props = root.busProps(JSON.parse(s.slice(space + 1)).data);
            } catch (e) {
                continue;
            }
            if (!(props.MaxBrightness > 0))
                continue;
            out.push({
                name: s.slice(0, space),
                label: props.Label ?? "",
                brightness: Math.max(0, props.Brightness ?? 0),
                max: props.MaxBrightness,
                internal: !!props.IsInternal
            });
        }
        return out;
    }

    // The lowest a slider or a scroll takes a display: 1%. The bottom of the
    // range turns some panels' backlight off altogether, and nothing on the
    // panel should be able to black out the screen it is being read on.
    function brightnessFloor(max) {
        return max > 0 ? Math.ceil(max / 100) : 0;
    }

    // The raw value `steps` wheel notches of `step` percent from `value`, on
    // a display whose top is `max`. A display already below the floor --
    // dimmed that far by something else -- is not brightened by scrolling
    // down, the rule stepVolume follows at the other end.
    function stepBrightness(value, max, steps, step) {
        if (!(max > 0))
            return 0;
        const current = Math.max(0, Math.min(max, value > 0 ? value : 0));
        const next = Math.round(current + steps * step * max / 100);
        return Math.max(Math.min(root.brightnessFloor(max), current), Math.min(max, next));
    }

    function brightnessIcon(fraction) {
        return fraction < 0.5 ? "brightness-low" : "brightness-high";
    }

    // KWin's Night Light, reduced to what a panel says about it. `nl` is its
    // DBus properties: { available, enabled, inhibited, currentTemperature }.
    //   "unavailable" -- the compositor cannot tint this screen
    //   "off"         -- turned off in System Settings
    //   "suspended"   -- on, but held off for now
    //   "warm"        -- tinting the screen at this moment
    //   "day"         -- on, and not tinting yet
    // "Warm" is read off the temperature rather than off `daylight`: 6500 K is
    // KWin's neutral, and a day temperature set below it is a tinted screen
    // in daylight, which is what the widget should then say.
    function nightLightState(nl) {
        if (!nl?.available)
            return "unavailable";
        if (!nl.enabled)
            return "off";
        if (nl.inhibited)
            return "suspended";
        return (nl.currentTemperature ?? 6500) < 6500 ? "warm" : "day";
    }

    function nightLightLabel(nl) {
        switch (root.nightLightState(nl)) {
        case "unavailable":
            return "Night Light is not available here";
        case "off":
            return "Night Light is off";
        case "suspended":
            return "Night Light is suspended";
        case "warm":
            return `Night Light · ${nl.currentTemperature} K`;
        default:
            return "Night Light is on";
        }
    }

    function nightLightIcon(state) {
        switch (state) {
        case "warm":
            return "redshift-status-on";
        case "day":
            return "redshift-status-day";
        default:
            return "redshift-status-off";
        }
    }

    // The one glyph on the panel. Night Light wins while it is doing
    // something the user would want to know about -- tinting, or held off by
    // them -- and otherwise the brightness shows; with no display to dim,
    // Night Light is all there is.
    function brightnessPanelIcon(fraction, hasDisplays, nightState) {
        if (nightState === "warm" || nightState === "suspended" || !hasDisplays)
            return root.nightLightIcon(nightState);
        return root.brightnessIcon(fraction);
    }

    // ---- keyboard --------------------------------------------------------

    // KWin's layouts as getLayoutsList gives them: [[shortName, displayName,
    // longName]]. The display name is the label a person gave the layout in
    // System Settings, and is usually empty.
    function keyboardLayouts(rows) {
        return (rows ?? [])
            .filter(r => Array.isArray(r) && r.length >= 3)
            .map(r => ({ short: String(r[0]), display: String(r[1]), long: String(r[2]) }));
    }

    // What the panel shows: the person's own label verbatim, or the short
    // name in capitals -- "US", "DE" -- as Plasma's applet does.
    function layoutLabel(layout) {
        if (!layout)
            return "";
        return layout.display || String(layout.short ?? "").toUpperCase();
    }

    // The index `steps` away from `index`, wrapping round both ends.
    function cycleIndex(index, count, steps) {
        if (!(count > 0))
            return -1;
        const from = index >= 0 && index < count ? index : 0;
        return ((from + steps) % count + count) % count;
    }

    // ---- privacy ---------------------------------------------------------

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
    // The same states as Material Symbols names, which is what the shell's
    // own look draws. Each follows the theme-icon rule above it, thresholds
    // and all, so the two can never say different things about one state.

    function privacyGlyph(users, micMuted) {
        if (users?.camera?.length > 0)
            return "videocam";
        if (users?.microphone?.length > 0)
            return micMuted ? "mic_off" : "mic";
        return "";
    }

    function volumeGlyph(volume, muted) {
        if (muted || !(volume > 0))
            return "volume_off";
        if (volume <= 0.25)
            return "volume_mute";
        if (volume <= 0.75)
            return "volume_down";
        return "volume_up";
    }

    function micGlyph(volume, muted) {
        return muted || !(volume > 0) ? "mic_off" : "mic";
    }

    function wifiGlyph(strength) {
        if (!(strength > 0.05))
            return "signal_wifi_0_bar";
        if (strength < 0.3)
            return "network_wifi_1_bar";
        if (strength < 0.55)
            return "network_wifi_2_bar";
        if (strength < 0.8)
            return "network_wifi_3_bar";
        return "signal_wifi_4_bar";
    }

    function networkGlyph(s) {
        const limited = root.isLimited(s?.connectivity ?? "Unknown");
        if (s?.wired)
            return limited ? "signal_disconnected" : "lan";
        if (s?.wifi)
            return limited ? "signal_wifi_bad" : root.wifiGlyph(s.strength ?? 0);
        return "signal_wifi_off";
    }

    function bluetoothGlyph(enabled, connected) {
        if (!enabled)
            return "bluetooth_disabled";
        return connected > 0 ? "bluetooth_connected" : "bluetooth";
    }

    // Material Symbols draws a battery in six bars, and a charging one at
    // seven marked levels. Under a tenth and not charging is an alert.
    function batteryGlyph(fraction, charging) {
        const f = root.fraction(fraction);
        if (charging) {
            if (f >= 0.95)
                return "battery_charging_full";
            const pct = f * 100;
            const level = pct < 30 ? 20 : pct < 50 ? 30 : pct < 60 ? 50 : pct < 80 ? 60 : pct < 90 ? 80 : 90;
            return `battery_charging_${level}`;
        }
        if (f >= 0.95)
            return "battery_full";
        if (f < 0.1)
            return "battery_alert";
        return `battery_${Math.max(1, Math.min(6, Math.round(f * 6)))}_bar`;
    }

    function profileGlyph(profile) {
        switch (profile) {
        case "PowerSaver":
            return "eco";
        case "Performance":
            return "speed";
        default:
            return "balance";
        }
    }

    function brightnessGlyph(fraction) {
        if (fraction < 0.34)
            return "brightness_low";
        return fraction < 0.67 ? "brightness_medium" : "brightness_high";
    }

    function nightLightGlyph(state) {
        switch (state) {
        case "warm":
            return "nightlight";
        case "suspended":
            return "bedtime_off";
        case "day":
            return "light_mode";
        default:
            return "dark_mode";
        }
    }

    function brightnessPanelGlyph(fraction, hasDisplays, nightState) {
        if (nightState === "warm" || nightState === "suspended" || !hasDisplays)
            return root.nightLightGlyph(nightState);
        return root.brightnessGlyph(fraction);
    }

    // The glyph for what Plasma's OSD says changed, from the icon name it
    // sends with it and, for a level, how far along it is (0..1).
    function osdGlyph(icon, fraction) {
        const i = String(icon ?? "");
        if (i.startsWith("audio-volume"))
            return i.endsWith("muted") ? "volume_off" : root.volumeGlyph(fraction, false);
        if (i.startsWith("microphone"))
            return i.endsWith("muted") ? "mic_off" : "mic";
        if (/keyboard-brightness|kbd-backlight/.test(i))
            return "keyboard";
        if (/brightness/.test(i))
            return root.brightnessGlyph(fraction);
        // Before the general keyboard rule below, which would otherwise take
        // both of these: a lock key is not "the keyboard", and the glyph is
        // the whole message when there is no bar to read.
        if (/caps/.test(i))
            return "keyboard_capslock";
        if (/num-?(lock|on|off)/.test(i))
            return "dialpad";
        if (/touchpad/.test(i))
            return /off|disabled/.test(i) ? "touchpad_mouse_off" : "touchpad_mouse";
        if (/keyboard|input-kb/.test(i))
            return "keyboard";
        if (/airplane|flight/.test(i))
            return "flight";
        if (/bluetooth/.test(i))
            return "bluetooth";
        if (/wireless|wifi|network/.test(i))
            return "wifi";
        if (/battery/.test(i))
            return "battery_full";
        return "";
    }

    // A Bluetooth device's glyph, from the icon name BlueZ gives it
    // ("audio-headset", "input-keyboard", "phone").
    function deviceGlyph(icon) {
        const i = String(icon ?? "");
        if (/headset|headphone/.test(i))
            return "headphones";
        if (/audio|speaker/.test(i))
            return "speaker";
        if (/keyboard/.test(i))
            return "keyboard";
        if (/mouse|pointing|tablet/.test(i))
            return "mouse";
        if (/phone/.test(i))
            return "smartphone";
        if (/gaming|joystick|gamepad/.test(i))
            return "sports_esports";
        if (/computer|laptop/.test(i))
            return "computer";
        if (/watch/.test(i))
            return "watch";
        return "bluetooth";
    }

    // ---- nmcli -----------------------------------------------------------

    // `nmcli -t` output as rows of fields. Fields are split on colons, and a
    // colon inside a field -- a connection named "home:5G" -- arrives as
    // "\:", which is kept as part of the field.
    function nmcliRows(text) {
        const rows = [];
        for (const line of String(text ?? "").split("\n")) {
            if (line.length === 0)
                continue;
            const fields = [];
            let cur = "";
            for (let i = 0; i < line.length; i++) {
                const c = line[i];
                if (c === "\\" && i + 1 < line.length) {
                    cur += line[++i];
                } else if (c === ":") {
                    fields.push(cur);
                    cur = "";
                } else {
                    cur += c;
                }
            }
            fields.push(cur);
            rows.push(fields);
        }
        return rows;
    }

    // The VPN and WireGuard connections, from rows of NAME:TYPE:ACTIVE.
    function vpnConnections(rows) {
        return (rows ?? [])
            .filter(r => r.length >= 3 && (r[1] === "vpn" || r[1] === "wireguard"))
            .map(r => ({ name: r[0], type: r[1], active: r[2] === "yes" }));
    }

    // ---- text ------------------------------------------------------------

    function percent(v) {
        return `${Math.round((v > 0 ? v : 0) * 100)}%`;
    }

    // Seconds to "1 h 05 min" or "45 min". Nothing for an unknown time, which
    // UPower reports as zero -- a battery is never "0 min" from anything.
    function duration(seconds) {
        if (!(seconds > 0))
            return "";
        let h = Math.floor(seconds / 3600);
        let m = Math.round((seconds - h * 3600) / 60);
        if (m === 60) {
            h += 1;
            m = 0;
        }
        if (h === 0)
            return `${Math.max(1, m)} min`;
        return `${h} h ${String(m).padStart(2, "0")} min`;
    }
}

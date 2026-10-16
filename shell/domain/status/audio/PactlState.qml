pragma Singleton

// What a PulseAudio server says, read from pactl's JSON, as the state the
// sound widgets draw -- and which server the shell should be reading at all.
//
// The shell reads sound from PipeWire. Where the PulseAudio socket is answered
// by PulseAudio itself rather than by PipeWire's stand-in for it, the devices
// are PulseAudio's and PipeWire cannot open them: on 2026-10-14 a package
// install brought the PulseAudio daemon back beside PipeWire, it took the USB
// interface, and the output picker lost it with nothing anywhere saying why.
// pactl is the protocol's own client and the same binary talks to either
// server, so a read of it is right whichever one is answering.
//
// PulseBackend runs the read (`sections` below, one `@name` line before each
// command's JSON) and hands the text here. In a module of its own, with no
// Quickshell import, so it can be tested without a running shell.

import QtQuick

QtObject {
    id: root

    // PA_VOLUME_NORM: 100%, unamplified.
    readonly property int norm: 65536

    // Which server to read. `choice` is the setting. "auto" reads PulseAudio
    // when the socket is PulseAudio's own -- what applications play through
    // is what a picker has to offer -- and PipeWire in every other case:
    // PipeWire's stand-in answering, or nobody answering, which on a desktop
    // with PipeWire and no pulse layer is still a desktop with sound.
    function backendFor(choice, server) {
        if (choice === "pipewire" || choice === "pulse")
            return choice;
        const name = String(server ?? "");
        return name.length > 0 && !root.onPipeWire(name) ? "pulse" : "pipewire";
    }

    // pipewire-pulse calls itself "PulseAudio (on PipeWire 1.6.9)";
    // PulseAudio calls itself "pulseaudio".
    function onPipeWire(server) {
        return /\bon PipeWire\b/i.test(String(server ?? ""));
    }

    // Unreadable is the same answer as nothing: no server said anything this
    // shell can draw.
    function json(text) {
        const s = String(text ?? "").trim();
        if (s.length === 0)
            return null;
        try {
            return JSON.parse(s);
        } catch (e) {
            return null;
        }
    }

    // The server's name from `pactl -f json info`, "" when nobody answered.
    function serverName(text) {
        const info = root.json(text);
        return String(info?.server_name ?? "");
    }

    // The text of each `@name` section, by name.
    function sections(text) {
        const out = ({});
        let name = "";
        for (const line of String(text ?? "").split("\n")) {
            const m = /^@([a-z]+)$/.exec(line);
            if (m) {
                name = m[1];
                out[name] = "";
            } else if (name) {
                out[name] += line + "\n";
            }
        }
        return out;
    }

    // A level as the widgets hold it -- 1.0 is 100% -- from pactl's
    // per-channel volumes: their mean, which is what PipeWire's reading is.
    function level(volume) {
        const channels = Object.values(volume ?? {});
        if (channels.length === 0)
            return 0;
        let sum = 0;
        for (const c of channels)
            sum += Number(c?.value) || 0;
        return sum / channels.length / root.norm;
    }

    // The argument pactl takes for a level: raw, so 73% stays 73% instead of
    // rounding through a whole percentage. Every channel gets it, as PipeWire's
    // writer does.
    function volumeArg(level) {
        return String(Math.round(Math.max(0, Number(level) || 0) * root.norm));
    }

    // A source that only echoes a sink is an output, not something to record
    // from. pactl names the sink in `monitor_source` (on a source, that field
    // is what it monitors; on a sink it is its own monitor, so this is for
    // sources only).
    function monitors(entry) {
        const props = entry?.properties ?? {};
        return String(entry?.monitor_source ?? "").length > 0 || props["device.class"] === "monitor";
    }

    function device(entry) {
        return {
            name: String(entry?.name ?? ""),
            description: String(entry?.description ?? ""),
            volume: root.level(entry?.volume),
            muted: entry?.mute === true
        };
    }

    // The whole state from one read, or null when no server answered.
    function parse(text) {
        const sec = root.sections(text);
        const info = root.json(sec.info);
        if (!info)
            return null;
        const sinks = (root.json(sec.sinks) ?? []).map(e => root.device(e));
        const sources = (root.json(sec.sources) ?? []).filter(e => !root.monitors(e)).map(e => root.device(e));
        return {
            server: String(info.server_name ?? ""),
            defaultSink: String(info.default_sink_name ?? ""),
            defaultSource: String(info.default_source_name ?? ""),
            sinks: sinks.filter(d => d.name.length > 0),
            sources: sources.filter(d => d.name.length > 0)
        };
    }

    // A line of `pactl subscribe` worth a read: a device, a card or the
    // server's defaults changing -- not an application's stream, and not a
    // client coming and going, which is every pactl this shell runs.
    function relevant(line) {
        return /^Event '[a-z]+' on (sink|source|server|card) #/.test(String(line ?? ""));
    }
}

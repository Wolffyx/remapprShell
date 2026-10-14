// Tests for reading a PulseAudio server through pactl's JSON, and for which
// server the sound widgets read at all.
//
// The choice is the part that went wrong unseen: with PulseAudio itself on
// the socket, PipeWire had no USB interface to offer and the picker simply
// had one device fewer. And a monitor listed as a microphone, or a device
// that is a new object on every read, is a picker that looks right and is not.

import QtQuick
import QtTest
import qs.domain.status.audio

TestCase {
    name: "PactlState"

    function read(info, sinks, sources) {
        return ["@info", JSON.stringify(info),
                "@sinks", JSON.stringify(sinks),
                "@sources", JSON.stringify(sources)].join("\n");
    }

    function stereo(value) {
        return { "front-left": { value: value, value_percent: "" }, "front-right": { value: value, value_percent: "" } };
    }

    readonly property var info: ({
        server_name: "pulseaudio",
        default_sink_name: "alsa_output.usb-Scarlett.HiFi__Line__sink",
        default_source_name: "alsa_input.usb-Scarlett.HiFi__Mic1__source"
    })

    readonly property var sinks: [
        { index: 0, name: "alsa_output.pci-hdmi", description: "HDMI 5", mute: false,
          volume: stereo(47841), monitor_source: "alsa_output.pci-hdmi.monitor", properties: { "device.class": "sound" } },
        { index: 3, name: "alsa_output.usb-Scarlett.HiFi__Line__sink", description: "Scarlett 2i2 Line 1-2", mute: true,
          volume: stereo(65536), monitor_source: "alsa_output.usb-Scarlett.HiFi__Line__sink.monitor", properties: { "device.class": "sound" } }
    ]

    readonly property var sources: [
        { index: 1, name: "alsa_output.pci-hdmi.monitor", description: "Monitor of HDMI 5", mute: false,
          volume: stereo(65536), monitor_source: "alsa_output.pci-hdmi", properties: { "device.class": "monitor" } },
        { index: 7, name: "alsa_input.usb-Scarlett.HiFi__Mic1__source", description: "Scarlett 2i2 Input 1", mute: false,
          volume: { mono: { value: 32768, value_percent: "50%" } }, monitor_source: "", properties: { "device.class": "sound" } }
    ]

    function test_auto_reads_pulseaudio_only_when_it_is_pulseaudio_itself() {
        compare(PactlState.backendFor("auto", "pulseaudio"), "pulse");
        compare(PactlState.backendFor("auto", "PulseAudio (on PipeWire 1.6.9)"), "pipewire");
        compare(PactlState.backendFor("auto", ""), "pipewire");
        compare(PactlState.backendFor("auto", undefined), "pipewire");
    }

    function test_a_setting_holds_whatever_answers() {
        compare(PactlState.backendFor("pipewire", "pulseaudio"), "pipewire");
        compare(PactlState.backendFor("pulse", "PulseAudio (on PipeWire 1.6.9)"), "pulse");
        compare(PactlState.backendFor("pulse", ""), "pulse");
    }

    function test_server_name() {
        compare(PactlState.serverName(JSON.stringify(info)), "pulseaudio");
        compare(PactlState.serverName(""), "");
        compare(PactlState.serverName("pactl: unrecognized option '-f'"), "");
    }

    function test_parse_reads_defaults_and_levels() {
        const s = PactlState.parse(read(info, sinks, sources));
        compare(s.server, "pulseaudio");
        compare(s.defaultSink, "alsa_output.usb-Scarlett.HiFi__Line__sink");
        compare(s.sinks.length, 2);
        compare(s.sinks[0].description, "HDMI 5");
        fuzzyCompare(s.sinks[0].volume, 0.73, 0.0001);
        compare(s.sinks[1].volume, 1);
        compare(s.sinks[1].muted, true);
    }

    // On a sink, monitor_source is its own monitor -- it is not one.
    function test_monitors_are_not_microphones_but_every_sink_is_an_output() {
        const s = PactlState.parse(read(info, sinks, sources));
        compare(s.sources.length, 1);
        compare(s.sources[0].name, "alsa_input.usb-Scarlett.HiFi__Mic1__source");
        compare(s.sources[0].volume, 0.5);
    }

    function test_nobody_answering_is_no_state() {
        compare(PactlState.parse(""), null);
        compare(PactlState.parse("@info\n@sinks\n@sources\n"), null);
    }

    // The server is there but a list is not readable: no devices, not a
    // stale or a broken state.
    function test_an_unreadable_list_is_an_empty_one() {
        const s = PactlState.parse(["@info", JSON.stringify(info), "@sinks", "garbage", "@sources"].join("\n"));
        compare(s.sinks.length, 0);
        compare(s.sources.length, 0);
    }

    function test_level_and_its_argument_round_trip() {
        compare(PactlState.level({}), 0);
        compare(PactlState.level(undefined), 0);
        compare(PactlState.volumeArg(0.73), "47841");
        compare(PactlState.volumeArg(1.5), "98304");
        compare(PactlState.volumeArg(-0.2), "0");
        fuzzyCompare(PactlState.level(stereo(Number(PactlState.volumeArg(0.42)))), 0.42, 0.0001);
    }

    // Every pactl this shell runs is a client coming and going; reading on
    // those would read for ever.
    function test_only_devices_and_defaults_are_worth_a_read() {
        verify(PactlState.relevant("Event 'change' on sink #64"));
        verify(PactlState.relevant("Event 'new' on source #70"));
        verify(PactlState.relevant("Event 'change' on server #4294967295"));
        verify(PactlState.relevant("Event 'change' on card #52"));
        verify(!PactlState.relevant("Event 'new' on client #144"));
        verify(!PactlState.relevant("Event 'change' on sink-input #12"));
        verify(!PactlState.relevant("Event 'remove' on source-output #3"));
    }
}

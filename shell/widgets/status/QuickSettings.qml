pragma ComponentBehavior: Bound

// Quick settings: the switches and sliders people reach for every day, as the
// design draws them -- a grid of tiles, or rows when dense -- with Wi-Fi and
// Bluetooth a page away.
//
// Everything goes through the services the single widgets use, so a switch
// here and on the volume widget are the same switch. Whatever needs more than
// a switch -- a VPN to set up, a device to pair -- opens Plasma's own applet
// or System Settings, rather than a lesser copy of either.
//
// This file is which page is showing and the slide between them. Each page is
// a file of its own -- MainPage, with its TileGrid, and one per page behind
// it -- and each is handed the widget, whose `page` says which is up.

import QtQuick
import qs.domain.status
import qs.domain.status.icons

Item {
    id: qs

    required property var widget

    implicitWidth: 384
    implicitHeight: (pages.item as Item)?.implicitHeight ?? 0

    Loader {
        id: pages
        width: parent.width
        sourceComponent: qs.widget.page === "wifi" ? wifiPage
                       : qs.widget.page === "ethernet" ? ethernetPage
                       : qs.widget.page === "bluetooth" ? bluetoothPage
                       : qs.widget.page === "volume" ? volumePage
                       : qs.widget.page === "microphone" ? microphonePage
                       : qs.widget.page === "brightness" ? brightnessPage
                       : mainPage
        onLoaded: slide.restart()

        NumberAnimation {
            id: slide
            target: pages
            property: "x"
            from: qs.widget.page === "main" ? -18 : 18
            to: 0
            duration: 170
            easing.type: Easing.OutCubic
        }
    }

    Component {
        id: mainPage
        MainPage { widget: qs.widget }
    }

    Component {
        id: wifiPage
        WifiPage { widget: qs.widget }
    }

    Component {
        id: ethernetPage
        EthernetPage { widget: qs.widget }
    }

    Component {
        id: bluetoothPage
        BluetoothPage { widget: qs.widget }
    }

    Component {
        id: brightnessPage
        BrightnessPage { widget: qs.widget }
    }

    // Sound and the microphone are one page, told which node it is about.
    Component {
        id: volumePage

        LevelPage {
            widget: qs.widget
            title: "Sound"
            glyph: AudioStatus.glyph
            devices: AudioStatus.sinks
            current: AudioStatus.sink
            volume: AudioStatus.volume
            muted: AudioStatus.muted
            emptyText: "No sound output."
            onSetLevel: value => AudioStatus.setVolume(value)
            onSetMuted: value => { if (value !== AudioStatus.muted) AudioStatus.toggleMute(); }
            onUse: node => AudioStatus.useSink(node)
        }
    }

    Component {
        id: microphonePage

        LevelPage {
            widget: qs.widget
            title: "Microphone"
            glyph: StatusIcons.micGlyph(AudioStatus.micVolume, AudioStatus.micMuted)
            devices: AudioStatus.sources
            current: AudioStatus.source
            volume: AudioStatus.micVolume
            muted: AudioStatus.micMuted
            emptyText: "No input device."
            onSetLevel: value => AudioStatus.setMicVolume(value)
            onSetMuted: value => { if (value !== AudioStatus.micMuted) AudioStatus.toggleMicMute(); }
            onUse: node => AudioStatus.useSource(node)
        }
    }
}

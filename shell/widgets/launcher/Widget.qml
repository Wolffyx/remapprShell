// The start button.
//
// It knows nothing about which launcher will open -- that is
// LauncherService's decision, made from configuration. Adding a provider never
// touches this file.

import QtQuick
import qs.ui.primitives
import qs.domain.theme
import qs.domain.launcher

BarWidget {
    id: root

    readonly property string iconName: root.widgetConfig?.icon ?? "start-here-kde"
    // A Material Symbols name; cleared, the theme icon above is drawn instead.
    readonly property string glyph: root.widgetConfig?.glyph ?? "blur_on"
    readonly property string labelText: root.widgetConfig?.label ?? ""

    wantsHover: true

    // A button with a label has already said what it is.
    tooltip: root.labelText.length > 0 ? "" : "Applications"

    // The built-in launcher draws in one of our own windows, so it gets a
    // popout anchored to this button. Every other provider is its own process
    // and positions itself, so there is nothing to anchor.
    popout: LauncherService.active.embedded ? popoutComponent : null

    readonly property Component popoutComponent: Component {
        LauncherPanel {}
    }

    popoutVisible: LauncherService.active.visible
                   && LauncherService.active.embedded
                   && LauncherService.builtin.shownOn === root.screenName

    // The built-in launcher is a search field; it is useless without the
    // keyboard.
    popoutGrabsFocus: true

    implicitWidth: button.implicitWidth
    implicitHeight: button.implicitHeight

    function handleActivate(button) {
        // Tell the provider which screen this button is on, so the popout is
        // built there and only there.
        if (LauncherService.active === LauncherService.builtin && !LauncherService.builtin.visible)
            LauncherService.builtin.openOn(root.screenName, "apps");
        else
            LauncherService.toggle("apps");
    }

    // A tile in the accent, as the design draws the start button. Icon only
    // down the side of the screen, where a word would be wider than the
    // panel.
    BarButton {
        id: button
        thickness: root.bar?.thickness ?? 40
        vertical: !(root.bar?.horizontal ?? true)
        hovered: root.hovered
        active: LauncherService.active.visible
        accent: true
        size: Math.max(24, Math.round(46 * root.unit))
        glyph: root.glyph
        fallback: root.iconName
        glyphSize: Math.max(18, Math.round(26 * root.unit))
        text: root.labelText
    }
}

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
    popout: LauncherService.active === LauncherService.builtin ? popoutComponent : null

    readonly property Component popoutComponent: Component {
        StartMenu { provider: LauncherService.builtin }
    }

    // The start menu, not the search: that one is drawn over the screen.
    popoutVisible: root.openHere

    // From the button, not around it: the menu is many times wider than the
    // start button, so centring it on the button and then pushing it back on
    // screen put it somewhere that read as belonging to nothing.
    popoutAlign: "start"

    // The two-pane menu draws its own edges, to the card's.
    popoutPadding: LauncherService.builtin.layout === "twopane" ? 0 : 22

    // The built-in launcher is a search field; it is useless without the
    // keyboard.
    popoutGrabsFocus: true

    implicitWidth: button.implicitWidth
    implicitHeight: button.implicitHeight

    // Whether the menu is up *here*. Anywhere else -- the other monitor, or
    // the search rather than the menu -- and this button's job is still to
    // put the menu on this screen.
    readonly property bool openHere: LauncherService.active === LauncherService.builtin
                                     && LauncherService.builtin.visible
                                     && LauncherService.builtin.mode === "apps"
                                     && LauncherService.builtin.shownOn === root.screenName

    function handleActivate(button) {
        if (LauncherService.active !== LauncherService.builtin) {
            LauncherService.toggle("apps");
            return;
        }
        // Tell the provider which screen this button is on, so the popout is
        // built there and only there. Clicking this screen's button always
        // ends with the menu on this screen, or gone -- never open on the
        // monitor the pointer is not on.
        if (root.openHere)
            LauncherService.builtin.close();
        else
            LauncherService.builtin.openOn(root.screenName, "apps");
    }

    // The panel closes popouts by calling this. Assigning to `popoutVisible`
    // would replace the binding below with a constant, and the start menu
    // would never open again -- which is what a click outside it used to do.
    function closePopout() {
        if (LauncherService.active === LauncherService.builtin)
            LauncherService.builtin.close();
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

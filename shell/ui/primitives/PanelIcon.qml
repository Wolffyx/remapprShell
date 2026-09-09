// An icon from the system icon theme.
//
// Resolved through the XDG theme rather than bundled with the shell, so icons
// follow whatever the user has set in System Settings and there is no second
// icon set to maintain.

import QtQuick
import Quickshell
import Quickshell.Widgets

IconImage {
    id: root

    // Falls back to a name that exists in every theme, so a missing icon is a
    // blank-looking glyph rather than an empty hole in the panel.
    property string iconName: ""
    property string fallbackName: "application-x-executable"

    implicitSize: 18

    source: {
        if (root.iconName.length > 0 && Quickshell.hasThemeIcon(root.iconName))
            return Quickshell.iconPath(root.iconName);
        return Quickshell.iconPath(root.fallbackName, true);
    }
}

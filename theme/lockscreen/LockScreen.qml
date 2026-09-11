/*
    SPDX-License-Identifier: GPL-3.0-or-later

    The lock screen, as Plasma's greeter loads it.

    kscreenlocker_greet draws the file its shell package names as
    `lockscreenmainscript` -- contents/lockscreen/LockScreen.qml of whichever
    package plasmashell is on, falling back to Plasma's own. It is installed
    into this project's shell packages by `lockscreen enable` and by nothing
    else, and that refuses until `lockscreen try` has unlocked this exact
    build with the person's own password. `lockscreen disable` takes it out;
    Plasma's comes back at the next lock.

    What the greeter hands over arrives here, as context properties, and goes
    down as plain properties -- so Unlock.qml can be tested with a fake, and
    nothing below this file reaches past its own properties.

    If this greeter lacks something unlocking depends on, Plasma's own lock
    screen is drawn instead. The greeter already falls back when a file
    fails to load; a lock screen that loads and cannot unlock is the failure
    it cannot see, so this checks for it.
*/
// Everything read unqualified here is a greeter context property, which the
// linter cannot see.
// qmllint disable unqualified
import QtCore
import QtQuick
import org.kde.plasma.private.sessions

Item {
    id: root

    // Set by the greeter once the first frame is on screen.
    property bool viewVisible: false

    // What the greeter provides. Properties so that a harness can hand in
    // its own; the greeter's are the defaults.
    property var greeterAuthenticator: typeof authenticator !== "undefined" ? authenticator : null
    property string greeterUserName: typeof kscreenlocker_userName !== "undefined" ? kscreenlocker_userName : ""
    property string greeterUserImage: typeof kscreenlocker_userImage !== "undefined" ? kscreenlocker_userImage : ""
    property var greeterConfig: typeof config !== "undefined" ? config : null
    property Item greeterWallpaper: typeof wallpaper !== "undefined" ? wallpaper : null
    readonly property int greeterInterface: typeof org_kde_plasma_screenlocker_greeter_interfaceVersion !== "undefined"
        ? org_kde_plasma_screenlocker_greeter_interfaceVersion : 0

    // What this lock screen cannot do without, from an authenticator.
    // `lockscreen check` asks it of the greeter's real one, which it only
    // looks at and never uses.
    function lacks(auth) {
        if (!auth)
            return ["the authenticator"];
        const l = ["startAuthenticating", "respond"].filter(m => typeof auth[m] !== "function");
        if (!("hadPrompt" in auth))
            l.push("hadPrompt");
        return l;
    }

    readonly property var missing: {
        const l = root.lacks(root.greeterAuthenticator);
        if (root.greeterInterface < 2)
            l.push("interface version 2");
        return l;
    }

    readonly property url plasmaLockScreen: StandardPaths.locate(StandardPaths.GenericDataLocation,
        "plasma/shells/org.kde.plasma.desktop/contents/lockscreen/LockScreen.qml")

    readonly property bool drawOurs: root.missing.length === 0 || root.plasmaLockScreen.toString() === ""

    // Wakes the prompt as a key would. For a harness drawing a picture of it.
    function wake() {
        // The loaded item's type is not known to the linter.
        // qmllint disable missing-property
        if (oursLoader.item)
            oursLoader.item.unlock.poke();
        // qmllint enable missing-property
    }

    implicitWidth: 800
    implicitHeight: 600

    LayoutMirroring.enabled: Application.layoutDirection === Qt.RightToLeft
    LayoutMirroring.childrenInherit: true

    // The one line `lockscreen check` looks for: this file loaded, in this
    // greeter, and found what it needs.
    Component.onCompleted: {
        if (root.missing.length === 0)
            console.info("lock screen: ready");
        else if (root.drawOurs)
            console.warn("lock screen: this greeter lacks", root.missing.join(", "),
                         "and Plasma's own lock screen was not found; drawing ours anyway");
        else
            console.warn("lock screen: this greeter lacks", root.missing.join(", "),
                         "-- drawing Plasma's own lock screen instead");
    }

    SessionManagement {
        id: sessionManagement
    }

    Loader {
        id: oursLoader
        anchors.fill: parent
        active: root.drawOurs
        focus: true
        sourceComponent: Item {
            property alias unlock: unlock

            Unlock {
                id: unlock
                authenticator: root.greeterAuthenticator
                onFinished: Qt.quit()
            }

            LockUi {
                anchors.fill: parent
                focus: true
                unlock: unlock
                userName: root.greeterUserName
                userImage: root.greeterUserImage
                wallpaper: root.greeterWallpaper
                config: root.greeterConfig
                session: sessionManagement
            }
        }
    }

    Loader {
        anchors.fill: parent
        active: !root.drawOurs
        focus: true
        source: root.plasmaLockScreen
        onLoaded: item.viewVisible = Qt.binding(() => root.viewVisible)
    }
}

/*
    SPDX-License-Identifier: GPL-3.0-or-later

    What every lock screen style is.

    LockUi.qml owns the machinery -- the wallpaper, waking, the on-screen
    keyboard, the shake, the OSD -- and draws none of it. A style owns the
    arrangement: where the clock is, what the password field looks like,
    whether there is a wallpaper behind it at all. One is loaded, by name,
    from `Options.style`.

    Two properties go back up. `promptField` is the LockPrompt the style
    built, which the frame needs for focus, for the virtual keyboard and for
    the shake; `promptBlock` is whatever must stay above the keyboard when it
    comes up. A style that sets neither still draws -- it simply cannot be
    typed into, which `lockscreen check` reports rather than discovers at a
    locked screen.

    What a style may draw is limited by where it runs. The greeter is its own
    process with none of this shell's session: no weather, no calendar, no
    notifications, no network name. The designs these styles come from show
    some of those. They are left out rather than filled with something that
    looks like an answer.
*/
pragma ComponentBehavior: Bound

import QtQuick

Item {
    id: style

    // The frame. Read for `unlock`, `userName`, `userImage`, `session`,
    // `wallpaper`, `unit`, `edge` and `setting()` -- a var rather than the
    // LockUi type, because LockUi loads this and the cycle is not worth the
    // two files it would take to break.
    required property var ui

    // The password field this style built, for the frame to focus, shake and
    // keep above the on-screen keyboard. Typed, so that a style handing back
    // the wrong item is a warning here rather than a lock screen that cannot
    // be typed into.
    property LockPrompt promptField: null

    // What the on-screen keyboard must not cover.
    property Item promptBlock: null

    // Whether the frame should blur the wallpaper behind this style. The
    // glass styles want it; the ones that make the picture the design do not,
    // and the ones with no picture at all have nothing to blur.
    property bool blursWallpaper: true

    // Whether the frame should lay its darkening gradient over the wallpaper.
    // A style that draws its own background does not want a second one.
    property bool scrimsWallpaper: true

    // No slides, no rolling digits, no shutter. The accessible style sets it
    // from its own reduced-motion switch; the frame reads it for the shutter.
    property bool reduceMotion: false

    // Where the frame puts the lockout countdown, from the top, for a style
    // whose own bar is where the default would land. Negative is the default.
    property real toastY: -1

    anchors.fill: parent
}

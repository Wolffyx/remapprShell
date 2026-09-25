/*
    SPDX-License-Identifier: GPL-3.0-or-later

    The accessible style's focus ring: a ring outside whatever has the
    keyboard focus, clear of it by a gap so that it shows around a filled
    button as well as an empty one. Put inside the thing it rings.
*/
pragma ComponentBehavior: Bound

import QtQuick

Rectangle {
    id: ring

    required property Rectangle target
    required property AccessibleLook look

    anchors.fill: parent
    anchors.margins: -(ring.look.ringGap + ring.look.thick)
    visible: ring.target.activeFocus
    radius: ring.target.radius + ring.look.ringGap + ring.look.thick
    color: "transparent"
    border.width: ring.look.thick
    border.color: ring.look.acc
}

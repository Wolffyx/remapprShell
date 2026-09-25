/*
    SPDX-License-Identifier: GPL-3.0-or-later

    The secure style's right rail, which says what is going on with this
    lock. Where the design has device posture, journald, VPN and Wi-Fi and
    "managed by IT" -- none of which the greeter can read -- it has the ways
    in PAM offers here, the log of this lock (kept by SecureLog), the layout
    and the battery (SecureStatusTiles), and at the foot a line on what the
    list is.
*/
pragma ComponentBehavior: Bound

import QtQuick

Rectangle {
    id: rail

    required property var ui
    required property SecurePalette colours
    property real unit: 1

    // SecureLog's rows, newest first.
    required property ListModel entries

    function px(v: real): int {
        return Math.round(v * rail.unit);
    }

    color: rail.colours.railGround

    component Heading: Item {
        id: heading

        property string label: ""
        property string aside: ""
        property color asideColor: rail.colours.sub

        width: parent?.width ?? 0
        height: headingText.implicitHeight

        Text {
            id: headingText
            text: heading.label
            textFormat: Text.PlainText
            font.family: "JetBrains Mono"
            font.pixelSize: rail.px(12)
            font.letterSpacing: 0.14 * rail.px(12)
            color: rail.colours.mut
        }

        Text {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: heading.aside
            textFormat: Text.PlainText
            font.family: "Rubik"
            font.pixelSize: rail.px(13)
            color: heading.asideColor
        }
    }

    component Way: Item {
        id: way

        property string glyph: ""
        property string label: ""
        property bool offered: false

        width: parent?.width ?? 0
        height: rail.px(44)

        SymbolText {
            id: wayGlyph
            anchors.verticalCenter: parent.verticalCenter
            symbol: way.offered ? "check_circle" : "do_not_disturb_on"
            font.pixelSize: rail.px(20)
            color: way.offered ? rail.colours.good : "#5d646c"
        }

        Text {
            anchors.left: wayGlyph.right
            anchors.leftMargin: rail.px(12)
            anchors.verticalCenter: parent.verticalCenter
            text: way.label
            textFormat: Text.PlainText
            font.family: "Rubik"
            font.pixelSize: rail.px(15)
            color: way.offered ? rail.colours.ink : rail.colours.mut
        }

        SymbolText {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            symbol: way.glyph
            font.pixelSize: rail.px(18)
            color: rail.colours.faint
        }

        Rectangle {
            anchors.bottom: parent.bottom
            width: parent.width
            height: 1
            color: "#1d2126"
        }
    }

    Rectangle {
        width: 1
        height: parent.height
        color: "#20242a"
    }

    Column {
        x: rail.px(64)
        y: rail.px(60)
        width: parent.width - 2 * x
        spacing: rail.px(30)

        // Where the design has device posture: the ways in, which the
        // greeter does know.
        Column {
            width: parent.width
            spacing: rail.px(12)

            Heading {
                label: "AUTHENTICATION"
                aside: "offered by PAM here"
            }

            Column {
                width: parent.width

                Way {
                    label: "Password"
                    glyph: "password"
                    offered: true
                }

                Way {
                    label: "Security key or smartcard"
                    glyph: "usb"
                    offered: rail.ui.unlock.hasSmartcard
                }

                Way {
                    label: "Fingerprint"
                    glyph: "fingerprint"
                    offered: rail.ui.unlock.hasFingerprint
                }
            }
        }

        // Where the design has journald: this lock, as this greeter saw it.
        Column {
            width: parent.width
            spacing: rail.px(12)

            Heading {
                label: "THIS LOCK"
                aside: "since this lock · this greeter"
            }

            Column {
                width: parent.width

                Repeater {
                    model: rail.entries

                    Item {
                        id: entry

                        required property string t
                        required property string what
                        required property string how
                        required property string tint

                        width: parent.width
                        height: rail.px(38)

                        Rectangle {
                            id: dot
                            anchors.verticalCenter: parent.verticalCenter
                            width: rail.px(8)
                            height: width
                            radius: width / 2
                            color: entry.tint
                        }

                        Text {
                            id: when
                            anchors.left: dot.right
                            anchors.leftMargin: rail.px(14)
                            anchors.verticalCenter: parent.verticalCenter
                            width: rail.px(72)
                            text: entry.t
                            textFormat: Text.PlainText
                            font.family: "JetBrains Mono"
                            font.pixelSize: rail.px(13)
                            color: rail.colours.sub
                        }

                        Text {
                            anchors.left: when.right
                            anchors.leftMargin: rail.px(10)
                            anchors.right: how.left
                            anchors.rightMargin: rail.px(14)
                            anchors.verticalCenter: parent.verticalCenter
                            text: entry.what
                            textFormat: Text.PlainText
                            elide: Text.ElideRight
                            font.family: "Rubik"
                            font.pixelSize: rail.px(15)
                            color: rail.colours.ink
                        }

                        Text {
                            id: how
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            text: entry.how
                            textFormat: Text.PlainText
                            font.family: "Rubik"
                            font.pixelSize: rail.px(13)
                            color: rail.colours.sub
                        }
                    }
                }
            }
        }

        SecureStatusTiles {
            width: parent.width
            ui: rail.ui
            colours: rail.colours
            unit: rail.unit
        }
    }

    // The design's "managed by IT" line, said of what this screen is.
    Row {
        x: rail.px(64)
        width: parent.width - 2 * x
        y: parent.height - height - rail.px(60)
        spacing: rail.px(12)

        SymbolText {
            id: policyGlyph
            symbol: "policy"
            font.pixelSize: rail.px(18)
            color: rail.colours.mut
        }

        Text {
            width: parent.width - policyGlyph.width - parent.spacing
            text: "This list is kept by the lock screen for this lock only and ends with it. "
                + "Nothing here is written anywhere; PAM decides what is allowed and when."
            textFormat: Text.PlainText
            wrapMode: Text.Wrap
            lineHeight: 1.3
            font.family: "Rubik"
            font.pixelSize: rail.px(13)
            color: rail.colours.mut
        }
    }
}

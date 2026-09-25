/*
    SPDX-License-Identifier: GPL-3.0-or-later

    One Material Symbols icon, by name -- or nothing, where the font is not
    installed. Drawn as Text with the name in `symbol`, not `text`, so a style
    cannot set the name straight onto the Text and bring the word back.
*/
import QtQuick

Text {
    property string symbol: ""

    text: Options.hasSymbols ? symbol : ""
    font.family: "Material Symbols Rounded"
}

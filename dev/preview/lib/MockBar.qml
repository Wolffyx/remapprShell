// A stand-in for the bar a panel surface or a widget is handed: the
// properties they read of it, with no panel window behind them.
//
// Copied beside the target by preview.sh. A floating or island bar stands
// off the screen's edge, and its extent is that gap and its thickness.
import QtQuick

QtObject {
    property string screenName: "PREVIEW"
    property string position: "bottom"
    property bool horizontal: true
    property int thickness: 64
    property var screenObject: null
    property string style: "full"
    property int spacing: 6
    property int iconSize: 19
    property int edgeGap: style === "full" ? 0 : 14
    property int extent: thickness + edgeGap
    property Item openPopout: null
}

// What a preview is drawn on: a plain gradient, dusk in the dark and dawn in
// the light, so a surface's own translucency has something to show through.
//
// Copied beside the target by preview.sh. Three stops across by default,
// which is what most targets want; a target that wants its stage to run down,
// or to have no middle, or other colours, says so here rather than keeping a
// gradient of its own.
import QtQuick
import qs.domain.theme

Rectangle {
    id: stage

    property int orientation: Gradient.Horizontal

    property color startDark: "#20283f"
    property color startLight: "#c8d5ef"

    // With no middle, the middle stop sits on the last one and draws nothing.
    property bool middle: true
    property real middleAt: 0.45
    property color middleDark: "#2c2b3d"
    property color middleLight: "#e6dcd2"

    property color endDark: "#3b3138"
    property color endLight: "#f2d7c4"

    gradient: Gradient {
        orientation: stage.orientation
        GradientStop { position: 0; color: Theme.dark ? stage.startDark : stage.startLight }
        GradientStop {
            position: stage.middle ? stage.middleAt : 1
            color: !stage.middle ? (Theme.dark ? stage.endDark : stage.endLight)
                                 : (Theme.dark ? stage.middleDark : stage.middleLight)
        }
        GradientStop { position: 1; color: Theme.dark ? stage.endDark : stage.endLight }
    }
}

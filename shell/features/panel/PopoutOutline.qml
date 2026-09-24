// A popout's card and the neck it hangs from, drawn as one shape: the fill,
// and one border that runs round the card and down both sides of the neck
// without a join anywhere. See Tail for the geometry.
//
// It replaces the card's own background and border rather than adding a neck
// to them: the card is translucent, so a neck laid over it doubles the tint
// where the two meet, and the card's border would cross the top of the neck
// as a seam.
//
// Sized as the card; the neck is drawn outside that, beyond the card's edge
// on the panel's side. Nothing here runs per frame: the path is worked out
// again only when the card's size or the neck's place changes.

import QtQuick
import QtQuick.Shapes
import qs.domain.panel

Shape {
    id: root

    // Tail.neck(), for this card.
    required property var neck
    required property string edge
    required property color fill
    required property color border

    readonly property var outline: Tail.outline(root.neck, root.width, root.height, root.edge)

    // Antialiased on the graphics card rather than by drawing into a texture
    // first: the edges stay sharp at any scale and there is no layer to keep.
    preferredRendererType: Shape.CurveRenderer

    ShapePath {
        fillColor: root.fill
        strokeWidth: -1
        PathSvg { path: root.outline.fill }
    }

    // Open across the neck's foot, which rests on the panel's own edge.
    ShapePath {
        fillColor: "transparent"
        strokeColor: root.border
        strokeWidth: 1
        capStyle: ShapePath.FlatCap
        joinStyle: ShapePath.RoundJoin
        PathSvg { path: root.outline.stroke }
    }
}

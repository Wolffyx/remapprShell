// The neck of a popout that hangs from its widget, as a region of its window:
// the rectangle it and its two curves occupy, with the ellipses the curves are
// quarters of cut out of it -- the shape drawn, to within a pixel, which is
// all a region can say. See Tail.
//
// One per use. A region lists another as one of its parts, and the same part
// in two lists -- the input region and the blur -- would be two parents
// sharing one child.

import Quickshell

Region {
    id: root

    // Tail.box() and Tail.hollows(), in the window's coordinates.
    required property var box
    required property var hollows

    x: Math.round(root.box.x)
    y: Math.round(root.box.y)
    width: Math.round(root.box.width)
    height: Math.round(root.box.height)

    Region {
        shape: RegionShape.Ellipse
        intersection: Intersection.Subtract
        x: Math.round(root.hollows[0].x)
        y: Math.round(root.hollows[0].y)
        width: Math.round(root.hollows[0].width)
        height: Math.round(root.hollows[0].height)
    }

    Region {
        shape: RegionShape.Ellipse
        intersection: Intersection.Subtract
        x: Math.round(root.hollows[1].x)
        y: Math.round(root.hollows[1].y)
        width: Math.round(root.hollows[1].width)
        height: Math.round(root.hollows[1].height)
    }
}

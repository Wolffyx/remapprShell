import QtQuick
import QtTest
import qs.domain.surfaces.place

TestCase {
    name: "Place"

    // The machine this was written on: a 2560x1440 monitor at the origin and
    // a portrait one beside it, which is why the second screen's x is 2560 --
    // KWin numbers every screen in one space and a layer surface is placed in
    // its own screen's.
    readonly property var wide: ({ x: 0, y: 0, width: 2560, height: 1440 })
    readonly property var tall: ({ x: 2560, y: 0, width: 1440, height: 2560 })

    function test_it_opens_under_the_pointer() {
        compare(Place.atPointer(400, 300, wide, 380, 400, 8), { x: 408, y: 308 });
    }

    function test_a_second_screens_origin_comes_off_first() {
        // The same place on the portrait monitor, in its own coordinates.
        compare(Place.atPointer(2600, 300, tall, 380, 400, 8), { x: 48, y: 308 });
    }

    function test_near_an_edge_it_flips_to_the_other_side() {
        // Close to the right: it opens to the left of the pointer.
        compare(Place.atPointer(2500, 300, wide, 380, 400, 8).x, 2500 - 380 - 8);
        // Close to the bottom: above it.
        compare(Place.atPointer(400, 1400, wide, 380, 400, 8).y, 1400 - 400 - 8);
        // And in a corner, both.
        const corner = Place.atPointer(2550, 1430, wide, 380, 400, 8);
        compare(corner, { x: 2162, y: 1022 });
    }

    function test_it_is_never_off_the_screen() {
        // A pointer in the top-left corner has no room on the other side
        // either: it is pushed inside and left there.
        const tight = Place.atPointer(4, 4, wide, 380, 400, 8);
        verify(tight.x >= 0 && tight.y >= 0);
        // A surface taller than the screen still starts on it.
        const huge = Place.atPointer(400, 300, wide, 380, 4000, 8);
        compare(huge.y, 0);
    }

    // Beside a panel: centred on the button, clear of the panel by the gap.
    function test_beside_a_panel() {
        compare(Place.atEdge("bottom", 1000, 40, wide, 200, 60, 8), { x: 900, y: 1440 - 40 - 8 - 60 });
        compare(Place.atEdge("top", 1000, 26, wide, 200, 60, 8), { x: 900, y: 34 });
        compare(Place.atEdge("left", 700, 48, wide, 200, 60, 8), { x: 56, y: 670 });
        compare(Place.atEdge("right", 700, 48, wide, 200, 60, 8), { x: 2560 - 56 - 200, y: 670 });
    }

    // A button at the very end of the edge does not push it off the screen,
    // and an edge nobody knows is the bottom.
    function test_beside_a_panel_stays_on_the_screen() {
        compare(Place.atEdge("bottom", 2550, 40, wide, 200, 60, 8).x, 2360);
        compare(Place.atEdge("top", 10, 26, wide, 200, 60, 8).x, 0);
        compare(Place.atEdge("sideways", 1000, 40, wide, 200, 60, 8),
                Place.atEdge("bottom", 1000, 40, wide, 200, 60, 8));
    }

    function test_which_screen_the_pointer_is_on() {
        compare(Place.contains(wide, 400, 300), true);
        compare(Place.contains(wide, 2600, 300), false);
        compare(Place.contains(tall, 2600, 300), true);
        compare(Place.contains(tall, 2560, 0), true);
        compare(Place.contains(tall, 4000, 0), false);
    }
}

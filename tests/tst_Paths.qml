// Tests for turning a filesystem path into a URL.
//
// A bare path is not a URL, and Qt resolves one against the base URL of the
// component that uses it -- inside qrc: for a type from a module. A screenshot
// notification carried an absolute path straight off the bus, and the icon
// came out as "qrc:/home/..." and drew nothing at all.

import QtQuick
import QtTest
import qs.core

TestCase {
    name: "Paths"

    function test_an_absolute_path_becomes_a_file_url() {
        compare(Paths.fileUrl("/home/someone/Pictures/shot.png"),
                "file:///home/someone/Pictures/shot.png");
    }

    function test_a_url_that_has_a_scheme_is_left_alone() {
        compare(Paths.fileUrl("file:///home/someone/shot.png"),
                "file:///home/someone/shot.png");
        compare(Paths.fileUrl("image://icon/dialog-information"),
                "image://icon/dialog-information");
    }

    function test_a_theme_icon_name_is_not_a_path() {
        compare(Paths.fileUrl("dialog-information"), "dialog-information");
    }

    function test_nothing_stays_nothing() {
        compare(Paths.fileUrl(""), "");
        compare(Paths.fileUrl(undefined), "");
        compare(Paths.fileUrl(null), "");
    }

    // A directory with a space in it is ordinary on a desktop, and an
    // unencoded space does not survive being parsed as a URL.
    function test_segments_are_encoded() {
        compare(Paths.fileUrl("/home/someone/My Pictures/a shot.png"),
                "file:///home/someone/My%20Pictures/a%20shot.png");
    }

    function test_a_hash_does_not_start_a_fragment() {
        compare(Paths.fileUrl("/tmp/shot #2.png"), "file:///tmp/shot%20%232.png");
    }
}

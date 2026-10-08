// Tests for turning a filesystem path into a URL, and for where this machine
// keeps things.
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

    // Worked out at startup, not written in at install (2026-10-08). Whatever
    // the machine says, each is a plain absolute path -- StandardPaths answers
    // in file: URLs, and one of those handed to a FileView is no file at all.
    function test_where_things_are_is_a_plain_absolute_path() {
        const dirs = [Paths.home, Paths.xdgConfigHome, Paths.xdgDataHome, Paths.xdgStateHome,
                      Paths.configDir, Paths.dataDir, Paths.stateDir, Paths.qsConfigDir, Paths.ctlBin];
        for (const d of dirs) {
            verify(d.startsWith("/"), d);
            verify(!d.includes("file:"), d);
            verify(!d.endsWith("/"), d);
        }
    }

    // The rules scripts/lib/brand.sh has, so the shell and the CLI agree.
    function test_the_project_directories_are_the_xdg_ones_and_the_slug() {
        compare(Paths.configDir, `${Paths.xdgConfigHome}/${Branding.slug}`);
        compare(Paths.dataDir, `${Paths.xdgDataHome}/${Branding.slug}`);
        compare(Paths.stateDir, `${Paths.xdgStateHome}/${Branding.slug}`);
        compare(Paths.qsConfigDir, `${Paths.xdgConfigHome}/quickshell/${Branding.slug}`);
        compare(Paths.ctlBin, `${Paths.home}/.local/bin/${Branding.ctlName}`);
    }
}

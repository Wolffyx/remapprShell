// Tests for the words the status widgets share: a percentage, and a time left.

import QtQuick
import QtTest
import qs.domain.status.icons

TestCase {
    name: "StatusText"

    function test_percent() {
        compare(StatusText.percent(0.456), "46%");
        compare(StatusText.percent(-1), "0%");
    }

    // Zero is UPower for "unknown", never "0 min".
    function test_duration() {
        compare(StatusText.duration(0), "");
        compare(StatusText.duration(20), "1 min");
        compare(StatusText.duration(45 * 60), "45 min");
        compare(StatusText.duration(3600 + 5 * 60), "1 h 05 min");
        compare(StatusText.duration(2 * 3600 - 10), "2 h 00 min");
    }
}

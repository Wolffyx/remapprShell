// Tests for the month grid the clock's calendar draws.

import QtQuick
import QtTest
import qs.domain.calendar

TestCase {
    name: "Calendar"

    // 1 September 2026 is a Tuesday.
    function test_a_monday_week_starts_on_the_last_day_of_august() {
        const w = Calendar.weeks(2026, 8, 1);
        compare(w.length, 6);
        compare(w[0].length, 7);
        compare(w[0][0].month, 7);
        compare(w[0][0].day, 31);
        verify(!w[0][0].inMonth);
        compare(w[0][1].day, 1);
        verify(w[0][1].inMonth);
    }

    function test_a_sunday_week_starts_two_days_earlier() {
        const w = Calendar.weeks(2026, 8, 0);
        compare(w[0][0].day, 30);
        compare(w[0][2].day, 1);
    }

    // A month that starts on the week's first day starts in the first cell.
    function test_a_month_starting_on_the_first_weekday() {
        const w = Calendar.weeks(2026, 1, 0);   // 1 February 2026 is a Sunday
        compare(w[0][0].day, 1);
        verify(w[0][0].inMonth);
    }

    function test_six_rows_always_and_the_next_month_after() {
        const w = Calendar.weeks(2026, 8, 1);
        const last = w[5][6];
        compare(last.month, 9);
        compare(last.day, 11);
        verify(!last.inMonth);
    }

    function test_the_year_turns() {
        compare(Calendar.shift(2026, 11, 1), { year: 2027, month: 0 });
        compare(Calendar.shift(2026, 0, -1), { year: 2025, month: 11 });
        compare(Calendar.shift(2026, 8, 0), { year: 2026, month: 8 });
    }

    function test_weekday_order() {
        compare(Calendar.weekdayOrder(1), [1, 2, 3, 4, 5, 6, 0]);
        compare(Calendar.weekdayOrder(0), [0, 1, 2, 3, 4, 5, 6]);
        compare(Calendar.weekdayOrder(6), [6, 0, 1, 2, 3, 4, 5]);
    }

    function test_today() {
        const now = new Date(2026, 8, 11, 14, 32);
        verify(Calendar.isToday({ year: 2026, month: 8, day: 11 }, now));
        verify(!Calendar.isToday({ year: 2026, month: 7, day: 11 }, now));
    }
}

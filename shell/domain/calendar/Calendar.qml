pragma Singleton

// The arithmetic of a month on a page: which days fill a six-week grid, and
// how to move a month either way. Pure, and a module of its own so the tests
// can load it.
//
// Weeks start on whichever day the locale says -- `firstDay` is 0 for Sunday
// to 6 for Saturday, as QML's Locale.firstDayOfWeek gives it. Six rows,
// always, so the grid does not change height from one month to the next.

import QtQuick

QtObject {
    id: root

    // [[{ year, month, day, inMonth }] x 7] x 6. `month` is 0..11, as Date's.
    function weeks(year, month, firstDay) {
        const first = new Date(year, month, 1);
        const offset = (first.getDay() - (firstDay ?? 1) + 7) % 7;
        const rows = [];
        for (let w = 0; w < 6; w++) {
            const row = [];
            for (let d = 0; d < 7; d++) {
                const date = new Date(year, month, 1 - offset + w * 7 + d);
                row.push({ year: date.getFullYear(), month: date.getMonth(), day: date.getDate(),
                           inMonth: date.getMonth() === month && date.getFullYear() === year });
            }
            rows.push(row);
        }
        return rows;
    }

    // The month `delta` months from year/month.
    function shift(year, month, delta) {
        const d = new Date(year, month + delta, 1);
        return { year: d.getFullYear(), month: d.getMonth() };
    }

    // The days of the week in the order the grid's columns show them.
    function weekdayOrder(firstDay) {
        const f = firstDay ?? 1;
        return [0, 1, 2, 3, 4, 5, 6].map(i => (f + i) % 7);
    }

    function isToday(cell, now) {
        return cell.year === now.getFullYear() && cell.month === now.getMonth() && cell.day === now.getDate();
    }
}

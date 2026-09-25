pragma ComponentBehavior: Bound

// A month on a page: the weekday row and six weeks of days.
//
// Extracted from the clock's popout when the sidebar wanted the same month in
// its day card, and the calendar wanted the weather on its days -- one grid
// drawn twice rather than two that drift apart. The arithmetic is
// qs.domain.calendar's, which is pure and tested; this is only how it looks.
//
// A day can carry a badge -- a small glyph under the number, which is how the
// forecast appears on the calendar. `badgeFor` is a function of a cell
// ({ year, month, day, inMonth }) returning a glyph name, or "" for none;
// leaving it unset draws a plain month.

import QtQuick
import qs.domain.calendar
import qs.domain.theme

Column {
    id: grid

    property var locale: Qt.locale()
    property int firstDay: grid.locale.firstDayOfWeek
    property date now: new Date()
    property int year: grid.now.getFullYear()
    property int month: grid.now.getMonth()

    property real cellHeight: 38
    property real dayDiameter: 34
    property real dayFontSize: 14

    // cell -> glyph name, or "".
    property var badgeFor: null

    // The day last clicked, and the click itself. A grid nobody listens to
    // still highlights what was chosen, which is what makes it usable as a
    // picker without wiring anything up.
    property date selected: new Date(NaN)

    signal picked(var cell)

    readonly property var weeks: Calendar.weeks(grid.year, grid.month, grid.firstDay)

    function isSelected(cell) {
        const s = grid.selected;
        return !isNaN(s.getTime()) && s.getFullYear() === cell.year
            && s.getMonth() === cell.month && s.getDate() === cell.day;
    }

    spacing: 0

    Row {
        width: parent.width

        Repeater {
            model: Calendar.weekdayOrder(grid.firstDay)

            PanelText {
                required property int modelData
                width: grid.width / 7
                height: 28
                horizontalAlignment: Text.AlignHCenter
                text: grid.locale.standaloneDayName(modelData, Locale.NarrowFormat)
                font.pixelSize: 12
                color: Theme.mut
            }
        }
    }

    Repeater {
        model: grid.weeks

        Row {
            id: week
            required property var modelData
            width: grid.width

            Repeater {
                model: week.modelData

                Item {
                    id: cell

                    required property var modelData
                    readonly property bool today: Calendar.isToday(cell.modelData, grid.now)
                    readonly property bool chosen: grid.isSelected(cell.modelData)
                    readonly property string badge: grid.badgeFor ? String(grid.badgeFor(cell.modelData) ?? "") : ""

                    width: grid.width / 7
                    height: grid.cellHeight

                    Rectangle {
                        anchors.centerIn: parent
                        width: grid.dayDiameter
                        height: grid.dayDiameter
                        radius: Theme.radiusOf(grid.dayDiameter / 2)
                        color: cell.today ? Theme.acc
                             : cell.chosen ? Theme.alpha(Theme.acc, 0.22)
                             : hover.hovered ? Theme.alpha(Theme.fg, 0.08) : "transparent"
                    }

                    Column {
                        anchors.centerIn: parent
                        spacing: 0

                        PanelText {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: cell.modelData.day
                            font.pixelSize: grid.dayFontSize
                            color: cell.today ? Theme.accFg : Theme.fg
                            opacity: cell.modelData.inMonth ? 1 : 0.35
                        }

                        Glyph {
                            anchors.horizontalCenter: parent.horizontalCenter
                            visible: cell.badge.length > 0
                            name: cell.badge
                            size: 11
                            color: cell.today ? Theme.accFg : Theme.mut
                            opacity: cell.modelData.inMonth ? 0.9 : 0.35
                        }
                    }

                    HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }
                    TapHandler {
                        onTapped: {
                            grid.selected = new Date(cell.modelData.year, cell.modelData.month, cell.modelData.day);
                            grid.picked(cell.modelData);
                        }
                    }
                }
            }
        }
    }
}

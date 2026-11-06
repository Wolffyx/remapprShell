/*
    SPDX-License-Identifier: GPL-3.0-or-later

    A window as KWin draws it, for Snap Assist to offer. A file of its own so
    that a KWin without WindowThumbnail fails to load this and nothing else:
    the Loader in Assist.qml that holds it shows the window's icon instead.
*/
// KWin's types live in its own process and cannot be resolved by the linter.
// qmllint disable import
import QtQuick
import org.kde.kwin

WindowThumbnail {
}

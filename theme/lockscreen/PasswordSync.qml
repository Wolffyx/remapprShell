/*
    SPDX-License-Identifier: GPL-3.0-or-later

    What has been typed so far, shared by the lock screen on every monitor.
    The greeter draws one view per screen from one QML engine, so a singleton
    is one object for all of them: typing on one screen shows on the others,
    and whichever screen Enter is pressed on sends the whole password.
*/
pragma Singleton

import QtQuick

QtObject {
    property string password
}

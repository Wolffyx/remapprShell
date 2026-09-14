/*
    SPDX-License-Identifier: GPL-3.0-or-later

    Which modifier keys are held right now, for QML.

    QML can read the modifiers carried *by an event*, and nothing else. There
    is no way to ask "is Alt down at this instant", and the window switcher
    needs exactly that.

    Why it needs it: a held shortcut is chosen when the modifier comes up, but
    kglobalaccel reports the release of the *shortcut* -- Tab coming up, not
    Alt. So a commit arriving while the switcher is on screen is ambiguous: it
    means "Alt was released, choose" or "Tab came up, Alt is still down, stay",
    and the two are indistinguishable from timing alone. Asking the keyboard
    settles it.

    `QGuiApplication::queryKeyboardModifiers` is the live state rather than the
    state of the last event, which is the whole point -- on Wayland it is what
    the compositor last told this client, and the switcher holds the keyboard
    exclusively while it is up, so it is told.
*/

#pragma once

#include <QObject>
#include <QtQml/qqmlregistration.h>

class Modifiers : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

public:
    explicit Modifiers(QObject *parent = nullptr);

    // True while Alt or Meta is physically down. Those two and no others:
    // they are the modifiers a held switcher is ever opened with, and the
    // same pair the switcher's own key handler watches for.
    Q_INVOKABLE bool switcherKeyHeld() const;
};

// SPDX-License-Identifier: GPL-3.0-or-later

#include "modifiers.h"

#include <QGuiApplication>

Modifiers::Modifiers(QObject *parent)
    : QObject(parent)
{
}

bool Modifiers::switcherKeyHeld() const
{
    const Qt::KeyboardModifiers held = QGuiApplication::queryKeyboardModifiers();
    return held.testFlag(Qt::AltModifier) || held.testFlag(Qt::MetaModifier);
}

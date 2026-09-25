// SPDX-License-Identifier: GPL-3.0-or-later

#include "lockkeys.h"

#include <KModifierKeyInfo>

LockKeys::LockKeys(QObject *parent)
    : QObject(parent)
    , m_keys(std::make_unique<KModifierKeyInfo>())
{
    // One signal carries every lock there is, so the key it names is what
    // decides which property moved. `locked` is deliberately not read here:
    // the getters ask KModifierKeyInfo itself, so a property and the signal
    // that announced it can never disagree.
    connect(m_keys.get(), &KModifierKeyInfo::keyLocked, this, [this](Qt::Key key, bool) {
        if (key == Qt::Key_CapsLock)
            Q_EMIT capsLockChanged();
        else if (key == Qt::Key_NumLock)
            Q_EMIT numLockChanged();
    });
}

// Out of line, and it has to be: the unique_ptr's deleter needs the complete
// type, which the header does not have.
LockKeys::~LockKeys() = default;

bool LockKeys::capsLock() const
{
    return m_keys->isKeyLocked(Qt::Key_CapsLock);
}

bool LockKeys::numLock() const
{
    return m_keys->isKeyLocked(Qt::Key_NumLock);
}

/*
    SPDX-License-Identifier: GPL-3.0-or-later

    Caps Lock and Num Lock, for QML.

    QML can read the modifiers carried *by an event*, and a lock key that is
    already on carries nothing: nothing is pressed, and this shell's surfaces
    never hold the keyboard anyway. Watching the LED files under
    /sys/class/leds works and costs a timer wakeup several times a second for
    the life of the session, to catch a fact that changes twice a day.

    KModifierKeyInfo needs neither. On Wayland it is backed by KWin's own
    `org_kde_kwin_keystate` global -- advertised at version 5 on this desktop,
    and global rather than per-surface, so a client with no keyboard focus is
    still told. It reports a change rather than being asked for one.

    This is a translation and nothing else: KModifierKeyInfo speaks in
    Qt::Key values and one `keyLocked(key, locked)` signal for every lock
    there is, and QML wants two properties that a binding can follow. The
    class exists because that translation needs somewhere to keep the
    KModifierKeyInfo alive -- an object that is not held is never told
    anything -- which is the difference between this and Modifiers next door,
    where the answer is a static call with no state behind it.
*/

#pragma once

#include <QObject>
#include <QtQml/qqmlregistration.h>

#include <memory>

class KModifierKeyInfo;

class LockKeys : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    Q_PROPERTY(bool capsLock READ capsLock NOTIFY capsLockChanged)
    Q_PROPERTY(bool numLock READ numLock NOTIFY numLockChanged)

public:
    explicit LockKeys(QObject *parent = nullptr);
    ~LockKeys() override;

    bool capsLock() const;
    bool numLock() const;

Q_SIGNALS:
    void capsLockChanged();
    void numLockChanged();

private:
    std::unique_ptr<KModifierKeyInfo> m_keys;
};

/*
    SPDX-License-Identifier: GPL-3.0-or-later

    An application's menu, read over DBus (com.canonical.dbusmenu), as a list
    QML can draw: what a global menu in the panel shows for the window in
    front (see appmenu.h for how the address is found).

    Quickshell reads this protocol for tray icons, but its menu handle cannot
    be made from QML for an address of our choosing; this is the part of it a
    global menu needs. `items` is the whole menu, top level first:

        [{ id, label, enabled, separator, toggle ("checkmark", "radio" or ""),
           checked, shortcut ("Ctrl+S"), icon, submenu, children: [...] }]

    Hidden entries are left out. `aboutToShow(id)` before a submenu is drawn
    lets the application fill it (a "Recent files" list is made then), and
    `activate(id)` is the click. When the application changes its menu, the
    list is read again.

    Pattern check: Adapter (Tier 1) — applied — the dbusmenu protocol turned into one QML list property plus two calls.
*/

#pragma once

#include <QDBusArgument>
#include <QDBusMessage>
#include <QObject>
#include <QTimer>
#include <QVariantList>
#include <QtQml/qqmlregistration.h>

class DBusMenuModel : public QObject
{
    Q_OBJECT
    QML_ELEMENT

    Q_PROPERTY(QString service READ service WRITE setService NOTIFY addressChanged)
    Q_PROPERTY(QString path READ path WRITE setPath NOTIFY addressChanged)
    Q_PROPERTY(QVariantList items READ items NOTIFY itemsChanged)

public:
    explicit DBusMenuModel(QObject *parent = nullptr);

    QString service() const { return m_service; }
    void setService(const QString &service);
    QString path() const { return m_path; }
    void setPath(const QString &path);
    QVariantList items() const { return m_items; }

    Q_INVOKABLE void aboutToShow(int id);
    Q_INVOKABLE void activate(int id);
    Q_INVOKABLE void refresh();

Q_SIGNALS:
    void addressChanged();
    void itemsChanged();

private Q_SLOTS:
    void onMenuChanged(const QDBusMessage &message);

private:
    bool hasAddress() const;
    void watch(bool on);
    void setItems(const QVariantList &items);
    QDBusMessage call(const QString &method) const;

    static QVariantMap readItem(const QDBusArgument &arg);
    static QVariantMap describe(int id, const QVariantMap &props, const QVariantList &children);
    static QString plainLabel(const QString &label);
    static QString shortcutText(const QVariant &value);

    QString m_service;
    QString m_path;
    QVariantList m_items;
    QTimer m_settle;
};

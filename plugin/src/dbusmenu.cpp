/*
    SPDX-License-Identifier: GPL-3.0-or-later

    See dbusmenu.h.

    Pattern check: Adapter (Tier 1) — extended — plugin/src/dbusmenu.h, the calls and replies of com.canonical.dbusmenu.
*/

#include "dbusmenu.h"

#include <QDBusConnection>
#include <QDBusPendingCallWatcher>
#include <QDBusPendingReply>
#include <QDBusVariant>
#include <QDateTime>
#include <QLoggingCategory>

Q_LOGGING_CATEGORY(logDBusMenu, "shell.dbusmenu")

namespace
{
const QString kInterface = QStringLiteral("com.canonical.dbusmenu");

// What the protocol calls a key, as people write it.
const QHash<QString, QString> kKeyNames = {
    {QStringLiteral("Control"), QStringLiteral("Ctrl")},
    {QStringLiteral("Super"), QStringLiteral("Meta")},
};
}

DBusMenuModel::DBusMenuModel(QObject *parent)
    : QObject(parent)
{
    // A burst of changes -- an application rebuilding its menu entry by entry
    // -- is read once, when it settles.
    m_settle.setSingleShot(true);
    m_settle.setInterval(60);
    connect(&m_settle, &QTimer::timeout, this, &DBusMenuModel::refresh);
}

void DBusMenuModel::setService(const QString &service)
{
    if (m_service == service)
        return;
    watch(false);
    m_service = service;
    watch(true);
    Q_EMIT addressChanged();
    refresh();
}

void DBusMenuModel::setPath(const QString &path)
{
    if (m_path == path)
        return;
    watch(false);
    m_path = path;
    watch(true);
    Q_EMIT addressChanged();
    refresh();
}

bool DBusMenuModel::hasAddress() const
{
    return !m_service.isEmpty() && m_path.startsWith(QLatin1Char('/'));
}

void DBusMenuModel::watch(bool on)
{
    if (!hasAddress())
        return;
    auto bus = QDBusConnection::sessionBus();
    for (const auto &signal : {QStringLiteral("LayoutUpdated"), QStringLiteral("ItemsPropertiesUpdated")}) {
        if (on)
            bus.connect(m_service, m_path, kInterface, signal, this, SLOT(onMenuChanged(QDBusMessage)));
        else
            bus.disconnect(m_service, m_path, kInterface, signal, this, SLOT(onMenuChanged(QDBusMessage)));
    }
}

void DBusMenuModel::onMenuChanged(const QDBusMessage &)
{
    m_settle.start();
}

QDBusMessage DBusMenuModel::call(const QString &method) const
{
    return QDBusMessage::createMethodCall(m_service, m_path, kInterface, method);
}

void DBusMenuModel::setItems(const QVariantList &items)
{
    m_items = items;
    Q_EMIT itemsChanged();
}

// The whole menu, from the top: an application's menu bar is a few hundred
// entries at most, and reading it whole keeps one list for QML to draw.
void DBusMenuModel::refresh()
{
    if (!hasAddress()) {
        setItems({});
        return;
    }
    auto message = call(QStringLiteral("GetLayout"));
    message << 0 << -1 << QStringList();
    const QString service = m_service;
    const QString path = m_path;
    auto *watcher = new QDBusPendingCallWatcher(QDBusConnection::sessionBus().asyncCall(message), this);
    connect(watcher, &QDBusPendingCallWatcher::finished, this, [this, watcher, service, path] {
        watcher->deleteLater();
        // Answered for a menu that is no longer the one shown.
        if (service != m_service || path != m_path)
            return;
        const QDBusMessage reply = watcher->reply();
        if (reply.type() != QDBusMessage::ReplyMessage || reply.arguments().size() < 2) {
            qCDebug(logDBusMenu) << "no menu at" << service << path << watcher->error().message();
            setItems({});
            return;
        }
        const auto root = readItem(reply.arguments().at(1).value<QDBusArgument>());
        setItems(root.value(QStringLiteral("children")).toList());
    });
}

void DBusMenuModel::aboutToShow(int id)
{
    if (!hasAddress())
        return;
    auto message = call(QStringLiteral("AboutToShow"));
    message << id;
    auto *watcher = new QDBusPendingCallWatcher(QDBusConnection::sessionBus().asyncCall(message), this);
    connect(watcher, &QDBusPendingCallWatcher::finished, this, [this, watcher] {
        watcher->deleteLater();
        const QDBusPendingReply<bool> reply = *watcher;
        if (reply.isValid() && reply.value())
            m_settle.start();
    });
}

void DBusMenuModel::activate(int id)
{
    if (!hasAddress())
        return;
    auto message = call(QStringLiteral("Event"));
    message << id << QStringLiteral("clicked") << QVariant::fromValue(QDBusVariant(QVariant(QString())))
            << static_cast<uint>(QDateTime::currentSecsSinceEpoch());
    QDBusConnection::sessionBus().asyncCall(message);
}

// ---- reading the layout --------------------------------------------------------

// One entry: (ia{sv}av) -- its id, its properties, and its children, each a
// variant holding another of the same.
QVariantMap DBusMenuModel::readItem(const QDBusArgument &arg)
{
    int id = 0;
    QVariantMap props;
    QVariantList children;
    arg.beginStructure();
    arg >> id >> props;
    arg.beginArray();
    while (!arg.atEnd()) {
        QDBusVariant child;
        arg >> child;
        const auto item = readItem(child.variant().value<QDBusArgument>());
        if (item.value(QStringLiteral("visible")).toBool())
            children << item;
    }
    arg.endArray();
    arg.endStructure();
    return describe(id, props, children);
}

QVariantMap DBusMenuModel::describe(int id, const QVariantMap &props, const QVariantList &children)
{
    const QString type = props.value(QStringLiteral("type")).toString();
    const QString toggle = props.value(QStringLiteral("toggle-type")).toString();
    return {
        {QStringLiteral("id"), id},
        {QStringLiteral("label"), plainLabel(props.value(QStringLiteral("label")).toString())},
        {QStringLiteral("enabled"), props.value(QStringLiteral("enabled"), true).toBool()},
        {QStringLiteral("visible"), props.value(QStringLiteral("visible"), true).toBool()},
        {QStringLiteral("separator"), type == QLatin1String("separator")},
        {QStringLiteral("toggle"), toggle},
        {QStringLiteral("checked"), props.value(QStringLiteral("toggle-state")).toInt() == 1},
        {QStringLiteral("shortcut"), shortcutText(props.value(QStringLiteral("shortcut")))},
        {QStringLiteral("icon"), props.value(QStringLiteral("icon-name")).toString()},
        {QStringLiteral("submenu"), props.value(QStringLiteral("children-display")).toString() == QLatin1String("submenu")
                                         || !children.isEmpty()},
        {QStringLiteral("children"), children},
    };
}

// "_File" is "File" with F as its mnemonic; "__" is an underscore.
QString DBusMenuModel::plainLabel(const QString &label)
{
    QString out;
    out.reserve(label.size());
    for (qsizetype i = 0; i < label.size(); ++i) {
        const bool doubled = label.at(i) == QLatin1Char('_') && i + 1 < label.size() && label.at(i + 1) == QLatin1Char('_');
        if (doubled)
            ++i;
        if (label.at(i) != QLatin1Char('_') || doubled)
            out += label.at(i);
    }
    return out;
}

// aas: chords of keys, [["Control", "S"]]; the first chord is the one shown.
QString DBusMenuModel::shortcutText(const QVariant &value)
{
    if (!value.canConvert<QDBusArgument>())
        return {};
    const auto arg = value.value<QDBusArgument>();
    QList<QStringList> chords;
    arg >> chords;
    if (chords.isEmpty())
        return {};
    QStringList keys;
    for (const auto &key : chords.first())
        keys << kKeyNames.value(key, key);
    return keys.join(QLatin1Char('+'));
}

/*
    SPDX-License-Identifier: GPL-3.0-or-later

    See appmenu.h for why this exists at all.

    Pattern check: Adapter (Tier 1) — extended — plugin/src/screencast.cpp, events kept as properties for QML.
*/

#include "appmenu.h"

#include <QDBusConnection>
#include <QDBusConnectionInterface>
#include <QLoggingCategory>

Q_LOGGING_CATEGORY(logAppMenu, "shell.appmenu")

namespace
{
// The name Plasma's global menu applet holds to say a menu view exists; the
// kded appmenu module watches for it and starts the registrar.
const QString kViewName = QStringLiteral("org.kde.kappmenuview");

// Version 13 brings window_with_uuid, 10 the application menu. Anything up
// to 16 is understood here; KWin offers more and Wayland gives the lower.
constexpr int kVersion = 16;

constexpr uint32_t kActive = 0x1;
}

// ---- the global -------------------------------------------------------------

WindowManagementGlobal::WindowManagementGlobal()
    : QWaylandClientExtensionTemplate<WindowManagementGlobal>(kVersion)
{
    initialize();
}

void WindowManagementGlobal::org_kde_plasma_window_management_window_with_uuid(uint32_t, const QString &uuid)
{
    Q_EMIT windowAdded(new PlasmaWindow(get_window_by_uuid(uuid), uuid));
}

// ---- one window ---------------------------------------------------------------

PlasmaWindow::PlasmaWindow(::org_kde_plasma_window *window, const QString &uuid)
    : QtWayland::org_kde_plasma_window(window)
    , uuid(uuid)
{
}

PlasmaWindow::~PlasmaWindow()
{
    if (isInitialized())
        destroy();
}

void PlasmaWindow::org_kde_plasma_window_title_changed(const QString &value)
{
    title = value;
    Q_EMIT changed();
}

void PlasmaWindow::org_kde_plasma_window_app_id_changed(const QString &value)
{
    appId = value;
    Q_EMIT changed();
}

void PlasmaWindow::org_kde_plasma_window_state_changed(uint32_t flags)
{
    const bool now = (flags & kActive) != 0;
    if (now == active)
        return;
    active = now;
    Q_EMIT changed();
}

void PlasmaWindow::org_kde_plasma_window_application_menu(const QString &serviceName, const QString &objectPath)
{
    menuService = serviceName;
    menuPath = objectPath;
    Q_EMIT changed();
}

void PlasmaWindow::org_kde_plasma_window_unmapped()
{
    Q_EMIT gone();
}

// ---- the windows, for the life of the process ------------------------------------

WindowTracker *WindowTracker::instance()
{
    // Deliberately leaked: see the class comment.
    static WindowTracker *tracker = new WindowTracker;
    return tracker;
}

WindowTracker::WindowTracker()
    : m_global(new WindowManagementGlobal)
{
    connect(m_global, &WindowManagementGlobal::windowAdded, this, &WindowTracker::track);
    connect(m_global, &WindowManagementGlobal::activeChanged, this, [this] {
        if (m_global->isActive())
            qCInfo(logAppMenu) << "KWin offers window management; the global menu follows the window in front";
        else
            qCWarning(logAppMenu) << "KWin does not offer org_kde_plasma_window_management to this client: no global menu";
        Q_EMIT supportedChanged();
    });
}

bool WindowTracker::isSupported() const
{
    return m_global->isActive();
}

void WindowTracker::hold(int change)
{
    const bool was = isHeld();
    m_holders = qMax(0, m_holders + change);
    if (was == isHeld())
        return;
    holdName(isHeld());
    Q_EMIT heldChanged();
}

// Owning the name is the whole of the switch: kded starts the registrar for
// it, and stops it when the name goes. Another owner -- Plasma's own applet
// in a Plasma panel beside this one -- already does the same thing, so being
// refused is not an error.
void WindowTracker::holdName(bool hold)
{
    auto bus = QDBusConnection::sessionBus();
    if (hold && !m_holdsName) {
        m_holdsName = bus.registerService(kViewName);
        if (!m_holdsName)
            qCInfo(logAppMenu) << kViewName << "is held by somebody else; their menu view keeps the registrar running";
        return;
    }
    if (!hold && m_holdsName) {
        bus.unregisterService(kViewName);
        m_holdsName = false;
    }
}

void WindowTracker::track(PlasmaWindow *window)
{
    window->setParent(this);
    connect(window, &PlasmaWindow::changed, this, [this, window] { windowChanged(window); });
    connect(window, &PlasmaWindow::gone, this, [this, window] { windowGone(window); });
}

void WindowTracker::windowChanged(PlasmaWindow *window)
{
    if (window->active && m_front != window) {
        m_front = window;
        Q_EMIT frontChanged();
        return;
    }
    if (m_front == window)
        Q_EMIT frontChanged();
}

void WindowTracker::windowGone(PlasmaWindow *window)
{
    const bool wasFront = m_front == window;
    window->deleteLater();
    if (!wasFront)
        return;
    m_front = nullptr;
    Q_EMIT frontChanged();
}

// ---- for QML ------------------------------------------------------------------

ActiveWindowMenu::ActiveWindowMenu(QObject *parent)
    : QObject(parent)
{
    auto *tracker = WindowTracker::instance();
    connect(tracker, &WindowTracker::supportedChanged, this, &ActiveWindowMenu::supportedChanged);
    connect(tracker, &WindowTracker::frontChanged, this, &ActiveWindowMenu::menuChanged);
    connect(tracker, &WindowTracker::heldChanged, this, &ActiveWindowMenu::enabledChanged);
}

// A reload ends the engine without every widget's onDestruction having run:
// whatever this engine still holds is given back here.
ActiveWindowMenu::~ActiveWindowMenu()
{
    WindowTracker::instance()->hold(-m_mine);
}

void ActiveWindowMenu::acquire()
{
    ++m_mine;
    WindowTracker::instance()->hold(1);
}

void ActiveWindowMenu::release()
{
    if (m_mine == 0)
        return;
    --m_mine;
    WindowTracker::instance()->hold(-1);
}

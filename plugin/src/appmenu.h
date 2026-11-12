/*
    SPDX-License-Identifier: GPL-3.0-or-later

    Which application menu belongs to the window in front, for a global menu
    in the panel -- and the switch that makes applications hand their menus
    over at all.

    Two halves, both things QML cannot do on its own:

    - The menu's address. A Qt or GTK application that exports its menu bar
      tells KWin where it is (a DBus service and object path) through the
      org_kde_kwin_appmenu protocol, and KWin hands that on, per window,
      through org_kde_plasma_window_management's `application_menu` event --
      the same route Plasma's own global menu takes. That protocol is
      restricted; this shell's desktop file asks for it already (see
      share/applications/wayland-interfaces.desktop.in). KWin's scripting
      API does not expose the address at all.

    - The switch. Applications export their menu only while a registrar
      (com.canonical.AppMenu.Registrar) is on the bus, and Plasma's kded
      appmenu module starts one only while somebody owns
      `org.kde.kappmenuview` -- which is how Plasma's global menu applet says
      "there is a menu view". While the name is held, KDE applications move
      their menu bar out of the window and into the panel; when it is let go,
      the registrar goes and the menu bars come back. So the name is held
      only while `enabled` -- while a global menu is on the panel.

    Pattern check: Adapter (Tier 1) — extended — plugin/src/screencast.h, a Wayland interface turned into QML properties.
    Nothing here decides how a menu looks.
*/

#pragma once

#include <QObject>
#include <QPointer>
#include <QWaylandClientExtension>
#include <QtQml/qqmlregistration.h>

#include "qwayland-plasma-window-management.h"

class PlasmaWindow;

class WindowManagementGlobal : public QWaylandClientExtensionTemplate<WindowManagementGlobal>,
                               public QtWayland::org_kde_plasma_window_management
{
    Q_OBJECT

public:
    WindowManagementGlobal();

Q_SIGNALS:
    void windowAdded(PlasmaWindow *window);

protected:
    void org_kde_plasma_window_management_window_with_uuid(uint32_t id, const QString &uuid) override;
};

// One window, as KWin describes it: whether it is in front, its title, its
// application, and where its menu is.
class PlasmaWindow : public QObject, public QtWayland::org_kde_plasma_window
{
    Q_OBJECT

public:
    PlasmaWindow(::org_kde_plasma_window *window, const QString &uuid);
    ~PlasmaWindow() override;

    QString uuid;
    QString title;
    QString appId;
    QString menuService;
    QString menuPath;
    bool active = false;

Q_SIGNALS:
    void changed();
    void gone();

protected:
    void org_kde_plasma_window_title_changed(const QString &title) override;
    void org_kde_plasma_window_app_id_changed(const QString &appId) override;
    void org_kde_plasma_window_state_changed(uint32_t flags) override;
    void org_kde_plasma_window_application_menu(const QString &serviceName, const QString &objectPath) override;
    void org_kde_plasma_window_unmapped() override;
};

// The windows and which one is in front, for the life of the process.
//
// Never deleted, as ScreencastGlobal is not: org_kde_plasma_window_management
// has no destructor request, so the proxy cannot be told to stop, and a
// global freed under it is called into by the next window event. A QML
// reload destroys the engine's singletons -- that freed this once and took
// the shell down 14 seconds later (2026-11-12). So the Wayland side lives
// here, once, and each engine's ActiveWindowMenu only reads it.
//
// "In front" is the last window KWin said was active. Clicking the panel
// takes the keyboard to a layer surface, which is not a window, and KWin then
// says no window is active; the menu of the one that was stays, or a global
// menu could never be clicked.
class WindowTracker : public QObject
{
    Q_OBJECT

public:
    static WindowTracker *instance();

    bool isSupported() const;
    PlasmaWindow *front() const { return m_front; }

    // `org.kde.kappmenuview`, held while anybody asks for it.
    void hold(int change);
    bool isHeld() const { return m_holders > 0; }

Q_SIGNALS:
    void supportedChanged();
    void frontChanged();
    void heldChanged();

private:
    WindowTracker();

    void track(PlasmaWindow *window);
    void windowChanged(PlasmaWindow *window);
    void windowGone(PlasmaWindow *window);
    void holdName(bool hold);

    WindowManagementGlobal *m_global = nullptr;
    QPointer<PlasmaWindow> m_front;
    int m_holders = 0;
    bool m_holdsName = false;
};

// For QML: the menu of the window in front. One a QML engine, made afresh on
// every reload; what it holds of the bus name it gives back when it goes.
class ActiveWindowMenu : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    // KWin offers window management to this client: without it there is no
    // way to know which menu is whose, and the rest is empty.
    Q_PROPERTY(bool supported READ isSupported NOTIFY supportedChanged)

    // Whether `org.kde.kappmenuview` is asked for, so applications export
    // their menus: while anybody holds it (acquire/release -- one global menu
    // a screen, and the last one to go lets it go).
    Q_PROPERTY(bool enabled READ isEnabled NOTIFY enabledChanged)

    Q_PROPERTY(QString service READ service NOTIFY menuChanged)
    Q_PROPERTY(QString path READ path NOTIFY menuChanged)
    Q_PROPERTY(QString title READ title NOTIFY menuChanged)
    Q_PROPERTY(QString appId READ appId NOTIFY menuChanged)
    Q_PROPERTY(QString uuid READ uuid NOTIFY menuChanged)

public:
    explicit ActiveWindowMenu(QObject *parent = nullptr);
    ~ActiveWindowMenu() override;

    bool isSupported() const { return WindowTracker::instance()->isSupported(); }
    bool isEnabled() const { return WindowTracker::instance()->isHeld(); }
    Q_INVOKABLE void acquire();
    Q_INVOKABLE void release();

    QString service() const { return front() ? front()->menuService : QString(); }
    QString path() const { return front() ? front()->menuPath : QString(); }
    QString title() const { return front() ? front()->title : QString(); }
    QString appId() const { return front() ? front()->appId : QString(); }
    QString uuid() const { return front() ? front()->uuid : QString(); }

Q_SIGNALS:
    void supportedChanged();
    void enabledChanged();
    void menuChanged();

private:
    PlasmaWindow *front() const { return WindowTracker::instance()->front(); }

    // What this engine holds of the name, given back in the destructor.
    int m_mine = 0;
};

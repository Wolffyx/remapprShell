/*
    SPDX-License-Identifier: GPL-3.0-or-later

    See screencast.h for why this exists at all.
*/

#include "screencast.h"

#include <QLoggingCategory>

Q_LOGGING_CATEGORY(logScreencast, "shell.screencast")

ScreencastGlobal::ScreencastGlobal()
    : QWaylandClientExtensionTemplate<ScreencastGlobal>(/* version */ 1)
{
    initialize();

    if (isActive()) {
        qCInfo(logScreencast) << "KWin offers window streams; previews are live";
    } else {
        // The likely reason, said once, because the alternative is a shell
        // that silently shows icons and a person wondering why.
        qCWarning(logScreencast)
            << "KWin did not advertise zkde_screencast_unstable_v1: window previews will be "
               "icons. This client's desktop file must name the interface in "
               "X-KDE-Wayland-Interfaces, and the match is on the executable's absolute path.";
    }
}

ScreencastGlobal *ScreencastGlobal::instance()
{
    // Created on first use and kept: the global is per connection, and binding
    // it twice is a protocol error rather than two streams.
    static ScreencastGlobal *global = new ScreencastGlobal;
    return global;
}

WindowStream::WindowStream(QObject *parent)
    : QObject(parent)
{
}

WindowStream::~WindowStream()
{
    close();
}

bool WindowStream::isSupported() const
{
    return ScreencastGlobal::instance()->isActive();
}

void WindowStream::setWindowId(const QString &id)
{
    if (m_windowId == id)
        return;
    m_windowId = id;
    Q_EMIT windowIdChanged();

    // A card that is reused for another window -- a list scrolling, a
    // selection moving -- must not keep showing the one before it.
    close();
    open();
}

void WindowStream::setActive(bool active)
{
    if (m_active == active)
        return;
    m_active = active;
    Q_EMIT activeChanged();

    if (m_active)
        open();
    else
        close();
}

void WindowStream::open()
{
    if (!m_active || m_windowId.isEmpty() || isInitialized())
        return;

    auto *global = ScreencastGlobal::instance();
    if (!global->isActive()) {
        setError(QStringLiteral("the compositor does not offer window streams"));
        return;
    }

    setError(QString());
    // Pointer mode 0 is "hidden": a thumbnail of a window with somebody
    // else's pointer drawn into it is a picture of the wrong thing.
    init(global->stream_window(m_windowId, 0));
}

void WindowStream::close()
{
    // The protocol's own destructor request, which is what tells the
    // compositor to stop capturing -- destroying the proxy behind its back
    // instead leaves KWin capturing a window nobody is looking at, and takes
    // the process down on the way out.
    //
    // Guarded on the global as well as on our own object, because this runs
    // from the destructor: a stream outliving the connection would write a
    // request into a display that is already gone. The crash that taught the
    // first half of this was a wl_proxy_add_listener on a null proxy, reached
    // from here, taking the whole shell with it on a reload.
    if (isInitialized() && ScreencastGlobal::instance()->isActive())
        zkde_screencast_stream_unstable_v1::close();
    setNodeId(-1);
}

void WindowStream::setNodeId(int node)
{
    if (m_nodeId == node)
        return;
    m_nodeId = node;
    Q_EMIT nodeIdChanged();
}

void WindowStream::setError(const QString &error)
{
    if (m_error == error)
        return;
    m_error = error;
    Q_EMIT errorChanged();
}

void WindowStream::zkde_screencast_stream_unstable_v1_created(uint32_t node)
{
    setNodeId(static_cast<int>(node));
}

void WindowStream::zkde_screencast_stream_unstable_v1_failed(const QString &error)
{
    qCWarning(logScreencast) << "stream for" << m_windowId << "failed:" << error;
    setError(error);
    setNodeId(-1);
}

void WindowStream::zkde_screencast_stream_unstable_v1_closed()
{
    setNodeId(-1);
}

/*
    SPDX-License-Identifier: GPL-3.0-or-later

    A live picture of a window, for QML.

    KWin renders window thumbnails for its own switcher layouts and for nobody
    else; what it offers everybody else is `zkde_screencast_unstable_v1`, a
    Wayland protocol that turns a window into a PipeWire stream. That protocol
    is *restricted*: KWin advertises it only to a client whose desktop file
    names it in `X-KDE-Wayland-Interfaces`, and refuses silently otherwise --
    the global simply is not there, which reads as "KWin does not implement
    it". See share/applications/wayland-interfaces.desktop.in.

    Rendering the stream is free from QML: `org.kde.pipewire`'s
    PipeWireSourceItem draws a node id. Obtaining the node id is the part that
    needs a Wayland client binding, which is what this is and the whole reason
    this project has any C++ in it.

    Adapter, in the Gang of Four sense: the shape KWin offers is a Wayland
    interface with new_id requests and events, and the shape QML can use is an
    object with properties that change. Nothing here decides anything.
*/

#pragma once

#include <QWaylandClientExtension>
#include <QtQml/qqmlregistration.h>

#include "qwayland-zkde-screencast-unstable-v1.h"

// The global. One per process: every stream is requested from it, and its
// absence is what "KWin will not give us one" looks like.
class ScreencastGlobal : public QWaylandClientExtensionTemplate<ScreencastGlobal>,
                         public QtWayland::zkde_screencast_unstable_v1
{
    Q_OBJECT

public:
    ScreencastGlobal();

    // Made on first use rather than at load: a shell that never shows a
    // preview should not hold a protocol object, and a shell that KWin refuses
    // should not be a shell that fails to start.
    static ScreencastGlobal *instance();
};

// One window's stream.
//
// `nodeId` is what PipeWireSourceItem wants. It is -1 until the compositor
// answers, and -1 again the moment the stream closes, so a preview can fall
// back to the application's icon by binding to it rather than by asking.
class WindowStream : public QObject, public QtWayland::zkde_screencast_stream_unstable_v1
{
    Q_OBJECT
    QML_ELEMENT

    // The window, as KWin's uuid -- the same string the window list carries,
    // so nothing here has to know how windows are identified.
    Q_PROPERTY(QString windowId READ windowId WRITE setWindowId NOTIFY windowIdChanged)

    // Whether this stream should be running. Streams cost the compositor a
    // capture each, so a preview that is not being looked at turns its own
    // off; see the taskbar's hover preview.
    Q_PROPERTY(bool active READ isActive WRITE setActive NOTIFY activeChanged)

    Q_PROPERTY(int nodeId READ nodeId NOTIFY nodeIdChanged)
    Q_PROPERTY(bool available READ isAvailable NOTIFY nodeIdChanged)

    // Why there is no picture, when there is none. Empty while all is well.
    Q_PROPERTY(QString error READ error NOTIFY errorChanged)

    // Whether the compositor offers this at all, so a surface can draw icons
    // without waiting for a stream that will never come.
    Q_PROPERTY(bool supported READ isSupported CONSTANT)

public:
    explicit WindowStream(QObject *parent = nullptr);
    ~WindowStream() override;

    QString windowId() const { return m_windowId; }
    void setWindowId(const QString &id);

    bool isActive() const { return m_active; }
    void setActive(bool active);

    int nodeId() const { return m_nodeId; }
    bool isAvailable() const { return m_nodeId >= 0; }
    QString error() const { return m_error; }
    bool isSupported() const;

Q_SIGNALS:
    void windowIdChanged();
    void activeChanged();
    void nodeIdChanged();
    void errorChanged();

protected:
    // The protocol's own events. `created` is how versions before 6 report the
    // node; `serial` is how 6 does, and carries the same node id first.
    void zkde_screencast_stream_unstable_v1_created(uint32_t node) override;
    void zkde_screencast_stream_unstable_v1_failed(const QString &error) override;
    void zkde_screencast_stream_unstable_v1_closed() override;

private:
    void open();
    void close();
    void setNodeId(int node);
    void setError(const QString &error);

    QString m_windowId;
    bool m_active = true;
    int m_nodeId = -1;
    QString m_error;
};

# The shell's only compiled part, and it exists for one thing: turning a
# window into a PipeWire node id that QML can draw.
#
# Everything else in this project is QML and shell script on purpose. This is
# here because obtaining a window's stream needs a Wayland client binding and
# there is no way to bind a protocol from QML -- see src/screencast.h.
#
# It is optional. The shell checks for the module at runtime and draws the
# application's icon when it is not there, so `make` and the test suite never
# need a C++ toolchain; `make plugin` is what builds it.
cmake_minimum_required(VERSION 3.24)

# C as well as C++: wayland-scanner's own output is C, and it carries the
# protocol's interface symbols. With C not enabled the file is generated,
# quietly not compiled, and the module fails to load at runtime with an
# undefined symbol -- which looks like the plugin not being installed.
project(shell-screencast VERSION 0.1 LANGUAGES CXX C)

find_package(Qt6 6.6 REQUIRED COMPONENTS Core Gui Qml WaylandClient)

# KGuiAddons, for KModifierKeyInfo: the lock keys. On Wayland it binds KWin's
# own org_kde_kwin_keystate global, which is how a client with no keyboard
# focus can be told that Caps Lock went on -- see src/lockkeys.h.
find_package(KF6GuiAddons REQUIRED)

qt_standard_project_setup(REQUIRES 6.6)

# Where the QML module lands. The default install prefix is the user's own Qt
# import path, because this installs beside a shell that lives in $HOME and
# needs no root.
if(NOT DEFINED QML_INSTALL_DIR)
    set(QML_INSTALL_DIR "$ENV{HOME}/.local/lib/qt6/qml")
endif()

# One QML module: <target>'s sources registered under <uri>, linked against
# Core, Gui and Qml and whatever LIBS adds, and installed as a directory of its
# own under QML_INSTALL_DIR. The library itself is made by the caller, before
# this, so that generated sources can be added to it first.
#
# The sources go through qt6_add_qml_module rather than through
# target_sources: the QML type registration is generated from the files that
# call is given, and a header added to the target afterwards is compiled but
# not registered -- which fails the build in the generated file rather than in
# ours. That generated registration includes each header by name, so src/ is on
# the include path: without it the header is not found, the type is unknown,
# and the failure is again reported in the generated file.
function(shell_qml_module target uri)
    cmake_parse_arguments(PARSE_ARGV 2 arg "" "" "SOURCES;LIBS;INCLUDES")
    qt6_add_qml_module(${target}
        URI ${uri}
        VERSION 1.0
        SOURCES ${arg_SOURCES}
        OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/qml/${uri}"
    )
    target_link_libraries(${target} PRIVATE Qt6::Core Qt6::Gui Qt6::Qml ${arg_LIBS})
    target_include_directories(${target} PRIVATE ${arg_INCLUDES} "${CMAKE_CURRENT_SOURCE_DIR}/src")

    # The installed module must stand on its own: Qt splits a QML module into
    # the plugin and a backing library, and without this the plugin's RUNPATH
    # points at whatever directory it was *built* in. A build directory that is
    # later removed -- a temporary one, a cleaned checkout -- leaves a module
    # that silently stops loading, and the shell then draws icons with nothing
    # to say why.
    foreach(t ${target} ${target}plugin)
        if(TARGET ${t})
            set_target_properties(${t} PROPERTIES
                INSTALL_RPATH "$ORIGIN"
                BUILD_WITH_INSTALL_RPATH OFF
                INSTALL_RPATH_USE_LINK_PATH OFF
            )
        endif()
    endforeach()

    install(TARGETS ${target} ${target}plugin
        LIBRARY DESTINATION "${QML_INSTALL_DIR}/${uri}"
        ARCHIVE DESTINATION "${QML_INSTALL_DIR}/${uri}"
        RUNTIME DESTINATION "${QML_INSTALL_DIR}/${uri}"
    )
    install(DIRECTORY "${CMAKE_BINARY_DIR}/qml/${uri}/"
        DESTINATION "${QML_INSTALL_DIR}/${uri}"
    )
endfunction()

# Shared, not static: the QML engine loads the module's plugin at runtime, and
# a static one installs an archive nothing can dlopen -- which looks exactly
# like the module not being installed.
qt_add_library(shellscreencast SHARED)

# The canonical copy of the protocol is plasma-wayland-protocols'; the copy
# here is the same file, vendored so that building this needs nothing but Qt.
# It is LGPL-2.1-or-later, which GPL-3.0-or-later can carry.
set(SCREENCAST_XML "${CMAKE_CURRENT_SOURCE_DIR}/protocols/zkde-screencast-unstable-v1.xml")
if(EXISTS "/usr/share/plasma-wayland-protocols/zkde-screencast-unstable-v1.xml")
    set(SCREENCAST_XML "/usr/share/plasma-wayland-protocols/zkde-screencast-unstable-v1.xml")
endif()

qt6_generate_wayland_protocol_client_sources(shellscreencast FILES "${SCREENCAST_XML}")

# The module name is deliberately about KWin rather than about this shell: what
# it wraps is KWin's protocol, and anything else drawing on this desktop wants
# the same thing. The binary directory is on its include path for the
# generated protocol header.
shell_qml_module(shellscreencast KWinScreencast
    SOURCES src/screencast.cpp src/screencast.h
    LIBS Qt6::WaylandClient
    INCLUDES "${CMAKE_CURRENT_BINARY_DIR}"
)

# A second module, deliberately separate. The one above is about KWin's
# screencast protocol and is named for it; asking the keyboard what is held has
# nothing to do with that, and a module that answered both would be a module
# about "the C++ we happened to need".
qt_add_library(shellinput SHARED)
shell_qml_module(shellinput ShellInput
    SOURCES src/modifiers.cpp src/modifiers.h src/lockkeys.cpp src/lockkeys.h
    LIBS KF6::GuiAddons
)

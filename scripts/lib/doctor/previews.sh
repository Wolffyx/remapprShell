# shellcheck shell=bash
# Window previews, and the input module built beside them: the compiled
# modules, kpipewire, and KWin's permission.
#
# A section of doctor.sh, which sources it and supplies ok, warn, bad, fix and
# section. Requires brand.sh.

doctor_previews() {
    local preview_module preview_dir input_module wayland_desktop
    section "window previews"

    # A live picture of a window needs three things to line up, and each of them
    # fails quietly on its own: the compiled module, kpipewire to draw a node, and
    # KWin's permission -- which it grants only to a client whose desktop file
    # names the protocol.
    preview_module="$HOME/.local/lib/qt6/qml/KWinScreencast/libshellscreencastplugin.so"
    preview_dir=$(dirname "$(dirname "$preview_module")")
    if [ -f "$preview_module" ]; then
        ok "the preview module is installed"
    else
        warn "no preview module: windows are drawn as their application's icon"
        fix "build it with: make plugin  (needs cmake and Qt 6 development files)"
    fi

    # Installed is not the same as reachable. The module is a compiled QML module
    # in the user's own Qt import directory, which Qt searches only when it is on
    # QML2_IMPORT_PATH -- and the session script is what puts it there. Built,
    # installed and unreachable reported itself as "the KWinScreencast module is
    # not installed (build it with `make plugin`)", which sent the reader to
    # rebuild a module that was already sitting in that directory.
    if [ -f "$preview_module" ]; then
        if grep -q "$(printf '%s' "$preview_dir" | sed 's|^'"$HOME"'|\$HOME|')" "$BIN_DIR/$SESSION_BIN" 2>/dev/null \
           || grep -qF "$preview_dir" "$BIN_DIR/$SESSION_BIN" 2>/dev/null; then
            ok "the shell can import it ($preview_dir is on the import path)"
        else
            bad "the preview module is installed but the shell cannot import it"
            fix "$preview_dir is not on QML2_IMPORT_PATH in $BIN_DIR/$SESSION_BIN"
            fix "reinstall with: make link  (then: $ALIAS restart)"
        fi
    fi

    # The other module the same build installs, beside it. It answers what QML
    # cannot ask without an event to hang the question on: which keys are held and
    # which locks are on. Without it the lock-key OSD is silent, and the switchers
    # cannot check whether their key is still down.
    input_module="$preview_dir/ShellInput/libshellinputplugin.so"
    if [ -f "$input_module" ]; then
        ok "the input module is installed (held keys, lock keys)"
    else
        warn "no input module: no lock-key OSD, and the switchers cannot check which keys are held"
        fix "build it with: make plugin  (the same build as the previews)"
    fi

    if [ -d /usr/lib/qt6/qml/org/kde/pipewire ]; then
        ok "kpipewire present (it draws the stream)"
    else
        warn "kpipewire is missing, so a stream could not be drawn even if KWin gave one"
        fix "install it with: sudo pacman -S --needed kpipewire"
    fi

    wayland_desktop="$APPLICATIONS_DIR/$SLUG-wayland-interfaces.desktop"
    if grep -q "zkde_screencast_unstable_v1" "$wayland_desktop" 2>/dev/null; then
        ok "KWin is asked for the screencast protocol ($(basename "$wayland_desktop"))"
    else
        bad "nothing asks KWin for the screencast protocol"
        fix "KWin only advertises it to a client whose desktop file names it in X-KDE-Wayland-Interfaces"
        fix "reinstall with: make link"
    fi
}

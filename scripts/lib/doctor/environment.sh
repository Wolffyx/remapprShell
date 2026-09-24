# shellcheck shell=bash
# The environment: the desktop this runs under, and the tools the shell needs
# at runtime.
#
# A section of doctor.sh, which sources it and supplies ok, warn, bad, fix and
# section. Requires brand.sh.

doctor_environment() {
    local tool
    section "environment"

    if [ "${XDG_CURRENT_DESKTOP:-}" = "KDE" ]; then
        ok "running under KDE"
    else
        warn "XDG_CURRENT_DESKTOP is '${XDG_CURRENT_DESKTOP:-unset}'"
        fix "this shell targets Plasma; other desktops are untested"
    fi

    for tool in quickshell jq busctl gdbus kwriteconfig6; do
        if command -v "$tool" >/dev/null 2>&1; then
            ok "$tool present"
        else
            bad "$tool not found"
            fix "install it; the shell needs it at runtime"
        fi
    done

    if [ -x /usr/lib/qt6/bin/qmllint ]; then
        ok "Qt6 qmllint present"
    else
        warn "Qt6 qmllint not found"
        fix "install qt6-declarative to run 'make lint'"
    fi
}

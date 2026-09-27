# shellcheck shell=bash
# The single SRC -> DEST manifest.
#
# --link, --copy and --uninstall all iterate this one list, so the development
# layout and the installed layout cannot drift apart. Adding something to the
# install means adding one line here and nowhere else.
#
# Each entry is: KIND|SRC (repo-relative)|DEST (absolute)
#   dir       a directory: symlinked whole in link mode, copied in copy mode
#   template  a *.in file rendered by lib/render.sh, always copied, made executable
#   package   a directory of modules rendered by lib/render.sh file by file --
#             the *.in among them rendered, the rest as they are -- always
#             copied, never linked: see install_package in install.sh
#   symlink   a link to SRC, which is a path relative to DEST's directory
#
# Requires brand.sh to have been sourced.

manifest_entries() {
    cat <<ENTRIES
dir|shell|$QS_CONFIG_DIR
dir|config|$DATA_DIR/config
template|bin/session.sh.in|$BIN_DIR/$SESSION_BIN
template|bin/ctl.sh.in|$BIN_DIR/$CTL_BIN
package|bin/windowsd|$DATA_DIR/lib/windowsd
template|bin/windowsd.py.in|$BIN_DIR/$WINDOWSD_BIN
template|share/dbus/windows.service.in|$DBUS_SERVICES_DIR/$DBUS_NAME.service
symlink|$CTL_BIN|$BIN_DIR/$ALIAS
template|share/systemd/service.in|$SYSTEMD_USER_DIR/$SYSTEMD_UNIT
template|share/systemd/report.in|$SYSTEMD_USER_DIR/$SLUG-report@.service
template|share/systemd/theme.in|$SYSTEMD_USER_DIR/$SLUG-theme.service
template|share/systemd/renderer.in|$SYSTEMD_USER_DIR/$SLUG-renderer@.service
template|share/applications/launcher.desktop.in|$APPLICATIONS_DIR/$SLUG-launcher.desktop
template|share/applications/search.desktop.in|$APPLICATIONS_DIR/$SLUG-search.desktop
template|share/applications/settings.desktop.in|$APPLICATIONS_DIR/$SLUG-settings.desktop
template|share/applications/ask.desktop.in|$APPLICATIONS_DIR/$SLUG-ask.desktop
template|share/applications/clipboard.desktop.in|$APPLICATIONS_DIR/$SLUG-clipboard.desktop
template|share/applications/sidebar.desktop.in|$APPLICATIONS_DIR/$SLUG-sidebar.desktop
template|share/applications/keys.desktop.in|$APPLICATIONS_DIR/$SLUG-keys.desktop
template|share/applications/switcher.desktop.in|$APPLICATIONS_DIR/$SLUG-switcher.desktop
template|share/applications/wayland-interfaces.desktop.in|$APPLICATIONS_DIR/$SLUG-wayland-interfaces.desktop
ENTRIES
}

# What a template may reference is RENDER_VARS, in lib/render.sh, which fails
# loudly on a placeholder it does not know.

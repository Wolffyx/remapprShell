# shellcheck shell=bash
# The single SRC -> DEST manifest.
#
# --link, --copy and --uninstall all iterate this one list, so the development
# layout and the installed layout cannot drift apart. Adding something to the
# install means adding one line here and nowhere else.
#
# Each entry is: KIND|SRC (repo-relative)|DEST (absolute)
#   dir       a directory: symlinked whole in link mode, copied in copy mode
#   template  a *.in file rendered through envsubst, always copied, made executable
#
# Requires brand.sh to have been sourced.

manifest_entries() {
    cat <<ENTRIES
dir|shell|$QS_CONFIG_DIR
dir|config|$DATA_DIR/config
template|bin/session.sh.in|$BIN_DIR/$SESSION_BIN
template|bin/ctl.sh.in|$BIN_DIR/$CTL_BIN
template|bin/windowsd.py.in|$BIN_DIR/$WINDOWSD_BIN
template|share/dbus/windows.service.in|$DBUS_SERVICES_DIR/$DBUS_NAME.service
symlink|$CTL_BIN|$BIN_DIR/$ALIAS
template|share/systemd/service.in|$SYSTEMD_USER_DIR/$SYSTEMD_UNIT
template|share/systemd/report.in|$SYSTEMD_USER_DIR/$SLUG-report@.service
template|share/applications/launcher.desktop.in|$APPLICATIONS_DIR/$SLUG-launcher.desktop
template|share/applications/search.desktop.in|$APPLICATIONS_DIR/$SLUG-search.desktop
template|share/applications/settings.desktop.in|$APPLICATIONS_DIR/$SLUG-settings.desktop
ENTRIES
}

# Variables a template may reference. Kept explicit so a typo in a template
# fails loudly instead of silently rendering an empty string.
MANIFEST_TEMPLATE_VARS='$SLUG $ALIAS $DISPLAY_NAME $APP_ID $DBUS_NAME $ENV_PREFIX
$SHELL_PACKAGE_ID $VERSION $QS_CONFIG_DIR $CONFIG_DIR $DATA_DIR $STATE_DIR
$BIN_DIR $SESSION_BIN $CTL_BIN $SYSTEMD_UNIT $SAFE_MODE_VAR $DEBUG_VAR'

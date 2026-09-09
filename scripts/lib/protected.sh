# shellcheck shell=bash
# The complete set of files outside our own directories that this project may
# modify.
#
# This list is the contract. The Tier 0 archive captures exactly these, the
# preflight check reports exactly these, and restore puts back exactly these.
# Anything the shell learns to touch later must be added here first -- if it is
# not in this list, it is not backed up, and a restore will not undo it.
#
# Requires brand.sh.

protected_files() {
    cat <<FILES
$XDG_CONFIG_HOME/plasmashellrc
$XDG_CONFIG_HOME/kglobalshortcutsrc
$XDG_CONFIG_HOME/kwinrc
$XDG_CONFIG_HOME/kdeglobals
$XDG_CONFIG_HOME/plasmarc
$XDG_CONFIG_HOME/kcminputrc
$XDG_CONFIG_HOME/ksplashrc
$XDG_CONFIG_HOME/kscreenlockerrc
$XDG_CONFIG_HOME/klipperrc
FILES

    # Every per-shell-package applet layout. These hold the user's panels, so
    # losing one loses their desktop layout.
    find "$XDG_CONFIG_HOME" -maxdepth 1 -name 'plasma-*-appletsrc' 2>/dev/null || true
}

# Directories captured whole.
protected_dirs() {
    cat <<DIRS
$PLASMA_SHELLS_DIR
$PLASMA_LNF_DIR
$COLORS_DIR
$KWIN_SWITCHER_DIR
$XDG_CONFIG_HOME/autostart
DIRS
}

# Files this project owns outright. Captured too, so a restore returns the
# project's own state as well as KDE's.
owned_paths() {
    cat <<OWNED
$CONFIG_DIR
$STATE_DIR
$SYSTEMD_USER_DIR/$SYSTEMD_UNIT
OWNED
}

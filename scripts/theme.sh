#!/usr/bin/env bash
# Installs and activates the look-and-feel package, reversibly.
#
#   apply [--appearance|--package-only]
#                          install the package and activate it
#   revert                 put every key back and remove the package
#   variant [light|dark|auto] [--if-following]
#                          which of light and dark the desktop is in
#   osd ours|plasma        which OSD draws when our package is active
#   style [<id>|revert]    the Qt style every application is drawn in
#   install-style <id> [--run]
#                          how to install a style that is missing
#   status [--json]        what is active, and what would be undone
#
# An apply installs the package and activates it -- which is what makes our
# OSD, splash and logout screens take effect -- and then themes the desktop:
# the colour scheme, icon theme, widget style, Plasma theme, window decorations
# and the Alt+Tab switcher, from the package's `defaults` file.
#
# Which of those it touches is the user's, under `theme.desktop`: the whole
# thing has a switch and so does every part, the settings window offers them as
# checkboxes, and a part that is off keeps whatever System Settings says. They
# default to on, so choosing this shell's theme themes the desktop to match it
# rather than leaving the two disagreeing.
#
# --package-only ignores all of that and installs the package alone.
# --appearance is the older spelling of "yes, the desktop too", kept because
# scripts and documentation use it.
#
# Every key is ledgered, so `revert` puts all of it back whatever was applied.
#
# Keys are written individually through the ledger rather than with
# `lookandfeeltool --apply`. lookandfeeltool overwrites the colour scheme, icon
# theme and cursor theme in one shot and keeps no record of what was there, so
# there would be nothing to revert to.
#
# The command and its options are here. What each part of the desktop is,
# and each command, is in scripts/lib/theme/: what an apply installs
# (install.sh), the package's defaults (defaults.sh), the colours in
# kdeglobals (colours.sh), GTK (gtk.sh), kde-material-you-colors
# (material-you.sh), Plasma's own day and night switch (plasma-switch.sh),
# light or dark (variant.sh), the Qt style (styles.sh), the OSD (osd.sh),
# and `apply`, `revert` and `status` (apply.sh, status.sh).
set -uo pipefail

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
source "$REPO_ROOT/scripts/lib/log.sh"
source "$REPO_ROOT/scripts/lib/brand.sh"
source "$REPO_ROOT/scripts/lib/render.sh"
source "$REPO_ROOT/scripts/lib/kconfig.sh"
source "$REPO_ROOT/scripts/lib/config.sh"
source "$REPO_ROOT/scripts/lib/protected.sh"
source "$REPO_ROOT/scripts/lib/snapshot.sh"
source "$REPO_ROOT/scripts/lib/kwin.sh"

# Read once: most commands here ask for the configuration many times over.
config_load

source "$REPO_ROOT/scripts/lib/theme/install.sh"
source "$REPO_ROOT/scripts/lib/theme/defaults.sh"
source "$REPO_ROOT/scripts/lib/theme/colours.sh"
source "$REPO_ROOT/scripts/lib/theme/gtk.sh"
source "$REPO_ROOT/scripts/lib/theme/material-you.sh"
source "$REPO_ROOT/scripts/lib/theme/plasma-switch.sh"
source "$REPO_ROOT/scripts/lib/theme/variant.sh"
source "$REPO_ROOT/scripts/lib/theme/styles.sh"
source "$REPO_ROOT/scripts/lib/theme/osd.sh"
source "$REPO_ROOT/scripts/lib/theme/apply.sh"
source "$REPO_ROOT/scripts/lib/theme/status.sh"

cmd=${1:-status}
[ $# -gt 0 ] && shift

WITH_APPEARANCE=0
PACKAGE_ONLY=0
WITH_JSON=0
RUN_INSTALL=0
VARIANT_ARG=""
IF_FOLLOWING=0
positional=()
while [ $# -gt 0 ]; do
    case "$1" in
        --appearance) WITH_APPEARANCE=1 ;;
        --package-only) PACKAGE_ONLY=1 ;;
        --json) WITH_JSON=1 ;;
        --run) RUN_INSTALL=1 ;;
        --variant) VARIANT_ARG=${2:-}; shift ;;
        --if-following) IF_FOLLOWING=1 ;;
        -*) die "unknown option: $1" ;;
        *) positional+=("$1") ;;
    esac
    shift
done
set -- "${positional[@]+"${positional[@]}"}"

case "$cmd" in
    apply)         theme_apply ;;
    revert)        theme_revert ;;
    status)        theme_status ;;
    variant)       theme_variant "$@" ;;
    osd)           osd_mode "${1:-status}" ;;
    style)         theme_style "$@" ;;
    install-style) theme_install_style "$@" ;;
    *) die "unknown command: $cmd (expected apply, revert, variant, osd, style, install-style or status)" ;;
esac

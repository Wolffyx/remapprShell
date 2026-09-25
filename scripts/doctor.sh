#!/usr/bin/env bash
# Checks the installation and reports what is wrong, with the fix for each.
#
# Every finding carries a command or a file, because a diagnostic that only
# says something is wrong leaves the person no better off than the symptom did.
#
# Each section is a file of its own under scripts/lib/doctor/. This file is
# the order they run in, how a finding is printed and counted, and the
# verdict.
set -uo pipefail

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
source "$REPO_ROOT/scripts/lib/log.sh"
source "$REPO_ROOT/scripts/lib/brand.sh"
source "$REPO_ROOT/scripts/lib/protected.sh"
source "$REPO_ROOT/scripts/lib/snapshot.sh"
source "$REPO_ROOT/scripts/lib/kconfig.sh"
source "$REPO_ROOT/scripts/lib/accel.sh"
source "$REPO_ROOT/scripts/lib/kwin.sh"
source "$REPO_ROOT/scripts/lib/lockscreen.sh"
source "$REPO_ROOT/scripts/lib/config.sh"
source "$REPO_ROOT/scripts/lib/renderers.sh"
source "$REPO_ROOT/scripts/lib/reports.sh"
source "$REPO_ROOT/scripts/lib/crashes.sh"
source "$REPO_ROOT/scripts/lib/doctor/environment.sh"
source "$REPO_ROOT/scripts/lib/doctor/install.sh"
source "$REPO_ROOT/scripts/lib/doctor/service.sh"
source "$REPO_ROOT/scripts/lib/doctor/previews.sh"
source "$REPO_ROOT/scripts/lib/doctor/configuration.sh"
source "$REPO_ROOT/scripts/lib/doctor/widgets.sh"
source "$REPO_ROOT/scripts/lib/doctor/kde-changes.sh"
source "$REPO_ROOT/scripts/lib/doctor/hazards.sh"
source "$REPO_ROOT/scripts/lib/doctor/restore-points.sh"
source "$REPO_ROOT/scripts/lib/doctor/windows.sh"
source "$REPO_ROOT/scripts/lib/doctor/osd.sh"
source "$REPO_ROOT/scripts/lib/doctor/light-dark.sh"
source "$REPO_ROOT/scripts/lib/doctor/lockscreen.sh"
source "$REPO_ROOT/scripts/lib/doctor/reports.sh"
source "$REPO_ROOT/scripts/lib/doctor/crashes.sh"
source "$REPO_ROOT/scripts/lib/doctor/ai.sh"
source "$REPO_ROOT/scripts/lib/doctor/plasma-services.sh"
source "$REPO_ROOT/scripts/lib/doctor/optional.sh"

# Read once: every section below asks for a setting or two of its own.
config_load

problems=0
warnings=0

ok()   { printf '  %sok%s    %s\n'   "$_c_grn" "$_c_off" "$*"; }
warn() { printf '  %swarn%s  %s\n'   "$_c_yel" "$_c_off" "$*"; warnings=$((warnings + 1)); }
bad()  { printf '  %sfail%s  %s\n'   "$_c_red" "$_c_off" "$*"; problems=$((problems + 1)); }
fix()  { printf '        %s\n' "$*"; }

section() { printf '\n%s==>%s %s\n' "$_c_grn" "$_c_off" "$*"; }

doctor_environment
doctor_install
doctor_service
doctor_previews
doctor_configuration
doctor_widgets
doctor_kde_changes
doctor_hazards
doctor_restore_points
doctor_windows
doctor_osd
doctor_light_dark
# The window daemon's check is the open-windows section's, and it has always
# been printed here, at the end of "light and dark", which it was written
# beneath. It stays here so the report reads as it always has.
doctor_window_daemon
doctor_lockscreen
doctor_reports
doctor_crashes
doctor_ai
doctor_plasma_services
doctor_optional

# ------------------------------------------------------------------- verdict

echo
if [ "$problems" -gt 0 ]; then
    log_error "$problems problem(s), $warnings warning(s)"
    exit 1
fi
log_step "no problems${warnings:+, $warnings warning(s)}"

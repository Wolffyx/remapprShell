#!/usr/bin/env bash
# Checks whether this machine is ready for an install, and reports exactly what
# would be modified -- before anything is modified.
#
# Exits non-zero if a Tier 0 restore point cannot be written, if a required
# dependency is missing, or if a previous install is half-applied.
set -uo pipefail

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
source "$REPO_ROOT/scripts/lib/log.sh"
source "$REPO_ROOT/scripts/lib/brand.sh"
source "$REPO_ROOT/scripts/lib/protected.sh"
source "$REPO_ROOT/scripts/lib/snapshot.sh"

SUGGEST=0
[ "${1:-}" = "--suggest-snapshots" ] && SUGGEST=1

problems=0
warnings=0

fail() { log_error "$*"; problems=$((problems + 1)); }
warn() { log_warn  "$*"; warnings=$((warnings + 1)); }

# --- environment ----------------------------------------------------------

log_step "environment"

if [ "${XDG_CURRENT_DESKTOP:-}" != "KDE" ]; then
    warn "XDG_CURRENT_DESKTOP is '${XDG_CURRENT_DESKTOP:-unset}', not KDE"
fi

if command -v plasmashell >/dev/null 2>&1; then
    plasma_version=$(plasmashell --version 2>/dev/null | awk '{print $2}')
    log_info "  plasmashell   $plasma_version"
    case "$plasma_version" in
        6.*) ;;
        *) fail "Plasma 6 is required, found '$plasma_version'" ;;
    esac
else
    fail "plasmashell not found"
fi

for tool in quickshell jq busctl gdbus; do
    if command -v "$tool" >/dev/null 2>&1; then
        log_info "  $tool $(printf '%*s' $((13 - ${#tool})) '')$("$tool" --version 2>/dev/null | head -1 | cut -c1-40)"
    else
        fail "$tool not found"
    fi
done

if [ -x /usr/lib/qt6/bin/qmllint ]; then
    log_info "  qmllint       $(/usr/lib/qt6/bin/qmllint --version 2>&1)"
else
    warn "Qt6 qmllint not found; 'make lint' will not run"
fi

# --- conflicting shells ---------------------------------------------------

log_step "conflicts"

others=$(pgrep -af 'quickshell' 2>/dev/null | grep -v "quickshell/$SLUG" || true)
if [ -n "$others" ]; then
    warn "another Quickshell instance is running:"
    printf '%s\n' "$others" | sed 's/^/      /' >&2
    log_info "      (that is fine while developing; both draw at once)"
else
    log_info "  no other Quickshell instance"
fi

current_shell=$(kreadconfig6 --file plasmashellrc --group Shell --key ShellPackage 2>/dev/null || true)
log_info "  active Plasma shell package: ${current_shell:-org.kde.plasma.desktop (default)}"

# --- existing install -----------------------------------------------------

log_step "existing install"

installed=0
[ -e "$QS_CONFIG_DIR" ] && installed=1
[ -e "$BIN_DIR/$SESSION_BIN" ] && installed=1

if [ "$installed" = 1 ]; then
    log_info "  $DISPLAY_NAME is installed"
    [ -e "$QS_CONFIG_DIR" ]        || fail "half-applied: $BIN_DIR/$SESSION_BIN exists but $QS_CONFIG_DIR does not"
    [ -e "$BIN_DIR/$SESSION_BIN" ] || fail "half-applied: $QS_CONFIG_DIR exists but $BIN_DIR/$SESSION_BIN does not"
else
    log_info "  not installed yet"
fi

if [ -d "$STATE_DIR" ] && [ ! -e "$QS_CONFIG_DIR" ]; then
    warn "state exists at $STATE_DIR but the shell is not installed (left over from a removal?)"
fi

# --- restore tiers --------------------------------------------------------

log_step "restore points"
snapshot_report_tiers

# Tier 0 is the one that must work. Prove it by writing to the directory it
# will use, rather than assuming.
probe="$(snapshot_root)/.probe"
if mkdir -p "$(dirname "$probe")" 2>/dev/null && touch "$probe" 2>/dev/null; then
    rm -f "$probe"
    avail=$(df -Pk "$(snapshot_root)" 2>/dev/null | awk 'NR==2 {print int($4/1024)}')
    log_info "  tier 0 target writable, ${avail:-?} MiB free"
else
    fail "cannot write a tier 0 restore point under $(snapshot_root)"
fi

# --- what would change ----------------------------------------------------

log_step "files this project may modify"
while IFS= read -r path; do
    [ -n "$path" ] || continue
    if [ -e "$path" ]; then
        log_info "  exists   $path"
    else
        log_info "  absent   $path"
    fi
done < <(protected_files; protected_dirs)

log_step "paths this project owns"
while IFS= read -r path; do
    [ -n "$path" ] || continue
    log_info "  $path"
done < <(owned_paths)

[ "$SUGGEST" = 1 ] && snapshot_suggest_commands

# --- verdict --------------------------------------------------------------

echo >&2
if [ "$problems" -gt 0 ]; then
    log_error "preflight failed: $problems problem(s), $warnings warning(s)"
    exit 1
fi
log_step "preflight passed${warnings:+ ($warnings warning(s))}"

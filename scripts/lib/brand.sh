# shellcheck shell=bash
# Reads branding.json and exports every derived name and path.
#
# This is the ONLY place in the codebase that turns the project name into
# concrete strings. Nothing else may hardcode the slug -- see scripts/lint-slug.sh,
# which fails CI if anything does.
#
# Sourced, never executed. Requires REPO_ROOT to be set, or infers it.

: "${REPO_ROOT:=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

_brand_file="$REPO_ROOT/branding.json"
[ -f "$_brand_file" ] || { echo "error: branding.json not found at $_brand_file" >&2; exit 1; }
command -v jq >/dev/null 2>&1 || { echo "error: jq is required" >&2; exit 1; }

_brand_get() {
    local v
    v=$(jq -er "$1" "$_brand_file") || {
        echo "error: branding.json is missing $1" >&2; exit 1
    }
    printf '%s' "$v"
}

# --- identity -------------------------------------------------------------
SLUG=$(_brand_get '.slug')
ALIAS=$(_brand_get '.alias')
DISPLAY_NAME=$(_brand_get '.displayName')
APP_ID=$(_brand_get '.appId')
DBUS_NAME=$(_brand_get '.dbusName')
ENV_PREFIX=$(_brand_get '.envPrefix')
SHELL_PACKAGE_ID=$(_brand_get '.shellPackageId')
REPO_PUSH=$(_brand_get '.repo.push')
REPO_FETCH=$(_brand_get '.repo.fetch')
VERSION=$(cat "$REPO_ROOT/VERSION" 2>/dev/null || echo "0.0.0")

# A slug becomes part of file paths, a DBus name and a KConfig group, so it is
# validated rather than trusted. This is also the guard that makes `rmpr rename`
# safe.
case "$SLUG" in
    [a-z][a-z0-9-]*) : ;;
    *) echo "error: slug '$SLUG' must be lowercase alphanumeric with dashes, starting with a letter" >&2; exit 1 ;;
esac

# --- derived paths --------------------------------------------------------
: "${XDG_CONFIG_HOME:=$HOME/.config}"
: "${XDG_DATA_HOME:=$HOME/.local/share}"
: "${XDG_STATE_HOME:=$HOME/.local/state}"

QS_CONFIG_DIR="$XDG_CONFIG_HOME/quickshell/$SLUG"   # the shell itself
CONFIG_DIR="$XDG_CONFIG_HOME/$SLUG"                 # user-authored config only
DATA_DIR="$XDG_DATA_HOME/$SLUG"                     # user widgets, assets
STATE_DIR="$XDG_STATE_HOME/$SLUG"                   # ledgers, snapshots, health
BIN_DIR="$HOME/.local/bin"
SYSTEMD_USER_DIR="$XDG_CONFIG_HOME/systemd/user"
PLASMA_SHELLS_DIR="$XDG_DATA_HOME/plasma/shells"
PLASMA_LNF_DIR="$XDG_DATA_HOME/plasma/look-and-feel"
PLASMA_PLASMOIDS_DIR="$XDG_DATA_HOME/plasma/plasmoids"
KWIN_SWITCHER_DIR="$XDG_DATA_HOME/kwin/tabbox"
COLORS_DIR="$XDG_DATA_HOME/color-schemes"
APPLICATIONS_DIR="$XDG_DATA_HOME/applications"

# --- derived names --------------------------------------------------------
SESSION_BIN="$SLUG-session"
CTL_BIN="$SLUG-ctl"
SYSTEMD_UNIT="$SLUG.service"
LNF_PACKAGE_ID="$SLUG.lookandfeel"
SAFE_MODE_VAR="${ENV_PREFIX}_SAFE_MODE"
DEBUG_VAR="${ENV_PREFIX}_DEBUG"

export SLUG ALIAS DISPLAY_NAME APP_ID DBUS_NAME ENV_PREFIX SHELL_PACKAGE_ID \
       REPO_PUSH REPO_FETCH VERSION \
       QS_CONFIG_DIR CONFIG_DIR DATA_DIR STATE_DIR BIN_DIR SYSTEMD_USER_DIR \
       PLASMA_SHELLS_DIR PLASMA_LNF_DIR PLASMA_PLASMOIDS_DIR KWIN_SWITCHER_DIR \
       COLORS_DIR APPLICATIONS_DIR \
       SESSION_BIN CTL_BIN SYSTEMD_UNIT LNF_PACKAGE_ID SAFE_MODE_VAR DEBUG_VAR

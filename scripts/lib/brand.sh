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
PLASMA_DESKTOPTHEME_DIR="$XDG_DATA_HOME/plasma/desktoptheme"
KWIN_SWITCHER_DIR="$XDG_DATA_HOME/kwin/tabbox"
KWIN_SCRIPTS_DIR="$XDG_DATA_HOME/kwin/scripts"
DBUS_SERVICES_DIR="$XDG_DATA_HOME/dbus-1/services"
COLORS_DIR="$XDG_DATA_HOME/color-schemes"
APPLICATIONS_DIR="$XDG_DATA_HOME/applications"

# --- derived names --------------------------------------------------------
SESSION_BIN="$SLUG-session"
CTL_BIN="$SLUG-ctl"
WINDOWSD_BIN="$SLUG-windowsd"
KWIN_SCRIPT_ID="$SLUG-windows"
# A second script, and deliberately not the same one: the window list is a
# read and says so in its own header, while an edge trigger acts. Separate
# packages also mean enabling one does not enable the other.
KWIN_EDGES_SCRIPT_ID="$SLUG-edges"
SYSTEMD_UNIT="$SLUG.service"
LNF_PACKAGE_ID="$SLUG.lookandfeel"

# The Plasma renderer needs a shell package of its own rather than a flag on
# the first one. plasmashell namespaces both the applet layout
# (plasma-<id>-appletsrc) and the panel views (plasmashellrc [PlasmaViews])
# by package id, so two ids means switching renderers cannot overwrite the
# other renderer's layout -- the switch is non-destructive by construction
# rather than by care.
PLASMA_SHELL_PACKAGE_ID="${SLUG}-plasma.desktop"
SAFE_MODE_VAR="${ENV_PREFIX}_SAFE_MODE"
# Set to keep a command away from the live session -- no DBus calls, no service
# restarts, no package cache rebuild. Tests run against a throwaway HOME but
# share the real session bus, so without this a test switching shell packages
# would switch the desktop the person is sitting in front of.
# Is this shell's Quickshell running -- installed, or straight from a checkout?
#
# `make run` starts it from the working tree ("quickshell -n -p
# shell/shell.qml"), whose command line has nothing of the installed config
# directory in it. Matching only that directory made every "is it running?"
# answer no during exactly the kind of session someone runs while working on
# it: `rmpr status` said no with a panel on screen, and `renderer set` refused
# to switch because it believed nothing would draw.
#
# `pgrep -x` matches the process name, so this cannot match the script asking
# the question -- the trap that killed a session's own shell once already.
# The candidate processes, as "pid command". Its own function so a test can
# put known lines in front of the matching without inventing a process.
_shell_processes() { pgrep -a -x quickshell 2>/dev/null; }

shell_running() { [ -n "$(shell_running_from)" ]; }

# Which of the two it is, for output that has to say something to a person.
# Prints "installed" or "working tree", and nothing at all when neither.
shell_running_from() {
    local line
    while IFS= read -r line; do
        case "$line" in
            *"$QS_CONFIG_DIR"*)             printf 'installed'; return 0 ;;
            *"$REPO_ROOT/shell/shell.qml"*) printf 'working tree'; return 0 ;;
        esac
    done < <(_shell_processes)
    return 1
}

# The config path the running shell was started with, which is what its IPC
# socket is keyed by. A script that talks to the shell must name the copy that
# is actually running: `make run` from this tree, or the installed one. The
# generated CLI answers the same question and knows about other checkouts too;
# a script in this tree only ever has these two to choose between.
shell_ipc_path() {
    if [ "$(shell_running_from)" = "working tree" ]; then
        printf '%s/shell/shell.qml' "$REPO_ROOT"
    else
        printf '%s/shell.qml' "$QS_CONFIG_DIR"
    fi
}

NO_SESSION_VAR="${ENV_PREFIX}_NO_SESSION"
DEBUG_VAR="${ENV_PREFIX}_DEBUG"

# Asked before every call that reaches the running desktop. One definition,
# because the scripts that each kept their own copy were the ones that
# remembered; the two that did not restarted the user's global shortcuts and
# reloaded KWin on every test run.
session_available() { [ -z "${!NO_SESSION_VAR:-}" ]; }


# Which profile the shell is actually reading. Held in one small file so that
# switching cannot damage the profile being switched away from.
#
# Here rather than in profile.sh because more than one command needs the
# answer, and the one that did not ask -- `preset apply` -- wrote to
# profiles/default while the shell read another profile entirely. Every layout
# chosen in the settings window landed in a file nothing was reading.
active_profile() {
    local state="$CONFIG_DIR/state.json"
    [ -f "$state" ] && jq -r '.profile // "default"' "$state" 2>/dev/null || echo default
}

profile_dir() { printf '%s/profiles/%s' "$CONFIG_DIR" "$(active_profile)"; }
profile_file() { printf '%s/shell.json' "$(profile_dir)"; }

export SLUG ALIAS DISPLAY_NAME APP_ID DBUS_NAME ENV_PREFIX SHELL_PACKAGE_ID \
       REPO_PUSH REPO_FETCH VERSION \
       QS_CONFIG_DIR CONFIG_DIR DATA_DIR STATE_DIR BIN_DIR SYSTEMD_USER_DIR \
       PLASMA_SHELLS_DIR PLASMA_LNF_DIR PLASMA_PLASMOIDS_DIR PLASMA_DESKTOPTHEME_DIR \
       KWIN_SWITCHER_DIR KWIN_SCRIPTS_DIR DBUS_SERVICES_DIR \
       COLORS_DIR APPLICATIONS_DIR \
       SESSION_BIN CTL_BIN WINDOWSD_BIN KWIN_SCRIPT_ID KWIN_EDGES_SCRIPT_ID SYSTEMD_UNIT LNF_PACKAGE_ID PLASMA_SHELL_PACKAGE_ID \
       SAFE_MODE_VAR DEBUG_VAR NO_SESSION_VAR

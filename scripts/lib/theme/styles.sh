# shellcheck shell=bash
# The Qt style every application is drawn in: the styles worth offering,
# whether each is installed, and the `style` and `install-style` commands.
#
# Sourced by theme.sh, never executed. Requires brand.sh, log.sh and
# kconfig.sh.

# The Qt styles worth offering:
#   id | the key Qt knows it by | its plugin, a glob in plugins/styles | package | what it is
#
# Qt matches style keys without regard to case, and KDE writes the key into
# kdeglobals [KDE] widgetStyle. Fusion is compiled into Qt, so it has no
# plugin. Union's plugin name and key are *not* verified -- it was not
# installed on the machine this was written on, and pacman's file lists were
# not synced -- so check both the first time it is.
STYLES=(
    "breeze|Breeze|breeze6.so|breeze|Plasma's own"
    "fusion|Fusion||qt6-base|Qt's own, built in"
    "darkly|Darkly|darkly6.so|darkly|Breeze, rounder and translucent"
    "kvantum|kvantum|libkvantum.so|kvantum|drawn by Kvantum's theme engine"
    "union|Union|*union*.so|union|KDE's new style, one for QtQuick and QtWidgets alike"
)

style_field() {   # <id> <n>
    local s
    for s in "${STYLES[@]}"; do
        [ "${s%%|*}" = "$1" ] && { cut -d'|' -f"$2" <<< "$s"; return 0; }
    done
    return 1
}
style_ids() { local s; for s in "${STYLES[@]}"; do printf '%s ' "${s%%|*}"; done; }

# Where Qt looks for style plugins. The tests point it at a directory of
# their own, so what is installed on the machine running them does not
# change the answer.
STYLE_DIRS_VAR="${ENV_PREFIX}_STYLE_DIRS"
style_dirs() {
    if [ -n "${!STYLE_DIRS_VAR:-}" ]; then
        tr ':' '\n' <<< "${!STYLE_DIRS_VAR}"
        return
    fi
    local d
    for d in $(tr ':' ' ' <<< "${QT_PLUGIN_PATH:-}") /usr/lib/qt6/plugins /usr/lib64/qt6/plugins; do
        printf '%s/styles\n' "$d"
    done
}

style_installed() {
    local glob d
    glob=$(style_field "$1" 3) || return 1
    [ -n "$glob" ] || return 0
    while IFS= read -r d; do
        compgen -G "$d/$glob" >/dev/null && return 0
    done < <(style_dirs)
    return 1
}

# The id of the style in use, or kdeglobals' own value when it is none of ours.
style_active_id() {
    local current s
    current=$(kreadconfig6 --file kdeglobals --group KDE --key widgetStyle --default '')
    for s in "${STYLES[@]}"; do
        [ "$(cut -d'|' -f2 <<< "$s" | tr '[:upper:]' '[:lower:]')" = "${current,,}" ] && { printf '%s' "${s%%|*}"; return; }
    done
    printf '%s' "$current"
}

# What System Settings' style page sends: KDE applications already running
# change style on it, the rest when next started.
notify_style_changed() {
    session_available || return 0
    busctl --user emit /KGlobalSettings org.kde.KGlobalSettings notifyChange ii 2 0 >/dev/null 2>&1 || true
}

# How to install a package here, printed for a person to run. Only pacman is
# known; elsewhere the package names are not known either.
install_command() {
    command -v pacman >/dev/null 2>&1 || return 1
    printf 'sudo pacman -S --needed %s' "$1"
}

# Its own ledger scope, so a style tried from the settings page can be
# undone without taking the whole theme with it. `revert` undoes both.
theme_style() {   # [<id>|revert]
    local want active s id key glob pkg label
    want=${1:-}
    if [ -z "$want" ]; then
        active=$(style_active_id)
        for s in "${STYLES[@]}"; do
            IFS='|' read -r id key glob pkg label <<< "$s"
            printf '  %-8s %-8s %-14s %s%s\n' "$id" "$key" \
                "$(style_installed "$id" && echo installed || echo 'not installed')" "$label" \
                "$([ "$id" = "$active" ] && echo '  (in use)')"
        done
        exit 0
    fi
    if [ "$want" = revert ]; then
        kconfig_revert style
        notify_style_changed
        exit 0
    fi
    key=$(style_field "$want" 2) || die "unknown style '$want' (one of: $(style_ids))"
    style_installed "$want" || die "$want is not installed; '$ALIAS theme install-style $want' says how"
    kconfig_set style kdeglobals KDE widgetStyle "$key"
    notify_style_changed
    log_step "widget style: $key"
    log_info "KDE applications already open change at once; others when next started"
}

# Prints the command; runs it only when asked, in a terminal, because it
# installs a system package and asks for a password.
theme_install_style() {   # <id>, and --run in $RUN_INSTALL
    local want pkg how
    want=${1:?usage: $ALIAS theme install-style <id> [--run]}
    pkg=$(style_field "$want" 4) || die "unknown style '$want' (one of: $(style_ids))"
    if style_installed "$want"; then
        log_info "$want is already installed: $ALIAS theme style $want"
        exit 0
    fi
    how=$(install_command "$pkg") || die "no package manager known here; install the package that provides the '$want' Qt style"
    if [ "$RUN_INSTALL" = 1 ]; then
        [ -t 0 ] || die "--run needs a terminal: the install asks for a password"
        log_step "$how"
        $how || die "the install did not finish"
        log_info "now: $ALIAS theme style $want"
        exit 0
    fi
    printf '%s\n' "$how"
    log_info "run that in a terminal -- it needs root -- then: $ALIAS theme style $want"
}

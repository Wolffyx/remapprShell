#!/usr/bin/env bash
# What this shell needs from the distribution, and installing what is missing.
#
#   deps.sh check   [--build]          list what is missing; non-zero if anything is
#   deps.sh install [--build] [--yes]  install what is missing, after asking
#   deps.sh family                     arch | fedora | debian | unknown
#
# --build adds what `make plugin` needs: a compiler, CMake and the Qt and KF6
# development files. Without it only what the shell runs with is considered.
#
# Deliberately standalone: it sources nothing but log.sh. brand.sh needs jq,
# and jq is one of the things this installs -- on a fresh machine everything
# else in scripts/ fails before it could say what is missing.
#
# Each dependency is checked by what it provides -- a command, a Python
# module, a CMake package -- not by a package name, so the check is the same
# on every distribution and says nothing wrong about a package installed some
# other way. Only the install needs the names, one per family. Plasma itself
# is not here: this is a shell for Plasma 6, and preflight says so when it is
# missing.
#
# Quickshell is the one package that is not in every family's own
# repositories. On Fedora it comes from the errornointernet/quickshell COPR
# and on Ubuntu from the avengemedia/danklinux PPA, the same sources other
# Quickshell shells for Plasma use; each is added only when Quickshell itself
# is missing. Debian proper has neither, and is told so.
#
# For the tests: DEPS_OS_RELEASE names the os-release file, DEPS_CMAKE_DIRS
# the CMake package directories (colon-separated), and DEPS_DRY=1 prints the
# commands instead of running them.
set -uo pipefail

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
source "$REPO_ROOT/scripts/lib/log.sh"

# id | kind | provides | arch | fedora | debian
#
# `provides` is cmd:<command>, py:<module> or cmake:<package>. A family's
# column may name several packages, space-separated. Qt's Wayland client is
# the one that needs two, found by building in containers (2026-09-25): on
# Fedora its CMake files name a metatypes file that qt6-qtbase-private-devel
# ships, and on Ubuntu qtwaylandscanner moved to qt6-base-dev-tools.
DEPS=(
    "quickshell|run|cmd:quickshell|quickshell|quickshell-git|quickshell"
    "jq|run|cmd:jq|jq|jq|jq"
    "git|run|cmd:git|git|git|git"
    "make|run|cmd:make|make|make|make"
    "gdbus|run|cmd:gdbus|glib2|glib2|libglib2.0-bin"
    "wl-clipboard|run|cmd:wl-paste|wl-clipboard|wl-clipboard|wl-clipboard"
    "notify-send|run|cmd:notify-send|libnotify|libnotify|libnotify-bin"
    "kdialog|run|cmd:kdialog|kdialog|kdialog|kdialog"
    "python-gobject|run|py:gi|python-gobject|python3-gobject|python3-gi"
    "pillow|run|py:PIL|python-pillow|python3-pillow|python3-pil"
    "cmake|build|cmd:cmake|cmake|cmake|cmake"
    "c++|build|cmd:c++|gcc|gcc-c++|g++"
    "wayland-scanner|build|cmd:wayland-scanner|wayland|wayland-devel|libwayland-bin"
    "qt6-base|build|cmake:Qt6Gui|qt6-base|qt6-qtbase-devel|qt6-base-dev"
    "qt6-declarative|build|cmake:Qt6Qml|qt6-declarative|qt6-qtdeclarative-devel|qt6-declarative-dev"
    "qt6-wayland|build|cmake:Qt6WaylandClient|qt6-wayland|qt6-qtwayland-devel qt6-qtbase-private-devel|qt6-wayland-dev qt6-base-dev-tools"
    "kguiaddons|build|cmake:KF6GuiAddons|kguiaddons|kf6-kguiaddons-devel|libkf6guiaddons-dev"
)

OS_RELEASE=${DEPS_OS_RELEASE:-/etc/os-release}

# --- the distribution -----------------------------------------------------

# The family, from ID and then ID_LIKE: CachyOS, EndeavourOS and Manjaro say
# arch there, Nobara fedora, Ubuntu and Mint debian.
os_field() {
    sed -n "s/^$1=//p" "$OS_RELEASE" 2>/dev/null | head -1 | tr -d '"'
}

family() {
    local id like word
    id=$(os_field ID)
    like=$(os_field ID_LIKE)
    for word in $id $like; do
        case "$word" in
            arch)                  echo arch; return ;;
            fedora|rhel)           echo fedora; return ;;
            debian|ubuntu)         echo debian; return ;;
        esac
    done
    echo unknown
}

is_ubuntu() {
    case " $(os_field ID) $(os_field ID_LIKE) " in
        *" ubuntu "*) return 0 ;;
    esac
    return 1
}

# --- what is there ----------------------------------------------------------

cmake_dirs() {
    if [ -n "${DEPS_CMAKE_DIRS:-}" ]; then
        printf '%s\n' "$DEPS_CMAKE_DIRS" | tr ':' '\n'
        return
    fi
    printf '%s\n' /usr/lib/cmake /usr/lib64/cmake /usr/share/cmake /usr/lib/*-linux-gnu/cmake
}

provided() {
    local what=$1 dir
    case "$what" in
        cmd:*)   command -v "${what#cmd:}" >/dev/null 2>&1 ;;
        py:*)    python3 -c "import ${what#py:}" >/dev/null 2>&1 ;;
        cmake:*)
            while IFS= read -r dir; do
                [ -d "$dir/${what#cmake:}" ] && return 0
            done < <(cmake_dirs)
            return 1 ;;
        *)       return 1 ;;
    esac
}

# The ids missing, one per line. `build` includes the build dependencies.
missing() {
    local build=$1 entry id kind provides
    for entry in "${DEPS[@]}"; do
        IFS='|' read -r id kind provides _ <<< "$entry"
        [ "$kind" = build ] && [ "$build" = 0 ] && continue
        provided "$provides" || printf '%s\n' "$id"
    done
}

# The packages that provide the given ids, for a family.
packages_for() {
    local fam=$1; shift
    local col entry id want
    case "$fam" in
        arch) col=4 ;; fedora) col=5 ;; debian) col=6 ;; *) return 1 ;;
    esac
    for want in "$@"; do
        for entry in "${DEPS[@]}"; do
            id=${entry%%|*}
            [ "$id" = "$want" ] && printf '%s\n' "$entry" | cut -d'|' -f"$col" | tr ' ' '\n'
        done
    done
}

# --- installing -------------------------------------------------------------

run() {
    if [ "${DEPS_DRY:-0}" = 1 ]; then
        printf 'would run: %s\n' "$*"
        return 0
    fi
    "$@"
}

# Root needs nothing; anyone else goes through sudo, which asks for the
# password itself.
as_root() {
    if [ "$(id -u)" = 0 ]; then
        run "$@"
    elif command -v sudo >/dev/null 2>&1 || [ "${DEPS_DRY:-0}" = 1 ]; then
        run sudo "$@"
    else
        log_error "installing packages needs root, and sudo is not installed"
        return 1
    fi
}

ask() {
    local answer
    [ "$YES" = 1 ] && return 0
    # From the terminal, not stdin: under `curl ... | bash` stdin is the script.
    if [ ! -r /dev/tty ]; then
        log_error "nobody to ask; run again with --yes to install without asking"
        return 1
    fi
    printf '%s [Y/n] ' "$1" > /dev/tty
    read -r answer < /dev/tty || return 1
    case "$answer" in
        ''|y|Y|yes|Yes) return 0 ;;
        *) return 1 ;;
    esac
}

install_missing() {
    local build=$1 fam ids pkgs
    fam=$(family)
    mapfile -t ids < <(missing "$build")
    if [ ${#ids[@]} -eq 0 ]; then
        log_step "everything needed is installed"
        return 0
    fi

    if [ "$fam" = unknown ]; then
        log_error "this distribution is not one the installer knows ($(os_field ID))."
        log_info  "Install these by hand, then run the setup again:"
        printf '  %s\n' "${ids[@]}" >&2
        return 1
    fi

    mapfile -t pkgs < <(packages_for "$fam" "${ids[@]}")
    log_step "missing: ${ids[*]}"
    log_info "  packages ($fam): ${pkgs[*]}"
    ask "Install them now?" || { log_info "nothing was installed."; return 1; }

    local quickshell=0 id
    for id in "${ids[@]}"; do [ "$id" = quickshell ] && quickshell=1; done

    case "$fam" in
        arch)
            # -S alone, never -Sy: refreshing the database without upgrading
            # is the partial upgrade Arch warns against.
            as_root pacman -S --needed --noconfirm "${pkgs[@]}" ;;
        fedora)
            if [ $quickshell = 1 ]; then
                as_root dnf copr enable -y errornointernet/quickshell || return 1
            fi
            as_root dnf install -y "${pkgs[@]}" ;;
        debian)
            if [ $quickshell = 1 ] && ! is_ubuntu; then
                log_error "Quickshell has no package for Debian itself; build it from https://quickshell.org, then run the setup again."
                return 1
            fi
            # The lists first: on a fresh machine even the package that adds
            # a PPA is not found until they are read (seen in a container).
            as_root apt-get update || return 1
            if [ $quickshell = 1 ]; then
                as_root apt-get install -y software-properties-common || return 1
                # add-apt-repository reads the lists again itself.
                as_root add-apt-repository -y ppa:avengemedia/danklinux || return 1
            fi
            as_root apt-get install -y "${pkgs[@]}" ;;
    esac || { log_error "the package manager failed"; return 1; }

    [ "${DEPS_DRY:-0}" = 1 ] && return 0

    # Said again rather than trusted: a package that installed but did not
    # provide what it was for is a wrong name in the table above.
    mapfile -t ids < <(missing "$build")
    if [ ${#ids[@]} -gt 0 ]; then
        log_error "still missing after the install: ${ids[*]}"
        return 1
    fi
    log_step "everything needed is installed"
}

# --- the command ------------------------------------------------------------

cmd=${1:-check}; shift || true
BUILD=0
YES=0
while [ $# -gt 0 ]; do
    case "$1" in
        --build) BUILD=1 ;;
        --yes)   YES=1 ;;
        *)       die "unknown argument: $1" ;;
    esac
    shift
done

case "$cmd" in
    family)
        family ;;
    check)
        mapfile -t ids < <(missing "$BUILD")
        [ ${#ids[@]} -eq 0 ] && exit 0
        printf '%s\n' "${ids[@]}"
        exit 1 ;;
    install)
        install_missing "$BUILD" ;;
    -h|--help)
        sed -n '2,9p' "${BASH_SOURCE[0]}" | sed 's/^# \?//' ;;
    *)
        die "unknown command: $cmd (check | install | family)" ;;
esac

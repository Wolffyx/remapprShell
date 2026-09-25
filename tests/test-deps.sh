#!/usr/bin/env bash
# What the installer asks the distribution for.
#
# deps.sh is the first thing a fresh machine runs, before jq -- so before
# anything else in scripts/ can -- and a wrong answer here is an install that
# stops on step one, or one that adds a package repository nobody needed.
# Checked: which family an os-release names, that a dependency is found by
# what it provides rather than by a package name, and the exact commands an
# install would run on each family, with the Quickshell repositories added
# only when Quickshell itself is missing.
set -uo pipefail
REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
source "$REPO_ROOT/tests/lib/harness.sh"
harness_init --no-home

DEPS="$REPO_ROOT/scripts/deps.sh"
OS="$SANDBOX/os-release"
CMAKE="$SANDBOX/cmake"
mkdir -p "$CMAKE"
export DEPS_OS_RELEASE="$OS" DEPS_CMAKE_DIRS="$CMAKE" DEPS_DRY=1

os() { printf '%s\n' "$@" > "$OS"; }

# ---- the family ---------------------------------------------------------------

family_of() { os "$@"; "$DEPS" family; }

check "Arch"                 "$(family_of ID=arch)" arch
check "CachyOS, by ID_LIKE"  "$(family_of ID=cachyos ID_LIKE=arch)" arch
check "Fedora"               "$(family_of ID=fedora)" fedora
check "Nobara, by ID_LIKE"   "$(family_of ID=nobara 'ID_LIKE="rhel centos fedora"')" fedora
check "Ubuntu"               "$(family_of ID=ubuntu ID_LIKE=debian)" debian
check "Mint, by ID_LIKE"     "$(family_of ID=linuxmint 'ID_LIKE="ubuntu debian"')" debian
check "Debian"               "$(family_of ID=debian)" debian
check "anything else"        "$(family_of ID=gentoo)" unknown

# ---- what is there ------------------------------------------------------------
#
# A PATH of stand-ins: every command the table checks for, and a python3 that
# imports what it is told to. Each check then takes one away.

STUBS="$SANDBOX/stubs"
mkdir -p "$STUBS"
for c in quickshell jq git make gdbus wl-paste notify-send kdialog cmake c++ wayland-scanner; do
    printf '#!/bin/sh\nexit 0\n' > "$STUBS/$c"; chmod +x "$STUBS/$c"
done
cat > "$STUBS/python3" <<'STUB'
#!/bin/sh
# python3 -c "import <module>": fails for the modules named in NO_PY.
mod=${2#import }
case " ${NO_PY:-} " in *" $mod "*) exit 1 ;; esac
exit 0
STUB
chmod +x "$STUBS/python3"
cat > "$STUBS/fc-list" <<'STUB'
#!/bin/sh
# fc-list : family -- every family but the ones named in NO_FONT.
for f in "Material Symbols Rounded" "Rubik,Rubik Light" "Noto Sans"; do
    case ",${NO_FONT:-}," in *",${f%%,*},"*) continue ;; esac
    printf '%s\n' "$f"
done
STUB
chmod +x "$STUBS/fc-list"
for p in Qt6Gui Qt6Qml Qt6WaylandClient KF6GuiAddons; do mkdir -p "$CMAKE/$p"; done

# Nothing else on PATH but the few tools deps.sh itself uses: with /usr/bin
# there, this machine's own jq and quickshell answer for the stand-ins taken
# away.
CORE="$SANDBOX/core"
mkdir -p "$CORE"
for t in bash env sh sed head tr cut id dirname cat grep; do
    ln -s "$(command -v "$t")" "$CORE/$t"
done
deps() { PATH="$STUBS:$CORE" "$DEPS" "$@"; }
os ID=arch

deps check >/dev/null; check "nothing missing, nothing listed" "$?" 0
deps check --build >/dev/null; check "nor for a build" "$?" 0

rm "$STUBS/jq"
check "a command gone is missing" "$(deps check)" jq
check "and non-zero" "$(deps check >/dev/null; echo $?)" 1
printf '#!/bin/sh\nexit 0\n' > "$STUBS/jq"; chmod +x "$STUBS/jq"

check "a Python module gone is missing" "$(NO_PY=gi deps check)" python-gobject

check "a font gone is missing" "$(NO_FONT="Material Symbols Rounded" deps check)" material-symbols
check "a family's other names do not hide it" "$(NO_FONT=Rubik deps check)" rubik

rmdir "$CMAKE/KF6GuiAddons"
check "a CMake package gone matters to a build" "$(deps check --build)" kguiaddons
check "and not to the shell" "$(deps check; echo $?)" 0
mkdir -p "$CMAKE/KF6GuiAddons"

# ---- the commands, per family ---------------------------------------------------

rm "$STUBS/quickshell" "$STUBS/jq"
install_says() { deps install --yes 2>/dev/null; }

os ID=cachyos ID_LIKE=arch
got=$(install_says)
contains "Arch: pacman, only what is missing" "$got" "pacman -S --needed --noconfirm quickshell jq"
case "$got" in *"-Sy"*) check "Arch: never -Sy" "$got" "(no -Sy)" ;; *) check "Arch: never -Sy" yes yes ;; esac

os ID=fedora
got=$(install_says)
contains "Fedora: the Quickshell COPR" "$got" "dnf copr enable -y errornointernet/quickshell"
contains "Fedora: its package name" "$got" "dnf install -y quickshell-git jq"

os ID=ubuntu ID_LIKE=debian
got=$(install_says)
contains "Ubuntu: the Quickshell PPA" "$got" "add-apt-repository -y ppa:avengemedia/danklinux"
contains "Ubuntu: apt" "$got" "apt-get install -y quickshell jq"

os ID=debian
check "Debian: no Quickshell package, said so" "$(deps install --yes >/dev/null 2>&1; echo $?)" 1

# With Quickshell there, no repository is added anywhere.
printf '#!/bin/sh\nexit 0\n' > "$STUBS/quickshell"; chmod +x "$STUBS/quickshell"
os ID=fedora
got=$(install_says)
case "$got" in *copr*) check "Fedora: no COPR without need" "$got" "(no copr)" ;; *) check "Fedora: no COPR without need" yes yes ;; esac
os ID=ubuntu ID_LIKE=debian
got=$(install_says)
case "$got" in *add-apt-repository*) check "Ubuntu: no PPA without need" "$got" "(no PPA)" ;; *) check "Ubuntu: no PPA without need" yes yes ;; esac

os ID=gentoo
check "an unknown family installs nothing" "$(deps install --yes >/dev/null 2>&1; echo $?)" 1

printf '#!/bin/sh\nexit 0\n' > "$STUBS/jq"; chmod +x "$STUBS/jq"
os ID=arch
check "nothing missing, nothing run" "$(install_says)" ""

echo "== fonts =="
os ID=arch
got=$(NO_FONT="Material Symbols Rounded" deps install --yes 2>/dev/null)
contains "Arch: the font is a package" "$got" "pacman -S --needed --noconfirm ttf-material-symbols-variable"
os ID=fedora
got=$(NO_FONT="Material Symbols Rounded" deps install --yes 2>/dev/null)
contains "Fedora: fetched, not installed" "$got" "curl -fsSL -o $HOME/.local/share/fonts/MaterialSymbolsRounded[FILL,GRAD,opsz,wght].ttf"
case "$got" in *"dnf install"*) check "Fedora: no dnf for a font alone" "$got" "(no dnf)" ;; *) check "Fedora: no dnf for a font alone" yes yes ;; esac
contains "and the cache refreshed" "$got" "fc-cache -f"


harness_done

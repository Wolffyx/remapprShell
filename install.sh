#!/usr/bin/env bash
# The one-line install:
#
#   curl -fsSL https://raw.githubusercontent.com/Wolffyx/remapprShell/main/install.sh | bash
#
# Fetches the shell's source, installs what the distribution has to provide,
# and hands over to the guided setup -- which asks every question first and
# changes nothing until its summary is confirmed. Run again, it updates the
# source it fetched before and sets up again.
#
#   --channel <branch>   main (releases, the default) or dev
#   --dir <path>         where the source goes (default: the shell's data
#                        directory, .../source)
#   --yes                install packages without asking, and take the
#                        setup's defaults
#   --reinstall          take off what is installed and set it up again
#   --fresh              with --reinstall: start from no settings
#   --                   everything after it goes to the setup as it is
#
# This file is the one part of the install that runs before the source is
# here, so it knows the repository's address and nothing else: the shell's
# name comes from the branding.json it fetches, as it does everywhere else.
set -euo pipefail

REPO=${REPO:-https://github.com/Wolffyx/remapprShell.git}
CHANNEL=main
DIR=""
YES=0
REINSTALL=0
FRESH=0
SETUP_ARGS=()

say()  { printf '\033[32m==>\033[0m %s\n' "$*" >&2; }
fail() { printf '\033[31merror:\033[0m %s\n' "$*" >&2; exit 1; }

while [ $# -gt 0 ]; do
    case "$1" in
        --channel) [ $# -ge 2 ] || fail "--channel needs a branch"; CHANNEL=$2; shift ;;
        --dir)     [ $# -ge 2 ] || fail "--dir needs a path"; DIR=$2; shift ;;
        --yes)     YES=1 ;;
        --reinstall) REINSTALL=1 ;;
        --fresh)   FRESH=1 ;;
        --)        shift; SETUP_ARGS+=("$@"); break ;;
        -h|--help) printf '%s\n' "usage: install.sh [--channel main|dev] [--dir <path>] [--yes] [--reinstall [--fresh]] [-- <setup arguments>]"; exit 0 ;;
        *)         fail "unknown argument: $1" ;;
    esac
    shift
done

# Under `curl | bash` stdin is this script. Everything that asks reads the
# terminal instead, and the setup is handed it as its stdin.
if [ -t 0 ]; then
    TTY=/dev/stdin
elif [ -r /dev/tty ] && : < /dev/tty 2>/dev/null; then
    TTY=/dev/tty
elif [ $YES = 1 ]; then
    TTY=/dev/null
else
    fail "no terminal to ask questions on; run it from one, or with --yes"
fi

[ "$(id -u)" != 0 ] || fail "run this as yourself, not root: the shell is installed for one user, and asks for sudo only to install packages"

# --- git, before anything else ------------------------------------------------

# scripts/deps.sh has the same, and the rest; this copy exists because git
# is what fetches deps.sh.
family() {
    local word
    # shellcheck disable=SC1091
    for word in $( . /etc/os-release 2>/dev/null; echo "${ID:-} ${ID_LIKE:-}"); do
        case "$word" in
            arch) echo arch; return ;;
            fedora|rhel) echo fedora; return ;;
            debian|ubuntu) echo debian; return ;;
        esac
    done
    echo unknown
}

if ! command -v git >/dev/null 2>&1; then
    say "git is needed to fetch the shell"
    case "$(family)" in
        arch)   sudo pacman -S --needed --noconfirm git ;;
        fedora) sudo dnf install -y git ;;
        debian) sudo apt-get update && sudo apt-get install -y git ;;
        *)      fail "install git, then run this again" ;;
    esac
fi

# --- the source ---------------------------------------------------------------

# Fetched beside where it will live first, then moved: where that is depends
# on the shell's name, which is in the source.
data_home=${XDG_DATA_HOME:-$HOME/.local/share}
mkdir -p "$data_home"
tmp=$(mktemp -d "$data_home/.install.XXXXXX")
trap 'rm -rf "$tmp"' EXIT

say "fetching the $CHANNEL channel from $REPO"
git clone --quiet --depth 1 --branch "$CHANNEL" "$REPO" "$tmp/source" \
    || fail "could not fetch $REPO ($CHANNEL)"

slug=$(sed -n 's/^[[:space:]]*"slug":[[:space:]]*"\([^"]*\)".*/\1/p' "$tmp/source/branding.json" | head -1)
[ -n "$slug" ] || fail "the fetched source has no name in branding.json"
[ -n "$DIR" ] || DIR="$data_home/$slug/source"

if [ -d "$DIR/.git" ]; then
    # An earlier install: brought up to this channel, not replaced, so the
    # source the installed commands point at stays where they point.
    say "updating the source in $DIR"
    # No --depth: on a full clone that would make it shallow.
    git -C "$DIR" fetch --quiet origin "$CHANNEL" || fail "could not fetch into $DIR"
    git -C "$DIR" checkout --quiet -B "$CHANNEL" FETCH_HEAD || fail "could not check out $CHANNEL in $DIR"
elif [ -e "$DIR" ]; then
    fail "$DIR exists and is not a git checkout; move it aside, or choose another place with --dir"
else
    mkdir -p "$(dirname "$DIR")"
    mv "$tmp/source" "$DIR"
    say "source in $DIR"
fi

# --- what the distribution provides ---------------------------------------------

deps_args=()
[ $YES = 1 ] && deps_args+=(--yes)
"$DIR/scripts/deps.sh" install "${deps_args[@]}" < "$TTY" \
    || fail "the shell cannot run without those; nothing else was changed"

# --- the setup ----------------------------------------------------------------

# exec replaces this process, and the EXIT trap with it.
rm -rf "$tmp"
trap - EXIT

if [ $REINSTALL = 1 ]; then
    args=()
    [ $YES = 1 ] && args+=(--yes)
    [ $FRESH = 1 ] && args+=(--fresh)
    say "reinstalling"
    exec "$DIR/scripts/reinstall.sh" "${args[@]}" < "$TTY"
fi

[ $FRESH = 0 ] || fail "--fresh goes with --reinstall"
[ $YES = 1 ] && SETUP_ARGS=(--unattended "${SETUP_ARGS[@]}")
say "starting the setup"
exec "$DIR/scripts/setup.sh" "${SETUP_ARGS[@]}" < "$TTY"

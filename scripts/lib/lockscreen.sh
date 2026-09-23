# shellcheck shell=bash
# Where the lock screen lives, how it goes into a shell package and comes out
# again, and how Plasma's own greeter is asked whether it loads.
#
# Sourced by lockscreen.sh, by renderer.sh (a shell package installed afresh
# keeps the lock screen it had) and by doctor.sh. Requires brand.sh and log.sh.
#
# Plasma 6's greeter, kscreenlocker_greet, draws contents/lockscreen/
# LockScreen.qml from the shell package plasmashell is on, and Plasma's own
# for a package that has none. So ours is a directory inside this project's
# own shell packages and nothing else: no KDE setting is written, and taking it
# out is deleting a directory we put there -- which works from a text console
# with no session, the one place it may have to be done from.

LOCKSCREEN_SRC="$REPO_ROOT/theme/lockscreen"
LOCKSCREEN_STATE="$STATE_DIR/lockscreen"
# The build `try` saw unlocked, and the record of it. `enable` installs this
# copy -- never the working tree, which may have changed since.
LOCKSCREEN_TRIED="$LOCKSCREEN_STATE/tried"
LOCKSCREEN_MARK="$LOCKSCREEN_STATE/tried.json"
LOCKSCREEN_ENABLED="$LOCKSCREEN_STATE/enabled"
# Left inside every copy we install, so that removing one can never remove a
# directory we did not put there.
LOCKSCREEN_MARKER=".installed-by-$SLUG"
LOCKSCREEN_PACKAGES=("$SHELL_PACKAGE_ID" "$PLASMA_SHELL_PACKAGE_ID")
GREETER_VAR="${ENV_PREFIX}_GREETER"
# How long `check` listens after the lock screen says it is ready.
SETTLE_VAR="${ENV_PREFIX}_LOCKSCREEN_SETTLE"

# The greeter binary. A path set in the variable is used or nothing is: a
# test naming a fake must never fall through to the real one.
lockscreen_greeter() {
    if [ -n "${!GREETER_VAR:-}" ]; then
        [ -x "${!GREETER_VAR}" ] && { printf '%s' "${!GREETER_VAR}"; return 0; }
        return 1
    fi
    local c
    for c in /usr/lib/kscreenlocker_greet /usr/libexec/kscreenlocker_greet \
             /usr/lib64/libexec/kscreenlocker_greet /usr/lib/x86_64-linux-gnu/libexec/kscreenlocker_greet; do
        [ -x "$c" ] && { printf '%s' "$c"; return 0; }
    done
    return 1
}

# Which greeter a build was tried with. `kscreenlocker_greet --version` says
# 0.1 whatever the release, so the binary itself is what gets compared.
lockscreen_greeter_id() { sha256sum "$1" | cut -c1-16; }

# For people rather than for comparing: the package's version, where the
# package manager is one we know.
lockscreen_greeter_release() {
    command -v pacman >/dev/null 2>&1 && pacman -Q kscreenlocker 2>/dev/null | cut -d' ' -f2
}

# A digest of a lock screen directory: every file's name and contents, our
# marker left out.
lockscreen_hash() {
    [ -d "$1" ] || return 1
    ( cd "$1" && find . -type f ! -name "$LOCKSCREEN_MARKER" -print0 | LC_ALL=C sort -z | xargs -0 -r sha256sum ) \
        | sha256sum | cut -c1-16
}

lockscreen_installed_dir() { printf '%s/%s/contents/lockscreen' "$PLASMA_SHELLS_DIR" "$1"; }

lockscreen_enabled() { [ -f "$LOCKSCREEN_ENABLED" ]; }

# Puts the tried build into one shell package.
#   0 installed, 1 failed, 2 the package is not installed
# Only over a copy of our own. The old copy goes before the new one arrives,
# so a failure between the two leaves Plasma's lock screen -- the safe side.
lockscreen_install_into() {   # <package id>
    local dest tmp
    dest=$(lockscreen_installed_dir "$1")
    [ -d "$PLASMA_SHELLS_DIR/$1" ] || return 2
    [ -d "$LOCKSCREEN_TRIED" ] || return 1
    if [ -e "$dest" ] && [ ! -f "$dest/$LOCKSCREEN_MARKER" ]; then
        log_error "$dest is not ours; leaving it alone"
        return 1
    fi
    tmp="$dest.new.$$"
    rm -rf "$tmp"
    cp -a "$LOCKSCREEN_TRIED" "$tmp" || { rm -rf "$tmp"; return 1; }
    lockscreen_hash "$LOCKSCREEN_TRIED" > "$tmp/$LOCKSCREEN_MARKER" || { rm -rf "$tmp"; return 1; }
    rm -rf "$dest"
    mv "$tmp" "$dest"
}

# 0 removed, 1 nothing there, 2 there but not ours (left alone).
lockscreen_remove_from() {   # <package id>
    local dest
    dest=$(lockscreen_installed_dir "$1")
    [ -e "$dest" ] || return 1
    [ -f "$dest/$LOCKSCREEN_MARKER" ] || return 2
    rm -rf "$dest"
}

# A throwaway shell package holding one lock screen, for the greeter's
# --shell, which takes a path as well as an id.
lockscreen_package() {   # <dest dir> <lockscreen dir>
    mkdir -p "$1/contents" || return 1
    jq -n --arg id "$SLUG-lockscreen.desktop" \
        '{KPackageStructure: "Plasma/Shell", KPlugin: {Id: $id, Name: $id}, "X-Plasma-APIVersion": "2"}' \
        > "$1/metadata.json" || return 1
    rm -rf "$1/contents/lockscreen"
    cp -a "$2" "$1/contents/lockscreen" || return 1

    # A verbatim copy, deliberately. `try` records the hash of what it showed
    # and `enable` installs only that, so anything rendered or dropped here
    # would make the tried copy differ from the source and refuse every
    # enable. Options.qml -- which names this shell's directories -- is
    # generated into the source instead, by scripts/gen-branding.sh.
}

# The same, arranged for `check`: the lock screen is loaded under a stand-in
# for the greeter's authenticator, and the real one is only looked at.
#
# The stand-in is not a nicety. Authentication started in the greeter and
# ended by the check stopping it is recorded by PAM as a failed login, and
# pam_faillock locks the account after three. Two were recorded against the
# account of the person developing this, on 2026-09-11, by checks that loaded
# the lock screen with the real authenticator while a bug woke its prompt
# with nobody there. So now nothing in a check can reach PAM, and the stand-in
# reports that bug instead of paying for it.
lockscreen_probe_package() {   # <dest dir> <lockscreen dir>
    local dir="$1/contents/lockscreen"
    lockscreen_package "$1" "$2" || return 1
    mv "$dir/LockScreen.qml" "$dir/LockScreenUnderTest.qml" || return 1
    printf 'LockScreenUnderTest 1.0 LockScreenUnderTest.qml\n' >> "$dir/qmldir"
    cat > "$dir/LockScreen.qml" <<'QML'
// Written by `lockscreen check`; never installed. See lockscreen_probe_package.
// qmllint disable unqualified
import QtQuick

Item {
    id: probe
    property bool viewVisible: false

    QtObject {
        id: stand
        property int state: 0
        property bool hadPrompt: false
        property string prompt: ""
        property string promptForSecret: ""
        property string infoMessage: ""
        property string errorMessage: ""
        property int authenticatorTypes: 0
        signal succeeded()
        signal failed(int kind, var source)
        signal noninteractiveError(int kind, var source)
        function startAuthenticating() { console.warn("lock screen: started authenticating with nobody there"); }
        function stopAuthenticating() {}
        function respond(response) { console.warn("lock screen: sent a password with nobody there"); }
        function cancel() {}
    }

    LockScreenUnderTest {
        id: under
        anchors.fill: parent
        viewVisible: probe.viewVisible
        greeterAuthenticator: stand
    }

    Component.onCompleted: {
        const lacks = under.lacks(typeof authenticator !== "undefined" ? authenticator : null);
        if (under.greeterInterface < 2)
            lacks.push("interface version 2");
        if (lacks.length > 0)
            console.warn("lock screen: this greeter lacks", lacks.join(", "));
    }
}
QML
}

# The greeter with no display, no session bus and no runtime directory.
# Nothing it does can reach the desktop, and it still loads the lock screen,
# its wallpaper and every context property -- measured.
# `LOCKSCREEN_PLATFORM` lets a caller ask for the offscreen platform with
# arguments -- `offscreen:configfile=...`, which is how dev/preview/lock.sh
# gets a 1920x1080 screen instead of the 800x800 one Qt invents. It is not a
# way to reach a real display: anything but offscreen is refused, because the
# whole point of this function is that nothing it runs can touch one.
lockscreen_offscreen() {
    local platform=${LOCKSCREEN_PLATFORM:-offscreen}
    case "$platform" in
        offscreen|offscreen:*) ;;
        *) log_warn "ignoring LOCKSCREEN_PLATFORM='$platform': this runs offscreen only"
           platform=offscreen ;;
    esac
    env -u WAYLAND_DISPLAY -u DISPLAY -u DBUS_SESSION_BUS_ADDRESS -u XDG_RUNTIME_DIR \
        QT_QPA_PLATFORM="$platform" QT_FORCE_STDERR_LOGGING=1 "$@"
}

# Loads a lock screen in Plasma's greeter, offscreen, and prints what went
# wrong. 0 when it said it was ready and nothing of its own was complained
# about.
#
# The real greeter rather than qmllint, because qmllint passed a file naming
# a type that is not installed, and the greeter refused it and drew its
# built-in locker. The greeter's testing mode never locks anything, and the
# lock screen gets a stand-in authenticator, so PAM is never reached.
lockscreen_check() {   # <lockscreen dir> [seconds] [style]
    local src=$1 limit=${2:-15} style=${3:-} greeter work pkg log pid i rc settled=0 problems=0 ours lacks
    greeter=$(lockscreen_greeter) || { echo "Plasma's greeter (kscreenlocker_greet) was not found"; return 1; }
    [ -f "$src/LockScreen.qml" ] || { echo "no LockScreen.qml in $src"; return 1; }

    work=$(mktemp -d) || return 1
    pkg="$work/package"
    log="$work/greeter.log"
    lockscreen_probe_package "$pkg" "$src" || { rm -rf "$work"; echo "could not build a package to load"; return 1; }
    # A style named here is drawn instead of the one the person picked: the
    # copy's Options.qml is pointed at a settings file saying so, and theirs
    # is never read or written.
    if [ -n "$style" ]; then
        printf '[Lock]\nstyle=%s\n' "$style" > "$work/lockscreen.conf"
        sed -i "s|location: \"file://[^\"]*\"|location: \"file://$work/lockscreen.conf\"|" \
            "$pkg/contents/lockscreen/Options.qml"
    fi

    lockscreen_offscreen timeout "$limit" "$greeter" --testing --shell "$pkg" > "$log" 2>&1 &
    pid=$!
    # Polled, not piped into grep -m1: a pipeline waits out the whole timeout.
    for ((i = 0; i < limit * 5; i++)); do
        if grep -q -E 'lock screen: (ready|this greeter lacks)|Failed to load lockscreen QML|Lockscreen QML outdated' "$log"; then
            settled=1
            break
        fi
        kill -0 "$pid" 2>/dev/null || break
        sleep 0.2
    done
    # A moment more, for complaints from bindings evaluated after loading --
    # and for the prompt waking by itself, which did, within the first second.
    [ "$settled" = 1 ] && sleep "${!SETTLE_VAR:-2}"
    if kill -0 "$pid" 2>/dev/null; then
        kill "$pid" 2>/dev/null
        wait "$pid" 2>/dev/null
        rc=running
    else
        wait "$pid"
        rc=$?
    fi

    if grep -q 'Failed to load lockscreen QML' "$log"; then
        echo "the greeter could not load it, and drew its own built-in locker instead"
        problems=1
    fi
    if grep -q 'Lockscreen QML outdated' "$log"; then
        echo "the greeter called it outdated, and drew Plasma's instead"
        problems=1
    fi
    ours=$(grep -F "$pkg/" "$log" | sed -e "s#file://$pkg/contents/lockscreen/##g" -e "s#$pkg/contents/lockscreen/##g" \
               | sed -e 's/^[[:space:]]*//' | LC_ALL=C sort -u)
    if [ -n "$ours" ]; then
        echo "what the greeter said about its files:"
        printf '%s\n' "$ours" | sed 's/^/  /'
        problems=1
    fi
    if grep -q -E 'lock screen: (started authenticating|sent a password) with nobody there' "$log"; then
        echo "it woke by itself and started authenticating, with nobody at the keyboard"
        echo "  (at a real lock that is a failed login each time the greeter is stopped)"
        problems=1
    fi
    lacks=$(grep -o 'lock screen: this greeter lacks.*' "$log" | head -1)
    if [ -n "$lacks" ]; then
        printf '%s\n' "${lacks#lock screen: }"
        problems=1
    fi
    if ! grep -q 'lock screen: ready' "$log" && [ "$problems" = 0 ]; then
        echo "it never said it was ready (nothing within ${limit}s)"
        problems=1
    fi
    if [ "$rc" != running ]; then
        echo "the greeter exited by itself, with status $rc"
        problems=1
    fi

    rm -rf "$work"
    return "$problems"
}

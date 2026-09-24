# shellcheck shell=bash
# Which renderers exist here: ours, Plasma, nothing, and every other
# Quickshell configuration on this machine.
#
# The list used to be four names, one of them caelestia, detected by a unit
# name its installer happened to create. Any Quickshell shell is a directory
# with a shell.qml in it, found exactly where quickshell itself looks, so that
# is what is read now: `<xdg config dir>/quickshell/<name>/shell.qml`, in
# XDG_CONFIG_HOME and then each of XDG_CONFIG_DIRS, the first of a name
# winning. A `quickshell/shell.qml` at the top is quickshell's `default` and
# hides the directories beside it, which is quickshell's rule, not ours.
#
# Such a renderer is named `quickshell:<config>`. It draws its own panel, from
# its own code, run under our unit template (`<slug>-renderer@<config>`) so
# switching away can stop it and the next login starts it again.
#
# Requires brand.sh to have been sourced.

RENDERER_FOREIGN_PREFIX="quickshell:"
RENDERER_UNIT_TEMPLATE="$SLUG-renderer@"

# One "name<TAB>directory" per Quickshell configuration that is not this shell.
quickshell_configs() {
    local -a dirs more
    local -A seen=()
    local d root c name ours_real repo_real

    dirs=("${XDG_CONFIG_HOME:-$HOME/.config}")
    IFS=: read -ra more <<< "${XDG_CONFIG_DIRS:-/etc/xdg}"
    dirs+=("${more[@]}")

    # Ours is linked in from a checkout under `make link`, so it is recognised
    # by where it resolves as well as by its name.
    ours_real=$(realpath -q "$QS_CONFIG_DIR" 2>/dev/null)
    repo_real=$(realpath -q "${REPO_ROOT:-/nonexistent}/shell" 2>/dev/null)

    for d in "${dirs[@]}"; do
        [ -n "$d" ] || continue
        root="$d/quickshell"
        [ -d "$root" ] || continue
        if [ -f "$root/shell.qml" ]; then
            [ -n "${seen[default]:-}" ] || { seen[default]=1; printf 'default\t%s\n' "$root"; }
            continue
        fi
        for c in "$root"/*/; do
            c=${c%/}
            [ -f "$c/shell.qml" ] || continue
            name=${c##*/}
            [ "$name" = "$(basename "$QS_CONFIG_DIR")" ] && continue
            case "$(realpath -q "$c" 2>/dev/null)" in
                "$ours_real"|"$repo_real") continue ;;
            esac
            [ -n "${seen[$name]:-}" ] && continue
            seen[$name]=1
            printf '%s\t%s\n' "$name" "$c"
        done
    done
}

# Every renderer id, in the order a list shows them.
renderer_ids() {
    printf '%s\n' quickshell plasma
    quickshell_configs | cut -f1 | sed "s/^/$RENDERER_FOREIGN_PREFIX/"
    printf '%s\n' none
}

# What a profile may still say from before discovery: `caelestia` meant its
# Quickshell configuration.
renderer_normalize() {
    case "$1" in
        caelestia) printf '%scaelestia' "$RENDERER_FOREIGN_PREFIX" ;;
        *)         printf '%s' "$1" ;;
    esac
}

renderer_is_foreign() { [[ "$1" == "$RENDERER_FOREIGN_PREFIX"?* ]]; }

# The shell package plasmashell is on, as plasmashellrc has it: the stock one
# when it names none -- or whatever the caller would rather show for that,
# since a report or a check may want to say it was never set.
live_shell_package() {   # [answer when unset]
    kreadconfig6 --file plasmashellrc --group Shell --key ShellPackage \
        --default "${1-org.kde.plasma.desktop}" 2>/dev/null
}

# The shell package a renderer puts plasmashell on. Nothing for a renderer
# that is not one.
package_for() {
    case "$1" in
        plasma)             printf '%s' "$PLASMA_SHELL_PACKAGE_ID" ;;
        quickshell)         printf '%s' "$SHELL_PACKAGE_ID" ;;
        none)               printf 'org.kde.plasma.desktop' ;;
        # Process-level only: another Quickshell shell draws its own bar from
        # its own code, and none of ours is involved. Ours stays the shell
        # package so the desktop keeps the containment it already has, with no
        # Plasma panel on it.
        "$RENDERER_FOREIGN_PREFIX"*) printf '%s' "$SHELL_PACKAGE_ID" ;;
    esac
}

# The configuration a foreign renderer runs, and where it lives.
renderer_config_name() { printf '%s' "${1#"$RENDERER_FOREIGN_PREFIX"}"; }
renderer_config_dir()  { quickshell_configs | awk -F'\t' -v n="$1" '$1 == n { print $2; exit }'; }

renderer_unit() { printf '%s%s.service' "$RENDERER_UNIT_TEMPLATE" "$(systemd-escape -- "$1")"; }

# Whether an XDG autostart entry starts this configuration on its own, which
# would bring it back at login beside whatever draws then. Prints the file.
renderer_autostart_entry() {
    local name=$1 f dir
    for dir in "${XDG_CONFIG_HOME:-$HOME/.config}/autostart" /etc/xdg/autostart; do
        for f in "$dir"/*.desktop; do
            [ -f "$f" ] || continue
            grep -qiE '^Hidden=true' "$f" && continue
            grep -E '^Exec=' "$f" | grep -qE -- "(-c|--config)[ =]$name( |\$)|/quickshell/$name(/| |\$)" \
                && { printf '%s\n' "$f"; return 0; }
        done
    done
    return 1
}

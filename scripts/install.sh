#!/usr/bin/env bash
# Installs, links or removes the shell, driven entirely by scripts/lib/manifest.sh.
#
#   --link       symlink source dirs into place (development; most edits reload
#                live, a widget's own files need `rmpr reload`)
#   --copy       copy them (frozen install)
#   --uninstall  remove everything the manifest owns
#
# Every mode iterates the same manifest, so the development layout and the
# installed layout cannot drift apart.
set -euo pipefail

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
source "$REPO_ROOT/scripts/lib/log.sh"
source "$REPO_ROOT/scripts/lib/brand.sh"
source "$REPO_ROOT/scripts/lib/render.sh"
source "$REPO_ROOT/scripts/lib/manifest.sh"

MODE=""
FORCE=0
while [ $# -gt 0 ]; do
    case "$1" in
        --link)      MODE=link ;;
        --copy)      MODE=copy ;;
        --uninstall) MODE=uninstall ;;
        --force)     FORCE=1 ;;
        -h|--help)
            sed -n '2,12p' "${BASH_SOURCE[0]}" | sed 's/^# \?//'
            exit 0 ;;
        *) die "unknown argument: $1" ;;
    esac
    shift
done
[ -n "$MODE" ] || die "one of --link, --copy or --uninstall is required"

# A destination is only ever removed if we put it there. Anything else is left
# alone and reported, so a stray real directory at an install path is never
# silently destroyed.
owned_by_us() {
    local dest=$1
    [ -L "$dest" ] && return 0                 # our symlink
    [ -e "$dest/.rmpr-owned" ] && return 0     # our copied dir
    # Rendered templates say so in their first few lines. Without this an
    # install after the first would decline to replace them, and editing a
    # template would silently never take effect.
    [ -f "$dest" ] && head -5 "$dest" 2>/dev/null | grep -q 'GENERATED FILE' && return 0

    # A destination whose own name carries the project slug is ours by
    # construction -- nothing else writes ~/.config/systemd/user/<slug>.service.
    # The marker alone was not enough: files installed before it existed could
    # never be replaced, so the marker could never arrive, and an upgrade would
    # keep skipping them forever.
    case "$(basename "$dest")" in
        "$SLUG"|"$SLUG".*|"$SLUG"-*) return 0 ;;
    esac
    return 1
}

remove_dest() {
    local dest=$1
    [ -e "$dest" ] || [ -L "$dest" ] || return 0
    if owned_by_us "$dest" || [ "$FORCE" = 1 ]; then
        rm -rf "$dest"
        log_debug "removed $dest"
    else
        log_warn "not ours, left in place: $dest"
        log_warn "  (use --force to remove it anyway)"
        return 1
    fi
}

install_dir() {
    local src=$1 dest=$2
    remove_dest "$dest" || return 0
    mkdir -p "$(dirname "$dest")"
    if [ "$MODE" = link ]; then
        ln -s "$src" "$dest"
        log_info "  link  $dest -> $src"
    else
        cp -a "$src" "$dest"
        # Marks the copy as ours so --uninstall can distinguish it from a
        # directory the user created at the same path.
        printf '%s %s\n' "$SLUG" "$VERSION" > "$dest/.rmpr-owned"
        log_info "  copy  $dest"
    fi
}

# A relative symlink, so the alias keeps working if the whole bin directory
# moves.
install_symlink() {
    local target=$1 dest=$2
    remove_dest "$dest" || return 0
    mkdir -p "$(dirname "$dest")"
    ln -s "$target" "$dest"
    log_info "  link  $dest -> $target"
}

install_template() {
    local src=$1 dest=$2
    remove_dest "$dest" || return 0
    render_template "$src" "$dest"
    # Templates default to executable because most of them are scripts; a
    # systemd unit must not be.
    case "$dest" in *.service|*.desktop) chmod 644 "$dest" ;; esac
    log_info "  gen   $dest"
}

# Rendered and copied in every mode, --link too. It is half of what a running
# process was started from -- the session daemon's modules, beside its
# template -- and a link would change it under that process with every edit
# in the checkout, while the template beside it stayed as it was installed:
# the doctor, asking whether the daemon running is the one installed, would
# be comparing against only half. Marked like a copied directory, which is
# what it is.
install_package() {
    local src=$1 dest=$2
    remove_dest "$dest" || return 0
    render_package "$src" "$dest" || return 1
    printf '%s %s\n' "$SLUG" "$VERSION" > "$dest/.rmpr-owned"
    log_info "  gen   $dest"
}

log_step "$MODE ($DISPLAY_NAME $VERSION)"

# The generated singleton must exist before shell/ is linked or copied.
if [ "$MODE" != uninstall ]; then
    "$REPO_ROOT/scripts/gen-branding.sh"     >/dev/null
    "$REPO_ROOT/scripts/gen-qmldir.sh"       >/dev/null
    "$REPO_ROOT/scripts/gen-widget-index.sh" >/dev/null
fi

failed=0
while IFS='|' read -r kind src dest; do
    [ -n "$kind" ] || continue
    case "$MODE" in
        uninstall) remove_dest "$dest" || failed=1 ;;
        *)
            [ "$kind" = symlink ] || [ -e "$REPO_ROOT/$src" ] || die "manifest references missing source: $src"
            case "$kind" in
                dir)      install_dir      "$REPO_ROOT/$src" "$dest" || failed=1 ;;
                template) install_template "$REPO_ROOT/$src" "$dest" || failed=1 ;;
                package)  install_package  "$REPO_ROOT/$src" "$dest" || failed=1 ;;
                symlink)  install_symlink  "$src" "$dest" || failed=1 ;;
                *) die "unknown manifest kind: $kind" ;;
            esac ;;
    esac
done < <(manifest_entries)

# Both of these reach the user's real session whatever $HOME says, so neither
# runs for an install into a throwaway HOME (the update suite makes one) --
# session_available, in brand.sh, is the switch.

# systemd caches unit files; without this the unit is invisible until the next
# login, and `rmpr start` fails with a confusing "unit not found".
if session_available && command -v systemctl >/dev/null 2>&1; then
    systemctl --user daemon-reload 2>/dev/null || true

    # Enabling is a symlink in whichever target [Install] named at the time.
    # When that target changes, an enabled unit keeps the old link until it
    # is re-enabled -- and keeps starting as late as it used to.
    if [ "$MODE" != uninstall ] && systemctl --user is-enabled "$SYSTEMD_UNIT" >/dev/null 2>&1; then
        systemctl --user reenable "$SYSTEMD_UNIT" >/dev/null 2>&1 || true
    fi
fi

# The bus caches its list of activatable names the same way. Without this the
# window daemon is "not activatable" until the next login, which looks exactly
# like the daemon being broken.
if session_available && [ "$MODE" != uninstall ] && command -v busctl >/dev/null 2>&1; then
    busctl --user call org.freedesktop.DBus / org.freedesktop.DBus ReloadConfig 2>/dev/null || true
fi

if [ "$MODE" != uninstall ]; then
    case ":$PATH:" in
        *":$BIN_DIR:"*) : ;;
        *) log_warn "$BIN_DIR is not on PATH; $SESSION_BIN will not be found" ;;
    esac
fi

[ "$failed" = 0 ] || die "$MODE completed with errors"
log_step "$MODE done"

#!/usr/bin/env bash
# Installs and activates the look-and-feel package, reversibly.
#
#   apply    install the package, activate it, write the defaults
#   revert   put every key back and remove the package
#   status   what is active, and what would be undone
#
# Keys are written individually through the ledger rather than with
# `lookandfeeltool --apply`. lookandfeeltool overwrites the colour scheme, icon
# theme and cursor theme in one shot and keeps no record of what was there, so
# there would be nothing to revert to.
set -uo pipefail

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
source "$REPO_ROOT/scripts/lib/log.sh"
source "$REPO_ROOT/scripts/lib/brand.sh"
source "$REPO_ROOT/scripts/lib/render.sh"
source "$REPO_ROOT/scripts/lib/kconfig.sh"
source "$REPO_ROOT/scripts/lib/protected.sh"
source "$REPO_ROOT/scripts/lib/snapshot.sh"

LNF_SRC="$REPO_ROOT/theme/lookandfeel"
LNF_DEST="$PLASMA_LNF_DIR/$LNF_PACKAGE_ID"

install_package() {
    mkdir -p "$LNF_DEST/contents"

    # Failures here must stop the apply. A half-installed package that is then
    # activated gives a desktop with no OSD at all.
    render_template "$LNF_SRC/metadata.json.in" "$LNF_DEST/metadata.json" \
        || { log_error "could not render the package metadata"; return 1; }
    render_template "$LNF_SRC/contents/defaults.in" "$LNF_DEST/contents/defaults" \
        || { log_error "could not render the package defaults"; return 1; }

    cp -a "$LNF_SRC/contents/osd" "$LNF_DEST/contents/" || return 1

    chmod 644 "$LNF_DEST/metadata.json" "$LNF_DEST/contents/defaults"
    log_step "installed $LNF_DEST"
}

# Reads contents/defaults and writes each key through the ledger.
#
# The file's group syntax is [file][Group], and a nested group appears as
# [file][A][B] -- which kwriteconfig6 expresses as repeated --group arguments,
# so it is passed through as "A/B".
apply_defaults() {
    local defaults="$LNF_DEST/contents/defaults"
    [ -f "$defaults" ] || { log_error "no defaults file at $defaults"; return 1; }

    local file="" group="" line key value
    while IFS= read -r line; do
        line=${line%%$'\r'}
        [ -n "$line" ] || continue
        case "$line" in \#*) continue ;; esac

        if [[ "$line" =~ ^\[ ]]; then
            # [file][Group] or [file][A][B]
            local parts
            parts=$(printf '%s' "$line" | sed 's/^\[//; s/\]$//; s/\]\[/\n/g')
            file=$(printf '%s' "$parts" | head -1)
            group=$(printf '%s' "$parts" | tail -n +2 | paste -sd'/' -)
            continue
        fi

        [ -n "$file" ] || continue
        key=${line%%=*}
        value=${line#*=}
        kconfig_set "$file" "$group" "$key" "$value"
    done < "$defaults"
}

cmd=${1:-status}
[ $# -gt 0 ] && shift

case "$cmd" in
    apply)
        # A restore point before the first write outside our own directories.
        snapshot_create "before-theme" >/dev/null || die "could not take a restore point; refusing to apply"

        install_package || die "package installation failed; nothing was activated"
        apply_defaults   || die "could not write the defaults; run '$ALIAS theme revert'"

        # Activating the package is what makes our OSD, splash and logout QML
        # take effect. It is a single key, and it is ledgered like the rest.
        kconfig_set kdeglobals KDE LookAndFeelPackage "$LNF_PACKAGE_ID"

        # KDE caches installed packages; without this the new one is invisible
        # until the next login.
        kbuildsycoca6 --noincremental >/dev/null 2>&1 || true

        log_step "applied"
        log_info "restart plasmashell to see it: systemctl --user restart plasma-plasmashell.service"
        log_info "undo with: $ALIAS theme revert"
        ;;

    revert)
        kconfig_revert_all
        if [ -d "$LNF_DEST" ]; then
            rm -rf "$LNF_DEST"
            log_step "removed $LNF_DEST"
        fi
        kbuildsycoca6 --noincremental >/dev/null 2>&1 || true
        log_step "reverted"
        log_info "restart plasmashell: systemctl --user restart plasma-plasmashell.service"
        ;;

    status)
        printf 'package:      %s\n' "$([ -d "$LNF_DEST" ] && echo "installed ($LNF_DEST)" || echo "not installed")"
        printf 'active L&F:   %s\n' "$(kreadconfig6 --file kdeglobals --group KDE --key LookAndFeelPackage --default '<unset>')"
        printf 'colour:       %s\n' "$(kreadconfig6 --file kdeglobals --group General --key ColorScheme --default '<unset>')"
        printf 'icons:        %s\n' "$(kreadconfig6 --file kdeglobals --group Icons --key Theme --default '<unset>')"
        printf 'widget style: %s\n' "$(kreadconfig6 --file kdeglobals --group KDE --key widgetStyle --default '<unset>')"
        echo
        echo 'ledger (what revert would undo):'
        kconfig_ledger_summary
        ;;

    *) die "unknown command: $cmd (expected apply, revert or status)" ;;
esac

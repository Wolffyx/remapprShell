#!/usr/bin/env bash
# Installs and activates the look-and-feel package, reversibly.
#
#   apply [--appearance]   install the package and activate it
#   revert                 put every key back and remove the package
#   osd ours|plasma        which OSD draws when our package is active
#   status                 what is active, and what would be undone
#
# A plain apply installs the package and activates it -- which is what makes
# our OSD, splash and logout screens take effect -- and touches nothing else.
#
# --appearance additionally writes the colour scheme, icon theme, widget style
# and window decoration from the package's `defaults` file. That is opt-in
# because those are the settings a user is most likely to have deliberately
# chosen: overwriting a dynamic colour scheme with a static one, uninvited, is
# exactly the kind of surprise this project is meant not to spring. It is
# ledgered like everything else, so `revert` puts it all back either way.
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
SWITCHER_SRC="$REPO_ROOT/theme/windowswitcher"
SWITCHER_DEST="$KWIN_SWITCHER_DIR/$SLUG"
DESKTOPTHEME_SRC="$REPO_ROOT/theme/desktoptheme"
DESKTOPTHEME_DEST="$PLASMA_DESKTOPTHEME_DIR/$SLUG"

install_package() {
    mkdir -p "$LNF_DEST/contents"

    # Failures here must stop the apply. A half-installed package that is then
    # activated gives a desktop with no OSD at all.
    render_template "$LNF_SRC/metadata.json.in" "$LNF_DEST/metadata.json" \
        || { log_error "could not render the package metadata"; return 1; }
    render_template "$LNF_SRC/contents/defaults.in" "$LNF_DEST/contents/defaults" \
        || { log_error "could not render the package defaults"; return 1; }

    cp -a "$LNF_SRC/contents/osd" "$LNF_DEST/contents/" || return 1

    # The splash names the project, so it ships as a template like every other
    # file that does.
    render_template "$LNF_SRC/contents/splash/Splash.qml.in" "$LNF_DEST/contents/splash/Splash.qml" \
        || { log_error "could not render the splash"; return 1; }
    chmod 644 "$LNF_DEST/contents/splash/Splash.qml"

    chmod 644 "$LNF_DEST/metadata.json" "$LNF_DEST/contents/defaults"
    log_step "installed $LNF_DEST"

    install_colors || return 1
    install_switcher || return 1
    install_desktoptheme
}

# Plasma's own widgets -- applet popups, the tray, tooltips -- read their
# colours from the desktop theme rather than from the colour scheme. Ours ships
# the scheme's colours and nothing else: every SVG it does not provide falls
# back to Breeze's, so this is a recolour rather than a second set of assets to
# maintain, and it cannot leave a widget with no graphics at all.
install_desktoptheme() {
    local dark="$REPO_ROOT/theme/colors/$SLUG-dark.colors"
    [ -f "$dark" ] || { log_error "no generated colour scheme to build the desktop theme from"; return 1; }

    mkdir -p "$DESKTOPTHEME_DEST"
    render_template "$DESKTOPTHEME_SRC/metadata.json.in" "$DESKTOPTHEME_DEST/metadata.json" \
        || { log_error "could not render the desktop theme metadata"; return 1; }
    chmod 644 "$DESKTOPTHEME_DEST/metadata.json"

    # The same file, so the panel, Plasma's widgets and every dialogue cannot
    # disagree about what the accent colour is.
    cp -a "$dark" "$DESKTOPTHEME_DEST/colors" || return 1
    chmod 644 "$DESKTOPTHEME_DEST/colors"
    log_step "installed $DESKTOPTHEME_DEST"
}

# Alt+Tab's look. Installed by a plain apply and selected only by
# `--appearance`, like the colour schemes: a switcher package that is present
# but not named in kwinrc changes nothing, and appears in System Settings for
# someone who wants to try it without this command deciding for them.
install_switcher() {
    mkdir -p "$SWITCHER_DEST/contents"
    render_template "$SWITCHER_SRC/metadata.json.in" "$SWITCHER_DEST/metadata.json" \
        || { log_error "could not render the window switcher metadata"; return 1; }
    chmod 644 "$SWITCHER_DEST/metadata.json"
    cp -a "$SWITCHER_SRC/contents/ui" "$SWITCHER_DEST/contents/" || return 1
    log_step "installed $SWITCHER_DEST"
}

# The colour schemes are installed by a plain apply, before anything is
# activated. Installing them changes nothing on its own -- a scheme file that
# is not selected has no effect -- but it is what makes ours appear in System
# Settings, so a person can try it without this command choosing for them.
# `--appearance` is what actually selects one.
install_colors() {
    local src="$REPO_ROOT/theme/colors"

    # Generated from the palette, so a checkout that has never been built has
    # none yet.
    [ -n "$(ls -1 "$src"/*.colors 2>/dev/null)" ] || "$REPO_ROOT/scripts/gen-colors.sh" >/dev/null || {
        log_error "could not generate the colour schemes"
        return 1
    }

    mkdir -p "$COLORS_DIR"
    local f
    for f in "$src"/*.colors; do
        [ -f "$f" ] || continue
        cp -a "$f" "$COLORS_DIR/" || { log_error "could not install $(basename "$f")"; return 1; }
        chmod 644 "$COLORS_DIR/$(basename "$f")"
    done
    log_step "installed $(ls -1 "$src"/*.colors | wc -l) colour scheme(s) in $COLORS_DIR"
}

remove_colors() {
    local f removed=0
    for f in "$REPO_ROOT/theme/colors"/*.colors; do
        [ -f "$f" ] || continue
        if [ -f "$COLORS_DIR/$(basename "$f")" ]; then
            rm -f "$COLORS_DIR/$(basename "$f")"
            removed=$((removed + 1))
        fi
    done
    [ "$removed" -gt 0 ] && log_step "removed $removed colour scheme(s) from $COLORS_DIR"
    true
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
        kconfig_set theme "$file" "$group" "$key" "$value"
    done < "$defaults"
}

cmd=${1:-status}
[ $# -gt 0 ] && shift

WITH_APPEARANCE=0
positional=()
while [ $# -gt 0 ]; do
    case "$1" in
        --appearance) WITH_APPEARANCE=1 ;;
        -*) die "unknown option: $1" ;;
        *) positional+=("$1") ;;
    esac
    shift
done
set -- "${positional[@]+"${positional[@]}"}"

# Which OSD draws.
#
# Our Look-and-Feel package supplies the QML plasmashell draws for the OSD, so
# with the package active there is no way to have both ours and Plasma's
# without seeing two. Swapping that one file is the whole mechanism: plasmashell
# still creates the window and still emits the signals our own OSD listens to,
# it simply draws nothing.
osd_mode() {
    local mode=$1
    local dest="$LNF_DEST/contents/osd/Osd.qml"

    [ -d "$LNF_DEST" ] || die "the look-and-feel package is not installed ($ALIAS theme apply)"

    case "$mode" in
        ours)
            cp -a "$LNF_SRC/contents/osd/SilentOsd.qml" "$dest" || die "could not silence Plasma's OSD"
            chmod 644 "$dest"
            set_osd_enabled true
            log_step "Plasma's OSD is silenced; the shell draws its own"
            ;;
        plasma)
            cp -a "$LNF_SRC/contents/osd/Osd.qml" "$dest" || die "could not restore Plasma's OSD"
            chmod 644 "$dest"
            set_osd_enabled false
            log_step "Plasma draws the OSD again"
            ;;
        status)
            if grep -q 'drawn as nothing' "$dest" 2>/dev/null; then
                printf 'osd: ours (Plasma'"'"'s is silenced)\n'
            else
                printf 'osd: Plasma'"'"'s\n'
            fi
            return 0
            ;;
        *) die "unknown OSD mode: $mode (expected ours, plasma or status)" ;;
    esac

    log_info "restart plasmashell to see it: systemctl --user restart plasma-plasmashell.service"
}

# The shell watches its configuration, so this is what makes our OSD appear or
# stop appearing. Written by the same command that swaps the QML: two settings
# that must agree are better set by one thing.
set_osd_enabled() {
    local value=$1
    local profile="$CONFIG_DIR/profiles/$( [ -f "$CONFIG_DIR/state.json" ] && jq -r '.profile // "default"' "$CONFIG_DIR/state.json" 2>/dev/null || echo default )/shell.json"
    mkdir -p "$(dirname "$profile")"

    if [ -f "$profile" ] && ! jq -e . "$profile" >/dev/null 2>&1; then
        log_warn "$profile does not parse; leaving osd.enabled alone"
        return 0
    fi

    local tmp
    tmp=$(mktemp)
    if [ -f "$profile" ]; then
        jq --argjson v "$value" '.osd = ((.osd // {}) + {enabled: $v})' "$profile" > "$tmp" || return 1
    else
        jq -n --argjson v "$value" '{osd: {enabled: $v}}' > "$tmp" || return 1
    fi
    mv "$tmp" "$profile"
}

case "$cmd" in
    apply)
        # A restore point before the first write outside our own directories.
        snapshot_create "before-theme" >/dev/null || die "could not take a restore point; refusing to apply"

        install_package || die "package installation failed; nothing was activated"

        if [ "$WITH_APPEARANCE" = 1 ]; then
            apply_defaults || die "could not write the defaults; run '$ALIAS theme revert'"
        else
            log_info "leaving colour scheme, icons and widget style alone"
            log_info "  (pass --appearance to apply those too)"
        fi

        # Activating the package is what makes our OSD, splash and logout QML
        # take effect. It is a single key, and it is ledgered like the rest.
        kconfig_set theme kdeglobals KDE LookAndFeelPackage "$LNF_PACKAGE_ID"

        # KDE caches installed packages; without this the new one is invisible
        # until the next login.
        kbuildsycoca6 --noincremental >/dev/null 2>&1 || true

        log_step "applied"
        log_info "restart plasmashell to see it: systemctl --user restart plasma-plasmashell.service"
        log_info "undo with: $ALIAS theme revert"
        ;;

    revert)
        kconfig_revert theme
        remove_colors
        for d in "$SWITCHER_DEST" "$DESKTOPTHEME_DEST"; do
            [ -d "$d" ] || continue
            rm -rf "$d"
            log_step "removed $d"
        done
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
        printf 'our schemes:  %s installed\n' "$(ls -1 "$COLORS_DIR" 2>/dev/null | grep -c "^$SLUG-")"
        osd_mode status 2>/dev/null || true
        printf 'switcher:     %s\n' "$([ -d "$SWITCHER_DEST" ] && echo "installed" || echo "not installed")"
        printf 'active Alt+Tab: %s\n' "$(kreadconfig6 --file kwinrc --group TabBox --key LayoutName --default '<unset>')"
        printf 'icons:        %s\n' "$(kreadconfig6 --file kdeglobals --group Icons --key Theme --default '<unset>')"
        printf 'widget style: %s\n' "$(kreadconfig6 --file kdeglobals --group KDE --key widgetStyle --default '<unset>')"
        echo
        echo 'ledger (what revert would undo):'
        kconfig_ledger_summary theme
        ;;

    osd)
        osd_mode "${1:-status}"
        ;;

    *) die "unknown command: $cmd (expected apply, revert, osd or status)" ;;
esac

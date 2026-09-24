# shellcheck shell=bash
# What an apply installs, and where: the two look-and-feel packages, the
# colour schemes, the Plasma desktop theme and the three Alt+Tab switcher
# packages -- and taking them away again.
#
# Sourced by theme.sh, never executed. Requires brand.sh, log.sh, render.sh
# and config.sh -- and defaults.sh, for which parts of the desktop are wanted.

LNF_SRC="$REPO_ROOT/theme/lookandfeel"

# Two packages, light and dark, and LNF_DEST is the light one -- the id this
# project has always used, so a machine that has ours already keeps it. The
# dark one is new beside it. Why two at all: see the note in lib/brand.sh, and
# `lnf_pair_apply` in plasma-switch.sh.
LNF_DEST="$PLASMA_LNF_DIR/$LNF_PACKAGE_ID"
LNF_DARK_DEST="$PLASMA_LNF_DIR/$LNF_DARK_PACKAGE_ID"

lnf_id_for()   { [ "${1:-dark}" = light ] && printf '%s' "$LNF_PACKAGE_ID" || printf '%s' "$LNF_DARK_PACKAGE_ID"; }
lnf_dest_for() { [ "${1:-dark}" = light ] && printf '%s' "$LNF_DEST" || printf '%s' "$LNF_DARK_DEST"; }
SWITCHER_SRC="$REPO_ROOT/theme/windowswitcher"
SWITCHER_DEST="$KWIN_SWITCHER_DIR/$SLUG"
DESKTOPTHEME_SRC="$REPO_ROOT/theme/desktoptheme"
DESKTOPTHEME_DEST="$PLASMA_DESKTOPTHEME_DIR/$SLUG"

# One package, for one variant. Plasma reads a package's `contents/defaults`
# and writes every line in it, so each package must carry its own variant's
# lines and nothing of the other's -- a file with both in it ends with
# whichever comes last, which is how applying ours from the Global Theme page
# always gave light.
#
# The parts the user has turned off (theme.desktop.*) are left out of the
# installed file too, so Plasma's own apply honours them exactly as ours does.
# That is the whole reason the markers are in the source file rather than in
# this script.
install_package_variant() {   # <light|dark>
    local variant=$1
    local dest full line part="" marker="any" wanted=1
    dest=$(lnf_dest_for "$variant")
    mkdir -p "$dest/contents/splash"

    LNF_ID=$(lnf_id_for "$variant")
    LNF_NAME="$DISPLAY_NAME$([ "$variant" = dark ] && printf ' (dark)')"
    LNF_VARIANT="$variant"
    export LNF_ID LNF_NAME LNF_VARIANT

    render_template "$LNF_SRC/metadata.json.in" "$dest/metadata.json" \
        || { log_error "could not render the package metadata"; return 1; }

    full=$(mktemp) || return 1
    render_template "$LNF_SRC/contents/defaults.in" "$full" \
        || { log_error "could not render the package defaults"; rm -f "$full"; return 1; }

    # The same filter apply_defaults uses, applied once, at install time.
    : > "$dest/contents/defaults"
    while IFS= read -r line; do
        case "$line" in
            '# variant: '*) marker=${line#\# variant: } ;;
            '# part: '*)
                part=${line#\# part: }
                marker="any"
                desktop_part_wanted "$part" && wanted=1 || wanted=0
                ;;
        esac
        case "$line" in '#'*|'') printf '%s\n' "$line" >> "$dest/contents/defaults"; continue ;; esac
        [ "$wanted" = 1 ] || continue
        [ "$marker" = any ] || [ "$marker" = "$variant" ] || continue
        printf '%s\n' "$line" >> "$dest/contents/defaults"
    done < "$full"
    rm -f "$full"

    # The scheme itself, inside the package.
    #
    # Naming it in `defaults` is not enough: measured on Plasma 6.7,
    # `plasma-apply-lookandfeel` (and the day/night switch that uses the same
    # code) writes every other line of the defaults and leaves the colour
    # scheme alone unless the package carries a `contents/colors` of its own --
    # which is the first thing KCMLookandFeel looks for. Without this the night
    # switch moved the icons and the decorations to our dark package and left
    # the colours in the other variant, which is a desktop half light and half
    # dark: the exact fault this pair of packages was built to end.
    if [ -f "$REPO_ROOT/theme/colors/$SLUG-$variant.colors" ]; then
        cp -a "$REPO_ROOT/theme/colors/$SLUG-$variant.colors" "$dest/contents/colors" || return 1
        chmod 644 "$dest/contents/colors"
    fi

    cp -a "$LNF_SRC/contents/osd" "$dest/contents/" || return 1

    # The splash names the project, so it ships as a template like every other
    # file that does.
    render_template "$LNF_SRC/contents/splash/Splash.qml.in" "$dest/contents/splash/Splash.qml" \
        || { log_error "could not render the splash"; return 1; }
    chmod 644 "$dest/contents/splash/Splash.qml"

    chmod 644 "$dest/metadata.json" "$dest/contents/defaults"
    log_step "installed $dest"
}

install_package() {   # install_package [variant]
    # Failures here must stop the apply. A half-installed package that is then
    # activated gives a desktop with no OSD at all.
    install_package_variant light || return 1
    install_package_variant dark || return 1

    install_colors || return 1
    install_switcher || return 1
    install_desktoptheme "${1:-dark}"
}

# Plasma's own widgets -- applet popups, the tray, tooltips -- read their
# colours from the desktop theme rather than from the colour scheme. Ours ships
# the scheme's colours and nothing else: every SVG it does not provide falls
# back to Breeze's, so this is a recolour rather than a second set of assets to
# maintain, and it cannot leave a widget with no graphics at all.
install_desktoptheme() {
    local variant=${1:-dark}
    local colors="$REPO_ROOT/theme/colors/$SLUG-$variant.colors"
    [ -f "$colors" ] || { log_error "no generated $variant colour scheme to build the desktop theme from"; return 1; }

    mkdir -p "$DESKTOPTHEME_DEST"
    render_template "$DESKTOPTHEME_SRC/metadata.json.in" "$DESKTOPTHEME_DEST/metadata.json" \
        || { log_error "could not render the desktop theme metadata"; return 1; }
    chmod 644 "$DESKTOPTHEME_DEST/metadata.json"

    # The same file as the colour scheme, so the panel, Plasma's widgets and
    # every dialogue cannot disagree about what the accent colour is -- and the
    # same variant, or a light desktop would keep dark applet popups.
    cp -a "$colors" "$DESKTOPTHEME_DEST/colors" || return 1
    chmod 644 "$DESKTOPTHEME_DEST/colors"
    log_step "installed $DESKTOPTHEME_DEST"
}

# Alt+Tab's look. Installed by a plain apply and selected only by
# `--appearance`, like the colour schemes: a switcher package that is present
# but not named in kwinrc changes nothing, and appears in System Settings for
# someone who wants to try it without this command deciding for them.
# The design draws Alt+Tab three ways -- a row of cards, a wrapping grid, and
# icons alone -- and a layout running inside kwin_wayland cannot read this
# shell's configuration to pick one. So one source installs three packages and
# choosing a layout is choosing a package, which is what KWin's own TabBox
# setting already means: `$ALIAS switcher layout <id>` and the settings page
# both list what is installed.
SWITCHER_LAYOUTS=("row||" "grid|-grid| (grid)" "icons|-icons| (icons)")

switcher_dest() { printf '%s/%s%s' "$KWIN_SWITCHER_DIR" "$SLUG" "$1"; }

install_switcher() {
    local spec layout suffix label dest src ui
    for spec in "${SWITCHER_LAYOUTS[@]}"; do
        IFS='|' read -r layout suffix label <<< "$spec"
        dest=$(switcher_dest "$suffix")

        export SWITCHER_LAYOUT="$layout" SWITCHER_SUFFIX="$suffix" SWITCHER_LABEL="$label"
        mkdir -p "$dest/contents/ui"
        render_template "$SWITCHER_SRC/metadata.json.in" "$dest/metadata.json" \
            || { log_error "could not render the $layout switcher metadata"; return 1; }
        chmod 644 "$dest/metadata.json"

        # Every template in ui/, not main.qml alone: the header and the
        # footer are files of their own beside it, and a package without one
        # of them is a main.qml naming a type that is not there -- which KWin
        # answers by drawing no switcher at all.
        for src in "$SWITCHER_SRC"/contents/ui/*.in; do
            ui="$dest/contents/ui/$(basename "${src%.in}")"
            render_template "$src" "$ui" \
                || { log_error "could not render the $layout switcher"; return 1; }
            chmod 644 "$ui"
        done
        unset SWITCHER_LAYOUT SWITCHER_SUFFIX SWITCHER_LABEL
        log_step "installed $dest"
    done
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

# What revert takes away once every key is back: the switcher packages, the
# desktop theme and both look-and-feel packages.
remove_packages() {
    local spec suffix d
    for spec in "${SWITCHER_LAYOUTS[@]}"; do
        IFS='|' read -r _ suffix _ <<< "$spec"
        d=$(switcher_dest "$suffix")
        [ -d "$d" ] || continue
        rm -rf "$d"
        log_step "removed $d"
    done
    for d in "$DESKTOPTHEME_DEST"; do
        [ -d "$d" ] || continue
        rm -rf "$d"
        log_step "removed $d"
    done
    if [ -d "$LNF_DARK_DEST" ]; then
        rm -rf "$LNF_DARK_DEST"
        log_step "removed $LNF_DARK_DEST"
    fi
    if [ -d "$LNF_DEST" ]; then
        rm -rf "$LNF_DEST"
        log_step "removed $LNF_DEST"
    fi
}

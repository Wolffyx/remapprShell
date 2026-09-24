#!/usr/bin/env bash
# Installs and activates the look-and-feel package, reversibly.
#
#   apply [--appearance|--package-only]
#                          install the package and activate it
#   revert                 put every key back and remove the package
#   variant [light|dark|auto] [--if-following]
#                          which of light and dark the desktop is in
#   osd ours|plasma        which OSD draws when our package is active
#   style [<id>|revert]    the Qt style every application is drawn in
#   install-style <id> [--run]
#                          how to install a style that is missing
#   status [--json]        what is active, and what would be undone
#
# An apply installs the package and activates it -- which is what makes our
# OSD, splash and logout screens take effect -- and then themes the desktop:
# the colour scheme, icon theme, widget style, Plasma theme, window decorations
# and the Alt+Tab switcher, from the package's `defaults` file.
#
# Which of those it touches is the user's, under `theme.desktop`: the whole
# thing has a switch and so does every part, the settings window offers them as
# checkboxes, and a part that is off keeps whatever System Settings says. They
# default to on, so choosing this shell's theme themes the desktop to match it
# rather than leaving the two disagreeing.
#
# --package-only ignores all of that and installs the package alone.
# --appearance is the older spelling of "yes, the desktop too", kept because
# scripts and documentation use it.
#
# Every key is ledgered, so `revert` puts all of it back whatever was applied.
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
source "$REPO_ROOT/scripts/lib/config.sh"
source "$REPO_ROOT/scripts/lib/protected.sh"
source "$REPO_ROOT/scripts/lib/snapshot.sh"
source "$REPO_ROOT/scripts/lib/kwin.sh"

LNF_SRC="$REPO_ROOT/theme/lookandfeel"

# Two packages, light and dark, and LNF_DEST is the light one -- the id this
# project has always used, so a machine that has ours already keeps it. The
# dark one is new beside it. Why two at all: see the note in lib/brand.sh, and
# `lnf_pair_apply` below.
LNF_DEST="$PLASMA_LNF_DIR/$LNF_PACKAGE_ID"
LNF_DARK_DEST="$PLASMA_LNF_DIR/$LNF_DARK_PACKAGE_ID"

lnf_id_for()   { [ "${1:-dark}" = light ] && printf '%s' "$LNF_PACKAGE_ID" || printf '%s' "$LNF_DARK_PACKAGE_ID"; }
lnf_dest_for() { [ "${1:-dark}" = light ] && printf '%s' "$LNF_DEST" || printf '%s' "$LNF_DARK_DEST"; }
SWITCHER_SRC="$REPO_ROOT/theme/windowswitcher"
SWITCHER_DEST="$KWIN_SWITCHER_DIR/$SLUG"
DESKTOPTHEME_SRC="$REPO_ROOT/theme/desktoptheme"
DESKTOPTHEME_DEST="$PLASMA_DESKTOPTHEME_DIR/$SLUG"

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

# What System Settings' colours page sends. Qt applications reread kdeglobals
# on it, which is what makes a colour scheme written here reach a window that
# is already open rather than only the next one started.
notify_palette_changed() {
    session_available || return 0
    busctl --user emit /KGlobalSettings org.kde.KGlobalSettings notifyChange ii 0 0 >/dev/null 2>&1 || true
}

# How to install a package here, printed for a person to run. Only pacman is
# known; elsewhere the package names are not known either.
install_command() {
    command -v pacman >/dev/null 2>&1 || return 1
    printf 'sudo pacman -S --needed %s' "$1"
}

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

# Names our two packages as the light and dark halves Plasma's own day/night
# switch moves between. Ledgered, so `theme revert` gives back whatever was
# there -- usually nothing, which is what makes Plasma fall back to Breeze.
lnf_pair_apply() {
    kconfig_set theme kdeglobals KDE DefaultLightLookAndFeel "$LNF_PACKAGE_ID"
    kconfig_set theme kdeglobals KDE DefaultDarkLookAndFeel "$LNF_DARK_PACKAGE_ID"
}

# Whether Plasma is the one switching light and dark, and whether it has been
# told to switch between ours. "ours", "breeze" or "off".
lnf_pair_state() {
    local auto light dark
    auto=$(kreadconfig6 --file kdeglobals --group KDE --key AutomaticLookAndFeel --default false)
    [ "$auto" = true ] || { printf 'off'; return 0; }
    light=$(kreadconfig6 --file kdeglobals --group KDE --key DefaultLightLookAndFeel --default '')
    dark=$(kreadconfig6 --file kdeglobals --group KDE --key DefaultDarkLookAndFeel --default '')
    if [ "$light" = "$LNF_PACKAGE_ID" ] && [ "$dark" = "$LNF_DARK_PACKAGE_ID" ]; then
        printf 'ours'
    else
        printf 'breeze'
    fi
}

# Plasma's day/night switch is a kded module with a timer, and a timer can
# miss. On the evening of 2026-09-22 it did: kded6 had been running since
# 09:56, a Frameworks upgrade at 10:56 replaced 130 of the libraries mapped
# into it, and sunset at 19:42 came and went with nothing written. The shell
# had turned dark at 19:13 and every application stayed light until somebody
# reloaded the module by hand.
#
# Handing the schedule to Plasma is still right -- one writer, no two clocks
# disagreeing by seconds and waking every Qt application twice for one sunset.
# What was wrong was never looking. So this looks, waits for Plasma to do its
# own job, and only writes when it is clear that nobody else will.
#
# What it writes goes through the ledger like everything else, `LookAndFeelPackage`
# included -- which is also what stops the next start from rescuing all over
# again, since that key is what Plasma's own switch compares against.
plasma_rescue() {   # plasma_rescue variant
    local variant=${1:-dark} want deadline

    if [ "$(config_get '.theme.desktop.rescuePlasmaSwitch' true)" != "true" ]; then
        log_info "Plasma's switch has not put the desktop in $variant, and rescuing it is off"
        return 0
    fi

    want=$(lnf_id_for "$variant")

    # This runs a second after the mode changed, which is the same second
    # Plasma's own switch is working in. Writing now would be a race with a
    # write that was already coming, so wait for it before concluding there
    # is none.
    deadline=$(( SECONDS + 20 ))
    while [ "$SECONDS" -lt "$deadline" ]; do
        [ "$(kreadconfig6 --file kdeglobals --group KDE --key LookAndFeelPackage --default '')" = "$want" ] \
            && { log_info "Plasma switched the desktop to $variant"; return 0; }
        sleep 1
    done

    log_warn "Plasma's own day and night switch did not fire; putting the desktop in $variant ourselves"
    apply_defaults "$variant" 1 || { log_error "could not write the $variant variant"; return 1; }
    desktop_part_wanted colours && colors_apply_scheme "$variant"
    kconfig_set theme kdeglobals KDE LookAndFeelPackage "$want"
}

# The other half of the same fault: Plasma switched, and its colours did not
# follow.
#
# `plasma_rescue` above is for Plasma not switching at all. This one is for
# Plasma switching and leaving the desktop half done -- `LookAndFeelPackage`
# and `ColorScheme` in this variant, the `[Colors:*]` groups still in the
# other. Found on the morning of 2026-09-23, on a machine started an hour after
# sunrise: every name in kdeglobals said light, every window was dark, and
# `theme variant` read the names, agreed with them and wrote nothing. Three
# separate checks -- this command's, the shell's and doctor's -- all called
# that desktop light, because all three asked the name.
#
# Which is the whole reason the colours are copied into kdeglobals at all: the
# name is a label, and `[Colors:*]` is what every Qt application reads.
#
# It costs one read when all is well. That is the price of never again calling
# a dark desktop light.
plasma_fill_colours() {   # plasma_fill_colours <light|dark>
    local variant=$1
    desktop_part_wanted colours || return 0
    # With kde-material-you-colors following, the colours on the desktop are
    # deliberately theirs and disagreeing with ours is the point.
    if material_you_wanted; then return 0; fi
    if colours_match "$variant"; then return 0; fi

    log_warn "Plasma put the $variant global theme on, but kdeglobals still holds the other variant's colours"
    colors_apply_scheme "$variant" || return 1

    # The name beside them, when it is the other variant's. Copying a scheme's
    # colours in under another scheme's name is the same fault upside down --
    # and it is one this function caused on 2026-09-23 before it did this.
    [ "$(kreadconfig6 --file kdeglobals --group General --key ColorScheme --default '')" \
        = "$SLUG-$variant" ] \
        || kconfig_set theme kdeglobals General ColorScheme "$SLUG-$variant"
}

# `night_light_daylight`, `night_light_wait` and the rest of KWin's Night
# Light live in kwin.sh: doctor asks the same question, and one copy of it is
# one answer.

# Whether the colour scheme on the desktop right now is a dark one, by the
# luminance of the window background -- the same question `Scheme.resolveMode`
# asks of `PlasmaColors.background`.
scheme_darkness() {
    local bg r g b
    bg=$(kreadconfig6 --file kdeglobals --group "Colors:Window" --key BackgroundNormal --default '')
    IFS=, read -r r g b <<< "$bg"
    [ -n "$b" ] || { printf 'dark'; return 0; }
    if [ $(( (r * 299 + g * 587 + b * 114) / 1000 )) -lt 128 ]; then
        printf 'dark'
    else
        printf 'light'
    fi
}

# Whether the colours in kdeglobals are the ones this variant's scheme carries.
#
# Naming a scheme and wearing it are two separate writes -- see
# `colors_apply_scheme` -- and on the morning of 2026-09-23 the desktop had the
# first without the second: `LookAndFeelPackage` and `ColorScheme` both said
# light, every `[Colors:*]` group still held the dark scheme's values, and every
# Qt application drew dark. The window background is enough to tell the two
# apart; it is the one colour the variants can never share.
#
# No scheme installed to compare against is not a disagreement, so it answers
# yes: a missing file is `colors_apply_scheme`'s warning to give, not this.
colours_match() {   # colours_match <light|dark>
    local want have
    want=$(sed -n '/^\[Colors:Window\]/,/^\[/ s/^BackgroundNormal=//p' \
               "$COLORS_DIR/$SLUG-$1.colors" 2>/dev/null | head -1 | tr -d ' ')
    [ -n "$want" ] || return 0
    have=$(kreadconfig6 --file kdeglobals --group "Colors:Window" --key BackgroundNormal --default '' | tr -d ' ')
    [ "$have" = "$want" ]
}

# Light or dark, for the desktop. The shell answers this for itself in
# Scheme.resolveMode; this is the same question for the applications.
#
# `theme.mode` is the user's, and light and dark are answers in themselves.
# `auto` follows Night Light. With nothing to follow it answers whatever the
# desktop is already wearing -- which the caller's own "already in x" check
# then turns into doing nothing at all.
#
# It used to answer dark there, which is what the defaults file said before
# there was a light variant of it at all. That is the one guess that cannot be
# taken back: a dark written to the desktop is read back as the desktop's own
# darkness, and auto has latched on its own answer.
resolve_variant() {
    local mode
    mode=$(config_get '.theme.mode' 'auto')
    case "$mode" in
        light|dark) printf '%s' "$mode"; return 0 ;;
    esac
    case "$(night_light_wait)" in
        true)  printf 'light' ;;
        false) printf 'dark' ;;
        *)     scheme_darkness ;;
    esac
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
    local spec layout suffix label dest
    for spec in "${SWITCHER_LAYOUTS[@]}"; do
        IFS='|' read -r layout suffix label <<< "$spec"
        dest=$(switcher_dest "$suffix")

        export SWITCHER_LAYOUT="$layout" SWITCHER_SUFFIX="$suffix" SWITCHER_LABEL="$label"
        mkdir -p "$dest/contents/ui"
        render_template "$SWITCHER_SRC/metadata.json.in" "$dest/metadata.json" \
            || { log_error "could not render the $layout switcher metadata"; return 1; }
        render_template "$SWITCHER_SRC/contents/ui/main.qml.in" "$dest/contents/ui/main.qml" \
            || { log_error "could not render the $layout switcher"; return 1; }
        chmod 644 "$dest/metadata.json" "$dest/contents/ui/main.qml"
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

# Reads contents/defaults and writes each key through the ledger.
#
# The file's group syntax is [file][Group], and a nested group appears as
# [file][A][B] -- which kwriteconfig6 expresses as repeated --group arguments,
# so it is passed through as "A/B".
# Is this part of the desktop ours to theme? `theme.desktop.enabled` is the
# whole question and each part is a second one, so turning the lot off is one
# setting and leaving out just the colour scheme is another. Anything left out
# keeps whatever the user chose in System Settings.
desktop_part_wanted() {
    local part=$1
    [ "$(config_get ".theme.desktop.enabled" true)" = "true" ] || return 1
    [ "$(config_get ".theme.desktop.$part" true)" = "true" ]
}

# Which parts would be written, and which are left alone -- for `status` and
# for saying out loud what an apply did.
desktop_parts() { printf '%s\n' colours icons style plasmaTheme decorations switcher gtk; }

# ---- the colours themselves, not just the scheme's name -------------------
#
# Naming a scheme in `kdeglobals [General] ColorScheme` is half of what
# selecting one means. The other half is copying the scheme's `[Colors:*]` and
# `[WM]` groups into kdeglobals, which is where every Qt and KDE application
# reads its colours -- and where the desktop portal reads the answer it gives
# Chrome and every Electron application. Without it the name said light while
# every window stayed the colour the last scheme left behind.
#
# See scripts/lib/kdeglobals-colors.py for why this one is saved whole rather
# than ledgered key by key.
COLORS_HELPER="$REPO_ROOT/scripts/lib/kdeglobals-colors.py"

colors_backup() { printf '%s/kdeglobals-colors.json' "$STATE_DIR"; }

colors_apply_scheme() {   # <light|dark>
    local variant=$1
    local scheme="$COLORS_DIR/$SLUG-$variant.colors"
    local kdeglobals="$XDG_CONFIG_HOME/kdeglobals"
    local backup
    backup=$(colors_backup)

    [ -f "$scheme" ] || { log_warn "no $variant colour scheme installed; colours not copied"; return 0; }

    mkdir -p "$(dirname "$backup")" "$(dirname "$kdeglobals")"
    touch "$kdeglobals"
    if [ -f "$backup" ]; then
        # A backup written before a group joined the governed set knows nothing
        # of it, and a revert would take it away without putting anything back.
        python3 "$COLORS_HELPER" save-widened "$kdeglobals" "$backup" \
            || log_warn "could not widen the saved colours; a revert may leave a group out"
    else
        python3 "$COLORS_HELPER" save "$kdeglobals" "$backup" \
            || { log_error "could not save the colours that were there"; return 1; }
    fi

    python3 "$COLORS_HELPER" apply "$scheme" "$kdeglobals" \
        || { log_error "could not copy the $variant colours into kdeglobals"; return 1; }
    log_step "copied the $variant colours into kdeglobals"

    # And say so. Writing the file by hand is silent, and a silent write is one
    # nobody acts on: on 2026-09-23 a window's contents followed the new
    # colours and its titlebar stayed the old ones, because KWin's decoration
    # palette is a KConfigWatcher and no ConfigChanged ever reached it. The
    # portal that answers Chrome and every Electron application is another.
    notify_colours_changed "$scheme"
}

# The signal KConfig sends when it writes kdeglobals itself. `notify_palette_changed`
# below is the other, older one, which reaches an application's contents but
# not its decoration; both are sent, because KDE's own apply sends both.
notify_colours_changed() {   # notify_colours_changed <scheme.colors>
    session_available || return 0
    python3 "$COLORS_HELPER" notify "$1" >/dev/null 2>&1 \
        || log_warn "could not announce the colours; applications will catch up when next started"
}

colors_revert_scheme() {
    local backup kdeglobals
    backup=$(colors_backup)
    kdeglobals="$XDG_CONFIG_HOME/kdeglobals"
    [ -f "$backup" ] || return 0
    if [ -f "$kdeglobals" ]; then
        python3 "$COLORS_HELPER" restore "$backup" "$kdeglobals" \
            || log_warn "could not put the previous colours back"
        log_step "put the previous colours back in kdeglobals"
    fi
    rm -f "$backup"
}

# ---- GTK, which is not KDE's configuration at all -------------------------
#
# Every application that follows "the system" asks a portal, and on this
# desktop two portals answer: ours, and xdg-desktop-portal-gtk. The GTK one
# reads `org.gnome.desktop.interface color-scheme` out of dconf, so a light
# KDE colour scheme leaves Chrome, every Electron application and every GTK
# application dark -- which is what "dark mode is active globally" was, with
# our own light scheme selected and reading correctly everywhere else.
#
# So the variant writes that preference too, and the `gtk-application-prefer-
# dark-theme` key in the GTK ini files beside it, which older GTK reads. The
# ini files are INI, so kwriteconfig6 and the ledger handle them like any other
# key; dconf is not, so the value it had is kept in a file of our own.
GTK_INIS=("gtk-3.0/settings.ini" "gtk-4.0/settings.ini")
GSETTINGS_SCHEMA="org.gnome.desktop.interface"

gtk_ledger() { printf '%s/gtk-color-scheme.json' "$STATE_DIR"; }

# The dconf preference, remembered the first time we change it so revert can
# put it back. dconf is nobody's INI file, so this is a note of our own rather
# than a ledger entry.
gtk_remember_scheme() {
    local led before file created=()
    led=$(gtk_ledger)
    [ -f "$led" ] && return 0

    # Which ini files we are about to create. The ledger puts keys back but
    # cannot remove a file that did not exist, and `theme revert` has to leave
    # the configuration byte-identical -- two empty ini files is not that.
    for file in "${GTK_INIS[@]}"; do
        [ -f "$XDG_CONFIG_HOME/$file" ] || created+=("$file")
    done

    before=""
    command -v gsettings >/dev/null 2>&1 \
        && before=$(gsettings get "$GSETTINGS_SCHEMA" color-scheme 2>/dev/null | tr -d "'")

    mkdir -p "$(dirname "$led")"
    jq -n --arg v "$before" \
          --argjson created "$(printf '%s\n' "${created[@]+"${created[@]}"}" | jq -R -s -c 'split("\n") | map(select(length > 0))')" \
          '{colorScheme: $v, created: $created}' > "$led"
    log_debug "gtk: color-scheme was ${before:-<unset>}"
}

# The theme a variant should wear, when the settings name one. Empty means
# leave the theme name alone, which is the default and was the only behaviour
# until 2026-09-16.
#
# Asking for the preference is not the same as asking for a theme. A GTK theme
# whose name *is* the dark one -- Nordic, adw-gtk3-dark -- ignores
# `color-scheme` and `gtk-application-prefer-dark-theme` entirely and stays
# dark in every mode, which is what "dark mode is still active" was here with
# both preferences reading light and correct. Themes ship in pairs and the
# pair's two names are the only thing that separates them, so following the
# mode means writing the name.
#
# Not guessed. A counterpart derived by adding or removing "-dark" is right for
# adw-gtk3 and wrong for Nordic, whose light half is Nordic-Polar, and a wrong
# guess puts the user in a theme they never chose. Both names are named.
gtk_theme_for() {   # <light|dark>
    config_get ".theme.desktop.gtkTheme${1^}" ""
}

# The theme name gsettings had, kept beside the colour-scheme note. Separate
# from gtk_remember_scheme because that one returns early once the ledger
# exists, and this key was added to it later: a desktop themed before today
# has the file without the field.
gtk_remember_theme() {
    local led before tmp
    led=$(gtk_ledger)
    [ -f "$led" ] || return 0
    jq -e 'has("theme")' "$led" >/dev/null 2>&1 && return 0

    before=""
    command -v gsettings >/dev/null 2>&1 \
        && before=$(gsettings get "$GSETTINGS_SCHEMA" gtk-theme 2>/dev/null | tr -d "'")

    tmp=$(mktemp)
    jq --arg v "$before" '. + {theme: $v}' "$led" > "$tmp" && mv "$tmp" "$led" || rm -f "$tmp"
    log_debug "gtk: gtk-theme was ${before:-<unset>}"
}

gtk_apply_variant() {   # <light|dark>
    local variant=$1
    local want file theme
    [ "$variant" = "light" ] && want="prefer-light" || want="prefer-dark"

    gtk_remember_scheme
    gtk_remember_theme
    if command -v gsettings >/dev/null 2>&1; then
        gsettings set "$GSETTINGS_SCHEMA" color-scheme "$want" 2>/dev/null \
            || log_warn "could not set GTK's colour scheme preference"
    fi

    # The ini key GTK reads without a portal. `true`/`false`, not the
    # portal's spelling.
    for file in "${GTK_INIS[@]}"; do
        kconfig_set theme "$file" Settings gtk-application-prefer-dark-theme \
            "$([ "$variant" = "light" ] && printf 'false' || printf 'true')"
    done
    log_step "GTK applications asked to prefer $variant"

    theme=$(gtk_theme_for "$variant")
    [ -n "$theme" ] || return 0

    if command -v gsettings >/dev/null 2>&1; then
        gsettings set "$GSETTINGS_SCHEMA" gtk-theme "$theme" 2>/dev/null \
            || log_warn "could not set the GTK theme to $theme"
    fi
    for file in "${GTK_INIS[@]}"; do
        kconfig_set theme "$file" Settings gtk-theme-name "$theme"
    done
    log_step "GTK theme: $theme"
}

gtk_revert() {
    local led before file path
    led=$(gtk_ledger)
    [ -f "$led" ] || return 0

    before=$(jq -r '.colorScheme // ""' "$led" 2>/dev/null)
    if [ -n "$before" ] && command -v gsettings >/dev/null 2>&1; then
        gsettings set "$GSETTINGS_SCHEMA" color-scheme "$before" 2>/dev/null || true
        log_step "GTK's colour scheme preference back to $before"
    fi

    before=$(jq -r '.theme // ""' "$led" 2>/dev/null)
    if [ -n "$before" ] && command -v gsettings >/dev/null 2>&1; then
        gsettings set "$GSETTINGS_SCHEMA" gtk-theme "$before" 2>/dev/null || true
        log_step "GTK theme back to $before"
    fi

    # An ini file we created, with nothing left in it once the ledger has put
    # its keys back, goes away again. One that was the user's stays whatever it
    # now holds.
    while IFS= read -r file; do
        [ -n "$file" ] || continue
        path="$XDG_CONFIG_HOME/$file"
        [ -f "$path" ] || continue
        if ! grep -qE '^[^][:space:]#]+=' "$path"; then
            rm -f "$path"
            rmdir "$(dirname "$path")" 2>/dev/null || true
            log_step "removed $path (ours, and now empty)"
        fi
    done < <(jq -r '.created[]? // empty' "$led" 2>/dev/null)

    rm -f "$led"
}

# ---- kde-material-you-colors, which is not ours either --------------------
#
# A third-party service that derives a Material You colour scheme from the
# wallpaper (or a fixed seed) and applies it to the Plasma session. It has one
# `light` switch in its own config and applies MaterialYouLight or
# MaterialYouDark accordingly -- once at login, and again whenever the
# wallpaper changes.
#
# Left alone it is the last writer at every login, so `theme.mode: auto` reads
# its answer rather than the other way round: measured here on 2026-09-16,
# `light = False` applied MaterialYouDark at 09:31:16 and the whole desktop was
# dark by day with every one of this project's own settings reading light and
# correct.
#
# So following it means writing that one key and restarting the unit. Off by
# default and for the usual reason: it is somebody else's service, installed by
# somebody else's dotfiles, and a shell that quietly rewrote a config it does
# not own would be exactly the behaviour this project refuses elsewhere.
MATERIAL_YOU_CONF="kde-material-you-colors/config.conf"
MATERIAL_YOU_UNIT="kde-material-you-colors.service"

material_you_wanted() {
    [ "$(config_get '.theme.desktop.enabled' true)" = "true" ] || return 1
    [ "$(config_get '.theme.desktop.materialYou' false)" = "true" ] || return 1
    [ -f "$XDG_CONFIG_HOME/$MATERIAL_YOU_CONF" ]
}

# Every GTK theme installed where GTK looks, by name: a directory with a
# gtk-3.0 or gtk-4.0 in it. What the settings window offers for the two
# gtkTheme keys, so a name there is one GTK will find.
gtk_themes() {
    local d t
    for d in "$HOME/.themes" "${XDG_DATA_HOME:-$HOME/.local/share}/themes" /usr/local/share/themes /usr/share/themes; do
        for t in "$d"/*/; do
            [ -d "${t}gtk-3.0" ] || [ -d "${t}gtk-4.0" ] || continue
            t=${t%/}; printf '%s\n' "${t##*/}"
        done
    done | sort -u
}

material_you_apply_variant() {   # <light|dark>
    local variant=$1 want have

    want=$([ "$variant" = "light" ] && printf 'True' || printf 'False')
    have=$(kreadconfig6 --file "$XDG_CONFIG_HOME/$MATERIAL_YOU_CONF" \
                        --group CUSTOM --key light --default '' 2>/dev/null)

    # Its config is read by Python's configparser, which does not care that
    # kwriteconfig6 drops the spaces around the "=" the file was written with.
    # Nothing is restarted when nothing changed: a restart re-applies the
    # scheme, which wakes every Qt application on the machine.
    [ "$have" = "$want" ] && return 0

    kconfig_set theme "$MATERIAL_YOU_CONF" CUSTOM light "$want"
    log_step "kde-material-you-colors: light = $want"

    session_available || return 0
    systemctl --user cat "$MATERIAL_YOU_UNIT" >/dev/null 2>&1 || return 0
    systemctl --user restart "$MATERIAL_YOU_UNIT" >/dev/null 2>&1 \
        && log_step "restarted $MATERIAL_YOU_UNIT so it re-applies" \
        || log_warn "could not restart $MATERIAL_YOU_UNIT; its scheme follows at the next login"
}

# apply_defaults [variant] [variant-only]
#
# `variant` is light or dark: the lines under the other one's `# variant:`
# marker are not written at all. `variant-only` writes nothing else, which is
# what `variant` uses to follow day and night without rewriting the whole
# desktop -- the style, the Plasma theme, the decorations and Alt+Tab do not
# change between light and dark, and rewriting them would churn the ledger.
apply_defaults() {
    local want=${1:-dark} variant_only=${2:-0}
    local defaults
    defaults="$(lnf_dest_for "$want")/contents/defaults"
    [ -f "$defaults" ] || { log_error "no defaults file at $defaults"; return 1; }

    local file="" group="" line key value part="" wanted=1 variant="any"
    while IFS= read -r line; do
        line=${line%%$'\r'}
        [ -n "$line" ] || continue

        # `# part: <id>` governs the lines beneath it, up to the next marker.
        case "$line" in
            '#'*)
                case "$line" in
                    '# variant: '*)
                        variant=${line#\# variant: }
                        ;;
                    '# part: '*)
                        part=${line#\# part: }
                        variant="any"
                        if desktop_part_wanted "$part"; then
                            wanted=1
                        else
                            wanted=0
                            log_info "leaving $part alone (theme.desktop.$part is off)"
                        fi
                        ;;
                esac
                continue
                ;;
        esac

        [ "$wanted" = 1 ] || continue

        # The variant being applied, and -- for a variant-only pass -- nothing
        # that belongs to neither. The group headers are skipped with the keys
        # beneath them, because each variant's block carries its own.
        if [ "$variant" = "any" ]; then
            [ "$variant_only" = 0 ] || continue
        else
            [ "$variant" = "$want" ] || continue
        fi

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
PACKAGE_ONLY=0
WITH_JSON=0
RUN_INSTALL=0
VARIANT_ARG=""
IF_FOLLOWING=0
positional=()
while [ $# -gt 0 ]; do
    case "$1" in
        --appearance) WITH_APPEARANCE=1 ;;
        --package-only) PACKAGE_ONLY=1 ;;
        --json) WITH_JSON=1 ;;
        --run) RUN_INSTALL=1 ;;
        --variant) VARIANT_ARG=${2:-}; shift ;;
        --if-following) IF_FOLLOWING=1 ;;
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
    local pkg

    [ -d "$LNF_DEST" ] || die "the look-and-feel package is not installed ($ALIAS theme apply)"

    # Both packages: which of the two is active changes at sunset, and an OSD
    # silenced in one of them would come back with the other.
    case "$mode" in
        ours)
            for pkg in "$LNF_DEST" "$LNF_DARK_DEST"; do
                [ -d "$pkg" ] || continue
                cp -a "$LNF_SRC/contents/osd/SilentOsd.qml" "$pkg/contents/osd/Osd.qml" \
                    || die "could not silence Plasma's OSD"
                chmod 644 "$pkg/contents/osd/Osd.qml"
            done
            set_osd_enabled true
            log_step "Plasma's OSD is silenced; the shell draws its own"
            ;;
        plasma)
            for pkg in "$LNF_DEST" "$LNF_DARK_DEST"; do
                [ -d "$pkg" ] || continue
                cp -a "$LNF_SRC/contents/osd/Osd.qml" "$pkg/contents/osd/Osd.qml" \
                    || die "could not restore Plasma's OSD"
                chmod 644 "$pkg/contents/osd/Osd.qml"
            done
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

        # Light or dark, for the applications. `--variant` overrides; without
        # it the desktop is put in whatever the shell is in.
        case "$VARIANT_ARG" in
            ""|auto) variant=$(resolve_variant) ;;
            light|dark) variant=$VARIANT_ARG ;;
            *) die "unknown variant: $VARIANT_ARG (one of: light dark auto)" ;;
        esac

        # Installing copies Plasma's Osd.qml over the silenced one, so a
        # second apply -- to add parts written since the first -- would
        # quietly bring back Plasma's OSD beside ours. The choice is kept.
        osd_was_ours=0
        grep -q 'drawn as nothing' "$LNF_DEST/contents/osd/Osd.qml" 2>/dev/null && osd_was_ours=1

        install_package "$variant" || die "package installation failed; nothing was activated"

        if [ "$osd_was_ours" = 1 ]; then
            cp -a "$LNF_SRC/contents/osd/SilentOsd.qml" "$LNF_DEST/contents/osd/Osd.qml" \
                || die "could not keep Plasma's OSD silenced"
            chmod 644 "$LNF_DEST/contents/osd/Osd.qml"
        fi

        # The desktop is themed unless it is turned off. `theme.desktop` says
        # which parts, and `--package-only` overrides the lot for the case
        # where somebody wants the package installed and nothing else touched.
        if [ "$PACKAGE_ONLY" = 1 ]; then
            log_info "package only: colour scheme, icons, widget style and the rest left alone"
        elif [ "$WITH_APPEARANCE" = 1 ] || [ "$(config_get '.theme.desktop.enabled' true)" = "true" ]; then
            apply_defaults "$variant" || die "could not write the defaults; run '$ALIAS theme revert'"
            desktop_part_wanted colours && colors_apply_scheme "$variant"
            desktop_part_wanted gtk && gtk_apply_variant "$variant"
            material_you_wanted && material_you_apply_variant "$variant"
            log_info "the desktop is in $variant (theme.mode: $(config_get '.theme.mode' 'auto'))"
        else
            log_info "leaving the desktop alone (theme.desktop.enabled is off)"
            log_info "  the shell is themed either way; --appearance applies the rest once"
        fi

        # Activating the package is what makes our OSD, splash and logout QML
        # take effect -- the one that matches the variant in force.
        kconfig_set theme kdeglobals KDE LookAndFeelPackage "$(lnf_id_for "$variant")"

        # And the pair Plasma's own day/night switch uses. This is the fix for
        # the fault that made it necessary: `AutomaticLookAndFeel` swaps the
        # whole global theme at sunset, and with nothing of ours named there it
        # swapped to Breeze and Breeze Dark -- taking the colour scheme, the
        # icons and the decorations with it, which reads as "dark did not reach
        # everywhere" rather than as another writer.
        #
        # The switch itself is left exactly as the user has it: on, it now
        # moves between our two packages; off, `theme variant` does the same
        # job. Either way nobody else decides what our desktop looks like.
        lnf_pair_apply

        # KDE caches installed packages; without this the new one is invisible
        # until the next login.
        kbuildsycoca6 --noincremental >/dev/null 2>&1 || true

        # Writing the colours is not the same as the desktop wearing them.
        # Every application already open -- KWin's titlebars included -- holds
        # the palette it read at startup and repaints only when told, which is
        # what `theme variant` has always done and this never did. Without it
        # an apply looked like it had half worked: new windows were right,
        # every window already open kept the old colours until somebody
        # clicked a scheme in System Settings, which sends this same signal.
        notify_palette_changed
        notify_style_changed

        log_step "applied"
        log_info "restart plasmashell to see it: systemctl --user restart plasma-plasmashell.service"
        log_info "undo with: $ALIAS theme revert"
        ;;

    revert)
        # The style first: its record holds what the style was after the
        # theme's own defaults, and the theme's is what gets back to the
        # user's.
        if jq -e '[.entries[] | select(.scope == "style")] | length > 0' "$(kconfig_ledger)" >/dev/null 2>&1; then
            kconfig_revert style
            notify_style_changed
        fi
        kconfig_revert theme
        colors_revert_scheme
        gtk_revert
        remove_colors

        # The colours that were put back reach the open windows the same way
        # the ones taken away did.
        notify_palette_changed
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
        kbuildsycoca6 --noincremental >/dev/null 2>&1 || true
        log_step "reverted"
        log_info "restart plasmashell: systemctl --user restart plasma-plasmashell.service"
        ;;

    status)
        if [ "$WITH_JSON" = 1 ]; then
            styles=$(for s in "${STYLES[@]}"; do
                         IFS='|' read -r id key glob pkg label <<< "$s"
                         printf '%s\t%s\t%s\t%s\t%s\n' "$id" "$key" "$label" \
                             "$(style_installed "$id" && echo true || echo false)" "$(install_command "$pkg" || true)"
                     done | jq -R -s -c '[split("\n")[] | select(length > 0) | split("\t")
                                          | {id: .[0], key: .[1], label: .[2], installed: (.[3] == "true"), install: (.[4] // "")}]')
            has() { [ -e "$1" ] && echo true || echo false; }
            jq -n -c \
                --argjson package "$(has "$LNF_DEST/metadata.json")" \
                --arg active "$(kreadconfig6 --file kdeglobals --group KDE --key LookAndFeelPackage --default '')" \
                --arg lnf "$LNF_PACKAGE_ID" \
                --argjson schemes "$(ls -1 "$COLORS_DIR" 2>/dev/null | grep -c "^$SLUG-")" \
                --argjson switcher "$(has "$SWITCHER_DEST/metadata.json")" \
                --argjson desktoptheme "$(has "$DESKTOPTHEME_DEST/colors")" \
                --argjson splash "$(has "$LNF_DEST/contents/splash/Splash.qml")" \
                --arg style "$(style_active_id)" \
                --argjson styles "$styles" \
                --argjson desktop "$(for part in $(desktop_parts); do
                                        printf '%s\t%s\n' "$part" "$(desktop_part_wanted "$part" && echo true || echo false)"
                                    done | jq -R -s -c 'split("\n")[] | select(length > 0) | split("\t")
                                                        | {(.[0]): (.[1] == "true")}' | jq -s -c 'add
                                                        + {enabled: '"$(config_get '.theme.desktop.enabled' true)"'}')" \
                --argjson styleCustomised "$(jq -e '[.entries[] | select(.scope == "style")] | length > 0' "$(kconfig_ledger)" >/dev/null 2>&1 && echo true || echo false)" \
                --arg variant "$(resolve_variant)" \
                --argjson followMode "$(config_get '.theme.desktop.followMode' false)" \
                --argjson gtkThemes "$(gtk_themes | jq -R -s -c 'split("\n") | map(select(length > 0))')" \
                --argjson materialYou "$([ -f "$XDG_CONFIG_HOME/$MATERIAL_YOU_CONF" ] && echo true || echo false)" \
                '{package: $package, active: ($active == $lnf),
                  parts: {schemes: $schemes, switcher: $switcher, desktoptheme: $desktoptheme, splash: $splash},
                  desktop: $desktop,
                  variant: {resolved: $variant, follows: $followMode},
                  style: $style, styles: $styles, styleCustomised: $styleCustomised,
                  gtkThemes: $gtkThemes, materialYouInstalled: $materialYou}'
            exit 0
        fi
        printf 'packages:     %s\n' "$([ -d "$LNF_DEST" ] && echo "light installed" || echo "light MISSING"), $([ -d "$LNF_DARK_DEST" ] && echo "dark installed" || echo "dark MISSING")"
        printf 'active L&F:   %s\n' "$(kreadconfig6 --file kdeglobals --group KDE --key LookAndFeelPackage --default '<unset>')"
        printf 'day and night: %s\n' "$(case "$(lnf_pair_state)" in
            ours) printf "Plasma's own switch, between our two packages" ;;
            breeze) printf "Plasma's own switch, and NOT between ours -- it will replace this theme at sunset" ;;
            *) printf "ours (theme.mode), Plasma's switch is off" ;;
        esac)"
        printf 'colour:       %s\n' "$(kreadconfig6 --file kdeglobals --group General --key ColorScheme --default '<unset>')"
        printf 'our schemes:  %s installed\n' "$(ls -1 "$COLORS_DIR" 2>/dev/null | grep -c "^$SLUG-")"
        osd_mode status 2>/dev/null || true
        printf 'switcher:     %s\n' "$([ -d "$SWITCHER_DEST" ] && echo "installed" || echo "not installed")"
        printf 'active Alt+Tab: %s\n' "$(kreadconfig6 --file kwinrc --group TabBox --key LayoutName --default '<unset>')"
        printf 'icons:        %s\n' "$(kreadconfig6 --file kdeglobals --group Icons --key Theme --default '<unset>')"
        printf 'widget style: %s\n' "$(kreadconfig6 --file kdeglobals --group KDE --key widgetStyle --default '<unset>')"
        echo
        if [ "$(config_get '.theme.desktop.enabled' true)" = "true" ]; then
            echo 'themes the desktop: yes -- an apply writes these parts:'
        else
            echo 'themes the desktop: no (theme.desktop.enabled is off); an apply would write none of:'
        fi
        for part in $(desktop_parts); do
            printf '  %-12s %s\n' "$part" \
                "$(desktop_part_wanted "$part" && echo "applied" || echo "left as System Settings has it")"
        done
        printf 'light or dark: %s (theme.mode: %s)%s\n' \
            "$(resolve_variant)" "$(config_get '.theme.mode' 'auto')" \
            "$([ "$(config_get '.theme.desktop.followMode' false)" = "true" ] && printf ', and the desktop follows it' || printf '; the desktop follows it only when theme.desktop.followMode is on')"
        echo
        echo 'ledger (what revert would undo):'
        kconfig_ledger_summary theme
        ;;

    variant)
        # Which of light and dark the applications are in.
        #
        # The shell recolours itself from `theme.mode` and needs nobody's
        # permission; the applications read KDE's own configuration, so this
        # writes the colour scheme and icon theme -- ledgered, like every other
        # key this project writes -- and nothing else. The style, the Plasma
        # theme, the decorations and Alt+Tab are the same either way.
        [ -f "$LNF_DEST/contents/defaults" ] \
            || die "the look-and-feel package is not installed ($ALIAS theme apply)"

        case "${1:-}" in
            "")
                nl=$(night_light_daylight)
                printf 'theme.mode:   %s\n' "$(config_get '.theme.mode' 'auto')"
                printf 'night light:  %s\n' "$([ -n "$nl" ] && printf '%s' "$([ "$nl" = true ] && echo daylight || echo night)" || printf 'off or unavailable')"
                printf 'resolved:     %s\n' "$(resolve_variant)"
                case "$(lnf_pair_state)" in
                    ours)   printf 'switched by:  Plasma, between our two packages\n' ;;
                    breeze) printf 'switched by:  Plasma, but between packages that are not ours\n' ;;
                    *)      printf 'switched by:  %s\n' "$([ "$(config_get '.theme.desktop.followMode' false)" = "true" ] && printf 'us (theme.desktop.followMode)' || printf 'nobody')" ;;
                esac
                printf 'colour scheme: %s\n' "$(kreadconfig6 --file kdeglobals --group General --key ColorScheme --default '<unset>')"
                printf 'icons:        %s\n' "$(kreadconfig6 --file kdeglobals --group Icons --key Theme --default '<unset>')"
                exit 0
                ;;
            auto)       variant=$(resolve_variant) ;;
            light|dark) variant=$1 ;;
            *) die "unknown variant: $1 (one of: light dark auto)" ;;
        esac

        # Who switches light and dark, and what is left for us.
        #
        # Plasma has a day/night switch of its own -- "Switch to Dark Mode at
        # Night" -- and when it is on and naming our two packages it swaps the
        # whole look-and-feel at sunset: the colour scheme, the icons, the
        # widget style, the decorations and Alt+Tab, every one of them read
        # from the package's own `defaults`. Writing those again from here is
        # a second hand on the same wheel -- the same keys, on a schedule that
        # can disagree with Plasma's by a few seconds, waking every Qt
        # application on the machine twice for one sunset.
        #
        # So when Plasma is switching, Plasma switches. This fills in only what
        # a look-and-feel package cannot carry: GTK's theme and its dark
        # preference, which live in gsettings and which Plasma never touches,
        # and our own Plasma desktop theme, whose colours are generated per
        # variant rather than shipped as two packages.
        #
        # The switch itself is never written here. It is the user's, set in
        # System Settings; `theme apply` only makes sure the two packages it
        # names are ours, so that turning it on does the right thing.
        case "$(lnf_pair_state)" in
            ours) plasma_owns=1 ;;
            *)    plasma_owns=0 ;;
        esac

        # `--if-following` is what the login unit passes. There are two reasons
        # to do anything at all: Plasma is switching and the gaps need filling,
        # or Plasma is not and the user has asked us to switch instead.
        if [ "$IF_FOLLOWING" = 1 ]; then
            if [ "$(config_get '.theme.desktop.enabled' true)" != "true" ]; then
                log_info "leaving the desktop alone (theme.desktop.enabled is off)"
                exit 0
            fi
            if [ "$plasma_owns" = 0 ] \
               && [ "$(config_get '.theme.desktop.followMode' false)" != "true" ]; then
                log_info "nothing switches light and dark here: Plasma's own switch is off and so is theme.desktop.followMode"
                exit 0
            fi
        fi

        # Called whenever night falls, and on every start, so doing nothing
        # when there is nothing to do matters: a write here wakes every Qt
        # application on the machine.
        colours_agree=1
        if desktop_part_wanted colours; then
            colours_match "$variant" || colours_agree=0
        fi

        gtk_agrees=1
        if desktop_part_wanted gtk && command -v gsettings >/dev/null 2>&1; then
            want_gtk=$([ "$variant" = "light" ] && printf 'prefer-light' || printf 'prefer-dark')
            [ "$(gsettings get "$GSETTINGS_SCHEMA" color-scheme 2>/dev/null | tr -d "'")" = "$want_gtk" ] || gtk_agrees=0

            # The theme name as well, when one is configured. Without this the
            # early exit below calls a desktop "already light" whose GTK theme
            # is the dark half of its pair -- which is the state this key was
            # added to end.
            want_theme=$(gtk_theme_for "$variant")
            if [ -n "$want_theme" ]; then
                [ "$(gsettings get "$GSETTINGS_SCHEMA" gtk-theme 2>/dev/null | tr -d "'")" = "$want_theme" ] \
                    || gtk_agrees=0
            fi
        fi

        material_agrees=1
        if material_you_wanted; then
            want_my=$([ "$variant" = "light" ] && printf 'True' || printf 'False')
            [ "$(kreadconfig6 --file "$XDG_CONFIG_HOME/$MATERIAL_YOU_CONF" \
                              --group CUSTOM --key light --default '' 2>/dev/null)" = "$want_my" ] \
                || material_agrees=0
        fi
        # Whether Plasma has actually switched. This used to be assumed --
        # "Plasma writes the scheme, whether it has caught up is Plasma's
        # business" -- and the assumption held until the evening of 2026-09-22,
        # when the autoswitcher did not fire at all: kded had been running
        # since before a Frameworks upgrade replaced the libraries under it,
        # and its timer never went off at sunset. The shell turned dark, this
        # command said "the desktop is already in dark", and every application
        # stayed light. Noticing costs one read; see `plasma_rescue`.
        #
        # It is the package's *name*, and that is all it is. Whether the
        # variant's colours reached kdeglobals is a second question, asked
        # below -- on the morning of 2026-09-23 the first was yes and the
        # second no, and asking only this one is how a dark desktop was called
        # light three times over. See `plasma_fill_colours`.
        plasma_named=1
        if [ "$plasma_owns" = 1 ]; then
            [ "$(kreadconfig6 --file kdeglobals --group KDE --key LookAndFeelPackage --default '')" \
                = "$(lnf_id_for "$variant")" ] || plasma_named=0
        fi

        # Whose colour scheme is on the desktop, by name and by value. Normally
        # both must be ours; with kde-material-you-colors following, they are
        # deliberately theirs -- they apply MaterialYouLight or MaterialYouDark
        # after us and are meant to. Asking for our name there would make this
        # check fail for ever, and every start would re-apply the lot and
        # restart their unit, which wakes every Qt application on the machine.
        scheme_agrees=1
        if [ "$plasma_owns" = 1 ]; then
            [ "$plasma_named" = 1 ] || scheme_agrees=0
            if material_you_wanted; then
                [ "$material_agrees" = 1 ] || scheme_agrees=0
            else
                [ "$colours_agree" = 1 ] || scheme_agrees=0
            fi
        elif material_you_wanted; then
            scheme_agrees=$material_agrees
        else
            [ "$(kreadconfig6 --file kdeglobals --group General --key ColorScheme --default '')" \
                = "$SLUG-$variant" ] && [ "$colours_agree" = 1 ] || scheme_agrees=0
        fi

        if [ "$scheme_agrees" = 1 ] \
           && cmp -s "$REPO_ROOT/theme/colors/$SLUG-$variant.colors" "$DESKTOPTHEME_DEST/colors" 2>/dev/null \
           && [ "$gtk_agrees" = 1 ]; then
            log_info "the desktop is already in $variant"
            exit 0
        fi

        if [ "$plasma_owns" = 1 ]; then
            log_info "Plasma switches the global theme; filling in what its packages cannot carry"
            [ "$plasma_named" = 0 ] && plasma_rescue "$variant"
            # Whether Plasma switched by itself, was waited for, or was stood
            # in for above, the colours are read again here: they are the half
            # every Qt application actually draws from.
            plasma_fill_colours "$variant"
        else
            apply_defaults "$variant" 1 || die "could not write the $variant variant"

            # The scheme's own colours, not only its name.
            desktop_part_wanted colours && colors_apply_scheme "$variant"
        fi

        # And the applications that ask a portal rather than KDE.
        if desktop_part_wanted gtk; then
            gtk_apply_variant "$variant"
        else
            log_info "leaving GTK alone (theme.desktop.gtk is off)"
        fi

        material_you_wanted && material_you_apply_variant "$variant"

        # Plasma's own widgets read the desktop theme, not the colour scheme,
        # so the variant has to reach both or a light desktop keeps dark applet
        # popups. This one takes a plasmashell restart to show, which is not
        # something to do to somebody at sunset -- it is right from the next
        # start either way.
        install_desktoptheme "$variant" || die "could not recolour the desktop theme"

        # The active package follows the variant too: it is where the OSD, the
        # splash and the logout screen come from, and System Settings shows it
        # as the global theme in force. Plasma's switch writes this one itself.
        [ "$plasma_owns" = 1 ] \
            || kconfig_set theme kdeglobals KDE LookAndFeelPackage "$(lnf_id_for "$variant")"

        notify_palette_changed
        if [ "$plasma_owns" = 1 ]; then
            log_step "filled in $variant behind Plasma's switch"
        else
            log_step "the desktop is in $variant"
        fi
        ;;

    osd)
        osd_mode "${1:-status}"
        ;;

    # Its own ledger scope, so a style tried from the settings page can be
    # undone without taking the whole theme with it. `revert` undoes both.
    style)
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
        ;;

    # Prints the command; runs it only when asked, in a terminal, because it
    # installs a system package and asks for a password.
    install-style)
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
        ;;

    *) die "unknown command: $cmd (expected apply, revert, variant, osd, style, install-style or status)" ;;
esac

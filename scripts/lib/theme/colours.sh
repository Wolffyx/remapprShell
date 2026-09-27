# shellcheck shell=bash
# The colours themselves: copying a scheme's colours into kdeglobals, saying
# so to every application, putting the previous ones back, and asking whether
# kdeglobals holds a variant's colours at all.
#
# Sourced by theme.sh, never executed. Requires brand.sh, log.sh and
# config.sh.

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

# What System Settings' colours page sends. Qt applications reread kdeglobals
# on it, which is what makes a colour scheme written here reach a window that
# is already open rather than only the next one started.
notify_palette_changed() {
    session_available || return 0
    busctl --user emit /KGlobalSettings org.kde.KGlobalSettings notifyChange ii 0 0 >/dev/null 2>&1 || true
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

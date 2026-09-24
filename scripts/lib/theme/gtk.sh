# shellcheck shell=bash
# GTK: the colour-scheme preference in dconf, the ini files older GTK reads,
# the theme name a variant wears, the GTK themes installed, and putting all of
# it back.
#
# Sourced by theme.sh, never executed. Requires brand.sh, log.sh, kconfig.sh
# and config.sh.

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

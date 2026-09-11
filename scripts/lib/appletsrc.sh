# shellcheck shell=bash
# Generates a Plasma applet layout from the same panel description the
# Quickshell renderer draws.
#
# This is the riskiest write in the project: it is the one place we author
# appletsrc rather than read it, and a malformed containment leaves plasmashell
# with no usable panel and no obvious way back. Three rules follow from that,
# and they are enforced here rather than remembered at the call site:
#
#   1. Generate into a temporary file. Nothing is written where plasmashell can
#      read it until the whole layout exists.
#   2. Validate before installing. A file that fails validation is a bug in
#      this generator, and it must fail loudly with the layout still intact.
#   3. Install atomically, keeping the previous file. A rename within one
#      directory cannot leave a half-written layout behind, and the copy is
#      what a failed switch is rolled back to.
#
# `immutability` is deliberately left at 0 (mutable). Writing 1 -- as some
# shells do -- means the user cannot fix their own panel from Plasma's UI, so
# a generator bug becomes unrecoverable without a terminal.
#
# Requires brand.sh, log.sh.

# Ids are allocated by us because we own the whole file. They start high so
# they do not collide with the ids Plasma has already handed out in the stock
# package's layout, which are namespaced separately but appear under the same
# `[PlasmaViews][Panel <id>]` group name in plasmashellrc.
APPLETSRC_DESKTOP_ID=810
APPLETSRC_PANEL_ID=811
APPLETSRC_APPLET_BASE=820

# Plasma::Types::Location
_appletsrc_location() {
    case "$1" in
        top)    echo 3 ;;
        bottom) echo 4 ;;
        left)   echo 5 ;;
        right)  echo 6 ;;
        *)      echo 4 ;;
    esac
}

# Plasma::Types::FormFactor -- Horizontal 2, Vertical 3.
_appletsrc_formfactor() {
    case "$1" in
        left|right) echo 3 ;;
        *)          echo 2 ;;
    esac
}

appletsrc_path() { printf '%s/plasma-%s-appletsrc' "$XDG_CONFIG_HOME" "$1"; }

# The wallpaper the given applet layout uses, if it names one.
#
# Carried across a renderer switch because the desktop is Plasma's in every
# renderer, and this project has no business changing it. Without this, moving
# to a package that has never run before hands the user Plasma's default
# wallpaper and no explanation -- a switch that was supposed to be about the
# panel silently redecorating their desktop.
appletsrc_wallpaper() {
    local src=$1
    [ -f "$src" ] || return 0
    # The first Image= under any Wallpaper group. Several desktop containments
    # (one per screen) normally share one image; taking the first is right when
    # they agree and harmless when they do not, since Plasma keeps whatever the
    # user later sets per screen.
    awk '
        /^\[Containments\]\[[0-9]+\]\[Wallpaper\]/ { inwp = 1; next }
        /^\[/ { inwp = 0 }
        inwp && /^Image=/ { sub(/^Image=/, ""); print; exit }
    ' "$src"
}

# The applet a widget maps to under the Plasma renderer, or nothing if it has
# no mapping. The manifest is the source of truth for support: a widget with no
# `renderers.plasma` block is one this renderer genuinely cannot draw, and
# substituting something approximate would be a worse answer than saying so.
appletsrc_applet_for() {
    local index=$1 id=$2
    jq -r --arg id "$id" \
        '.widgets[] | select(.id == $id) | .renderers.plasma.applet // empty' "$index"
}

# Enabled entries, in config order, that this renderer cannot draw.
appletsrc_unsupported() {
    local index=$1 config=$2
    local id
    while IFS= read -r id; do
        [ -n "$id" ] || continue
        [ -n "$(appletsrc_applet_for "$index" "$id")" ] || printf '%s\n' "$id"
    done < <(jq -r '[.bar.entries[]? | select(.enabled != false)] | .[].id' "$config")
}

# Whether a widget's applet is one Plasma's system tray shows by itself.
#
# Plasma's tray is not only StatusNotifierItems: volume, network, Bluetooth,
# battery and notifications are applets it hosts inside itself, on by default.
# Our own renderer draws each of those as a widget of its own, because our tray
# is only the StatusNotifierItems -- so a panel described with both `tray` and
# `volume` means one volume icon to us and would mean two to Plasma. The
# manifest says which applets these are (`renderers.plasma.inSystemTray`).
appletsrc_in_tray() {
    local index=$1 id=$2
    [ "$(jq -r --arg id "$id" \
        '.widgets[] | select(.id == $id) | .renderers.plasma.inSystemTray // false' "$index")" = "true" ]
}

# Whether the enabled entries include Plasma's system tray.
appletsrc_has_tray() {
    local index=$1 config=$2 id
    while IFS= read -r id; do
        [ "$(appletsrc_applet_for "$index" "$id")" = "org.kde.plasma.systemtray" ] && return 0
    done < <(jq -r '[.bar.entries[]? | select(.enabled != false)] | .[].id' "$config")
    return 1
}

# Enabled entries, in config order, left out because the tray already shows
# them. Nothing when there is no tray: then each stands on the panel alone.
appletsrc_folded_into_tray() {
    local index=$1 config=$2 id
    appletsrc_has_tray "$index" "$config" || return 0
    while IFS= read -r id; do
        [ -n "$id" ] || continue
        appletsrc_in_tray "$index" "$id" && printf '%s\n' "$id"
    done < <(jq -r '[.bar.entries[]? | select(.enabled != false)] | .[].id' "$config")
}

# Writes the `[Configuration]` groups a widget's manifest declares for its
# Plasma applet. Only what the manifest states is written -- our own widget
# settings are not translated into applet settings, because a guessed mapping
# ("HH:mm" onto a boolean 24-hour flag) silently produces a panel that does not
# match the configuration it claims to come from. The compatibility matrix
# tells the truth instead.
_appletsrc_applet_config() {
    local index=$1 id=$2 panel=$3 applet=$4 out=$5
    local groups
    groups=$(jq -r --arg id "$id" \
        '.widgets[] | select(.id == $id) | .renderers.plasma.config // {} | keys[]' "$index")

    local group
    while IFS= read -r group; do
        [ -n "$group" ] || continue
        printf '\n[Containments][%s][Applets][%s][Configuration][%s]\n' "$panel" "$applet" "$group" >> "$out"
        jq -r --arg id "$id" --arg g "$group" \
            '.widgets[] | select(.id == $id) | .renderers.plasma.config[$g]
             | to_entries[] | "\(.key)=\(.value | if type == "boolean" then tostring else . end)"' \
            "$index" >> "$out"
    done <<< "$groups"
}

_appletsrc_spacer() {
    local panel=$1 applet=$2 out=$3
    {
        printf '\n[Containments][%s][Applets][%s]\n' "$panel" "$applet"
        printf 'immutability=0\n'
        printf 'plugin=org.kde.plasma.panelspacer\n'
        printf '\n[Containments][%s][Applets][%s][Configuration][General]\n' "$panel" "$applet"
        printf 'expanding=true\n'
    } >> "$out"
}

# appletsrc_generate <out> <effective-config.json> <widget-index.json> <renderer>
#
# `renderer` decides whether a panel containment is written at all. There is
# one key and one generator, so "two panels at the same screen edge" is not a
# state this can produce.
appletsrc_generate() {
    local out=$1 config=$2 index=$3 renderer=$4 wallpaper=${5:-}

    local position
    position=$(jq -r '.panel.position // "bottom"' "$config")

    : > "$out"

    {
        printf '[ActionPlugins][0]\n'
        printf 'RightButton;NoModifier=org.kde.contextmenu\n'
        printf 'MiddleButton;NoModifier=org.kde.paste\n'
        printf '\n[ActionPlugins][1]\n'
        printf 'RightButton;NoModifier=org.kde.contextmenu\n'

        # One desktop containment. plasmashell adds one per further screen as
        # it finds them; the desktop is Plasma's in every renderer, so this is
        # the whole of our involvement with it.
        printf '\n[Containments][%s]\n' "$APPLETSRC_DESKTOP_ID"
        printf 'activityId=\n'
        printf 'formfactor=0\n'
        printf 'immutability=0\n'
        printf 'lastScreen=0\n'
        printf 'location=0\n'
        printf 'plugin=org.kde.plasma.folder\n'
        printf 'wallpaperplugin=org.kde.image\n'
    } >> "$out"

    if [ -n "$wallpaper" ]; then
        {
            printf '\n[Containments][%s][Wallpaper][org.kde.image][General]\n' "$APPLETSRC_DESKTOP_ID"
            printf 'Image=%s\n' "$wallpaper"
        } >> "$out"
    fi

    if [ "$renderer" != "plasma" ]; then
        log_debug "appletsrc: no panel containment (renderer: $renderer)"
        return 0
    fi

    {
        printf '\n[Containments][%s]\n' "$APPLETSRC_PANEL_ID"
        printf 'activityId=\n'
        printf 'formfactor=%s\n' "$(_appletsrc_formfactor "$position")"
        printf 'immutability=0\n'
        printf 'lastScreen=0\n'
        printf 'location=%s\n' "$(_appletsrc_location "$position")"
        printf 'plugin=org.kde.panel\n'
        printf 'wallpaperplugin=org.kde.image\n'
    } >> "$out"

    # Zones become applet order plus expanding spacers, which is how a Plasma
    # panel expresses "these hug the left edge, this one is centred".
    local -a order=()
    local next=$APPLETSRC_APPLET_BASE
    local -a middle_ids right_ids left_ids

    _zone_ids() {
        local zone=$1
        jq -r --arg z "$zone" \
            '[.bar.entries[]? | select(.enabled != false) | select(.zone == $z)] | .[].id' "$config"
    }

    mapfile -t left_ids   < <(_zone_ids left)
    mapfile -t middle_ids < <(_zone_ids middle)
    mapfile -t right_ids  < <(_zone_ids right)

    local tray=no
    appletsrc_has_tray "$index" "$config" && tray=yes

    _emit_zone() {
        local -n ids=$1
        local id applet
        for id in "${ids[@]}"; do
            [ -n "$id" ] || continue
            applet=$(appletsrc_applet_for "$index" "$id")
            if [ -z "$applet" ]; then
                # Reported by the caller before anything is written; skipped
                # here so a widget with no Plasma equivalent leaves a gap
                # rather than a broken applet.
                log_debug "appletsrc: '$id' has no Plasma applet, left out"
                continue
            fi
            if [ "$tray" = yes ] && appletsrc_in_tray "$index" "$id"; then
                log_debug "appletsrc: '$id' is shown by the system tray, not added beside it"
                continue
            fi
            {
                printf '\n[Containments][%s][Applets][%s]\n' "$APPLETSRC_PANEL_ID" "$next"
                printf 'immutability=0\n'
                printf 'plugin=%s\n' "$applet"
            } >> "$out"
            _appletsrc_applet_config "$index" "$id" "$APPLETSRC_PANEL_ID" "$next" "$out"
            order+=("$next")
            next=$((next + 1))
        done
    }

    _emit_zone left_ids

    # Two expanding spacers are what centre the middle zone on the panel
    # rather than on whatever space the other zones left over. With no middle
    # zone one spacer is enough to push the right zone to its edge.
    if [ "${#middle_ids[@]}" -gt 0 ] && [ -n "${middle_ids[0]:-}" ]; then
        _appletsrc_spacer "$APPLETSRC_PANEL_ID" "$next" "$out"; order+=("$next"); next=$((next + 1))
        _emit_zone middle_ids
        _appletsrc_spacer "$APPLETSRC_PANEL_ID" "$next" "$out"; order+=("$next"); next=$((next + 1))
    elif [ "${#right_ids[@]}" -gt 0 ] && [ -n "${right_ids[0]:-}" ]; then
        _appletsrc_spacer "$APPLETSRC_PANEL_ID" "$next" "$out"; order+=("$next"); next=$((next + 1))
    fi

    _emit_zone right_ids

    {
        printf '\n[Containments][%s][General]\n' "$APPLETSRC_PANEL_ID"
        printf 'AppletOrder=%s\n' "$(IFS=';'; printf '%s' "${order[*]}")"
    } >> "$out"
}

# appletsrc_validate <file> <expect-panel: yes|no>
#
# Structural, not semantic: it catches the failures a generator bug actually
# produces -- a truncated file, a repeated group, an applet in the order that
# was never defined -- before plasmashell is ever pointed at the result.
appletsrc_validate() {
    local file=$1 expect_panel=$2
    local errors=0

    [ -s "$file" ] || { log_error "generated layout is empty: $file"; return 1; }

    local line n=0
    while IFS= read -r line; do
        n=$((n + 1))
        [ -n "$line" ] || continue
        case "$line" in
            \[*\]) continue ;;
            *=*)   continue ;;
            *) log_error "line $n is neither a group nor a key: $line"; errors=$((errors + 1)) ;;
        esac
    done < "$file"

    local dupes
    dupes=$(grep -c '^\[' "$file")
    if [ "$dupes" -ne "$(grep '^\[' "$file" | sort -u | wc -l)" ]; then
        log_error "duplicate group headers in $file:"
        grep '^\[' "$file" | sort | uniq -d | sed 's/^/  /' >&2
        errors=$((errors + 1))
    fi

    grep -q '^plugin=org.kde.plasma.folder$' "$file" \
        || { log_error "no desktop containment"; errors=$((errors + 1)); }

    local panels
    panels=$(grep -c '^plugin=org.kde.panel$' "$file" || true)
    case "$expect_panel" in
        yes) [ "$panels" -eq 1 ] || { log_error "expected exactly one panel containment, found $panels"; errors=$((errors + 1)); } ;;
        no)  [ "$panels" -eq 0 ] || { log_error "expected no panel containment, found $panels"; errors=$((errors + 1)); } ;;
    esac

    if [ "$panels" -eq 1 ]; then
        # Every applet named in the order must exist, and every applet defined
        # must be named. A mismatch either way is an applet that silently does
        # not appear, which looks exactly like a widget that failed to load.
        local order defined
        order=$(sed -n 's/^AppletOrder=//p' "$file" | tr ';' '\n' | grep -v '^$' | sort -u)
        defined=$(grep -oE '^\[Containments\]\[[0-9]+\]\[Applets\]\[[0-9]+\]$' "$file" \
                  | grep -oE '[0-9]+\]$' | tr -d ']' | sort -u)
        if [ "$order" != "$defined" ]; then
            log_error "AppletOrder does not match the applets defined in $file"
            diff <(printf '%s\n' "$order") <(printf '%s\n' "$defined") | sed 's/^/  /' >&2
            errors=$((errors + 1))
        fi

        local applets
        applets=$(grep -cE '^\[Containments\]\[[0-9]+\]\[Applets\]\[[0-9]+\]$' "$file")
        local plugins
        plugins=$(grep -c '^plugin=' "$file")
        # containments + applets, each with exactly one plugin key
        [ "$plugins" -eq $((applets + 2)) ] \
            || { log_error "every containment and applet needs exactly one plugin key ($plugins for $((applets + 2)))"; errors=$((errors + 1)); }
    fi

    [ "$errors" -eq 0 ] || return 1
    log_debug "appletsrc: $file validates"
}

# How many containments a layout defines. The number that matters when asking
# whether a layout is still the layout it was.
appletsrc_containment_count() {
    local file=$1
    [ -f "$file" ] || { printf '0'; return 0; }
    local n
    n=$(grep -cE '^\[Containments\]\[[0-9]+\]$' "$file")
    printf '%s' "${n:-0}"
}

# --- protecting a layout we are switching away from ------------------------
#
# Observed on a live desktop: switching plasmashell's ShellPackage away from a
# third-party package left that package's applet layout gutted -- every
# containment gone, the panel and desktop it described with them. plasmashell
# had written its own now-empty view of that package's config back to disk on
# the way out.
#
# It is not our write, but it happens because of our switch, and "it was
# plasmashell" is no comfort to someone whose layout has just been deleted.

# appletsrc_hold <pkg> <backup-dir>
# Copies that package's layout aside and prints "<containments> <copy path>".
appletsrc_hold() {
    local pkg=$1 backup_dir=$2
    local src
    src=$(appletsrc_path "$pkg")
    [ -f "$src" ] || return 0

    mkdir -p "$backup_dir" || return 0
    local copy="$backup_dir/$(basename "$src")"
    cp -a "$src" "$copy" || return 0

    printf '%s %s' "$(appletsrc_containment_count "$src")" "$copy"
}

# appletsrc_restore_if_gutted <pkg> <copy> <containments-before>
#
# Restores only when containments have gone missing. Restoring unconditionally
# would undo a change the user made in the meantime, which is its own kind of
# data loss.
appletsrc_restore_if_gutted() {
    local pkg=$1 copy=$2 before=$3
    [ -n "$copy" ] && [ -f "$copy" ] || return 0

    local dest now
    dest=$(appletsrc_path "$pkg")
    now=$(appletsrc_containment_count "$dest")
    [ "$now" -ge "$before" ] && return 0

    cp -a "$copy" "$dest" || {
        log_error "$pkg's layout lost containments and could not be put back"
        log_error "  a copy is at $copy"
        return 1
    }
    log_warn "plasmashell emptied $pkg's applet layout on the way out"
    log_info "  put it back from $copy ($before containment(s), had $now)"
}

# appletsrc_install <generated> <dest> <backup-dir>
#
# The previous layout is copied out first: it is what a failed switch is rolled
# back to, and it is the user's panel if they ever edited the generated one by
# hand. The install itself is a rename inside one directory, which either
# happens or does not -- plasmashell can never read a half-written layout.
appletsrc_install() {
    local generated=$1 dest=$2 backup_dir=$3

    if [ -f "$dest" ]; then
        mkdir -p "$backup_dir"
        cp -a "$dest" "$backup_dir/$(basename "$dest")" || {
            log_error "could not keep a copy of the current layout; refusing to replace it"
            return 1
        }
        log_debug "appletsrc: kept $backup_dir/$(basename "$dest")"
    fi

    mkdir -p "$(dirname "$dest")"
    local staged="$dest.new"
    cp "$generated" "$staged" || { log_error "could not stage the layout next to $dest"; return 1; }
    chmod 600 "$staged"
    mv -f "$staged" "$dest" || { rm -f "$staged"; log_error "could not install $dest"; return 1; }
    log_step "wrote $dest"
}

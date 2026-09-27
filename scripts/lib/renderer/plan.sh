# shellcheck shell=bash
# What the shell is configured to draw the panel with, what the Plasma
# renderer would leave out of it, and the one setting that says which.
#
# Sourced by renderer.sh, never executed. Requires brand.sh, log.sh,
# config.sh and appletsrc.sh.

widget_index() {
    local installed="$QS_CONFIG_DIR/widgets/index.json"
    [ -f "$installed" ] && { printf '%s' "$installed"; return; }
    printf '%s/shell/widgets/index.json' "$REPO_ROOT"
}

# Defaults plus the user's sparse delta, which is what the shell itself draws
# from (lib/config.sh). Generating the Plasma panel from anything else would
# let the two renderers disagree about what the panel contains -- and the
# defaults are the installed copy first for the same reason: a renderer
# generated from a different description than the one on screen would be a
# confusing thing to debug.
effective_config() {
    config_profile_broken && log_warn "$(profile_file) does not parse; using the shipped defaults"
    config_merged
}

configured_renderer() { effective_config | jq -r '.panel.renderer // "quickshell"'; }

# live_shell_package and package_for are lib/renderers.sh's: doctor, the report
# and the lock screen ask the same two questions.

# Will anything of ours actually draw a panel?
#
# The quickshell renderer's shell package ships no Plasma panel *because our
# shell draws it*. If our shell is neither running nor installed, switching to
# it leaves plasmashell with no panel and nothing in its place -- a desktop with
# no panel at all, which is what this check exists to prevent. It cost a real
# desktop its panel once.
shell_will_draw() {
    # Matched on the installed path, not the slug: the slug appears in a
    # development run from a checkout too, and more importantly it makes this
    # answer depend on which HOME is in play -- which is what lets a test in a
    # throwaway HOME get a deterministic answer instead of inheriting whatever
    # the developer happens to be running.
    shell_running && return 0
    session_available && systemctl --user is-active "$SYSTEMD_UNIT" >/dev/null 2>&1 && return 0
    session_available && systemctl --user is-enabled "$SYSTEMD_UNIT" >/dev/null 2>&1 && return 0
    return 1
}

# Writes panel.renderer into the active profile, sparsely: the profile holds
# what the user changed, not a materialised copy of today's defaults.
write_renderer_setting() {
    local target=$1 file
    file=$(profile_file)
    config_set_string '.panel.renderer' "$target"
    case $? in
        0) log_debug "set panel.renderer=$target in $file" ;;
        2) log_error "$file does not parse; refusing to write over it"
           log_info "  fix it first: jq . $file"
           return 1 ;;
        *) return 1 ;;
    esac
}

# --- reporting -------------------------------------------------------------

compat_report() {   # <target> <effective config file>
    local target=$1 config=$2 index unsupported folded
    [ "$target" = "plasma" ] || return 0
    index=$(widget_index)

    unsupported=$(appletsrc_unsupported "$index" "$config")
    folded=$(appletsrc_folded_into_tray "$index" "$config")

    # Not a loss, so not a warning: the same icons, drawn by Plasma's tray.
    if [ -n "$folded" ]; then
        log_info "Plasma's system tray shows these itself, so they are not added beside it:"
        printf '%s\n' "$folded" | sed 's/^/        /' >&2
    fi

    [ -n "$unsupported" ] || { log_info "every enabled widget has a Plasma applet"; return 0; }

    log_warn "the Plasma renderer cannot draw these enabled widgets:"
    printf '%s\n' "$unsupported" | sed 's/^/        /' >&2
    log_info "  they will be left out of the panel until you switch back"
    return 0
}

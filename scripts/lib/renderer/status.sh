# shellcheck shell=bash
# The two commands that say what draws the panel: `list` and `status`.
#
# Sourced by renderer.sh, never executed. Requires brand.sh, kconfig.sh,
# appletsrc.sh, renderers.sh -- and plan.sh.

renderer_list() {   # one JSON array instead of a table when $JSON is 1
    local current r label note name dir rows
    current=$(configured_renderer)
    rows=()
    while read -r r; do
        case "$r" in
            quickshell) label="This shell"
                        note="Our own panel, drawn as a layer-shell surface. Every widget, and every visual effect." ;;
            plasma)     label="Plasma"
                        note="Drawn by plasmashell from this same configuration, using stock applets. No shaders, no blur, and any widget without a Plasma equivalent is left out." ;;
            none)       label="Nothing"
                        note="Your stock Plasma panels, exactly as they were. Nothing of ours is drawn." ;;
            *)          name=$(renderer_config_name "$r")
                        label=$name
                        dir=$(renderer_config_dir "$name"); dir=${dir/#"$HOME"/\~}
                        note="Another Quickshell shell, found in $dir. It draws its own bar from its own code; none of ours runs in it." ;;
        esac
        rows+=("$(jq -nc --arg id "$r" --arg label "$label" --arg note "$note" \
                    --argjson current "$([ "$r" = "$current" ] && echo true || echo false)" \
                    '{id: $id, label: $label, note: $note, current: $current}')")
    done < <(renderer_ids)
    # A profile can name a configuration that has since been removed. It
    # is still what is configured, so it is still listed -- as missing.
    if renderer_is_foreign "$current" && [ -z "$(renderer_config_dir "$(renderer_config_name "$current")")" ]; then
        rows+=("$(jq -nc --arg id "$current" --arg label "$(renderer_config_name "$current")" \
                    '{id: $id, label: $label, note: "Configured, but no Quickshell configuration of that name is on this machine any more.", current: true, absent: true}')")
    fi
    if [ "$JSON" = 1 ]; then
        printf '%s\n' "${rows[@]}" | jq -sc .
    else
        printf '%s\n' "${rows[@]}" | jq -r '"\(if .current then "*" else " " end) \(.id | . + " " * ([22 - length, 1] | max))\(.note)"'
    fi
}

renderer_status() {
    local configured f
    configured=$(configured_renderer)
    printf 'configured:     %s\n' "$configured"
    printf 'shell package:  %s\n' "$(live_shell_package)"
    printf 'expected:       %s\n' "$(package_for "$configured")"
    printf 'packages:       %s\n' \
        "$([ -d "$PLASMA_SHELLS_DIR/$SHELL_PACKAGE_ID" ] && echo "installed" || echo "not installed")"
    printf 'applet layout:  %s\n' "$(appletsrc_path "$(package_for "$configured")")"
    if [ "$configured" = "plasma" ]; then
        f=$(appletsrc_path "$PLASMA_SHELL_PACKAGE_ID")
        if [ -f "$f" ]; then
            printf 'panel applets:  %s\n' "$(sed -n 's/^AppletOrder=//p' "$f" | tr ';' ' ')"
        else
            printf 'panel applets:  not generated yet\n'
        fi
    fi
    echo
    echo 'ledger (what revert would undo):'
    kconfig_ledger_summary backend
}

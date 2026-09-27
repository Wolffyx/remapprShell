# shellcheck shell=bash
# The two commands that say what draws the panel: `list` and `status`.
#
# Sourced by renderer.sh, never executed. Requires brand.sh, kconfig.sh,
# appletsrc.sh, renderers.sh -- and plan.sh.

renderer_list() {   # one JSON array instead of a table when $JSON is 1
    local current r label note name dir is_current program
    local -a fields=()
    local -A dirs=()
    current=$(configured_renderer)

    # Where each configuration is, read once. Naming it in a row asked
    # renderer_config_dir, which scans every config root again -- once for
    # each foreign row, and once more for the check below.
    while IFS=$'\t' read -r name dir; do
        dirs[$name]=$dir
    done < <(quickshell_configs)

    # Five fields a row -- id, label, note, whether it is current, whether it
    # is missing -- for one jq at the end, where it was one a row.
    while read -r r; do
        case "$r" in
            quickshell) label="This shell"
                        note="Our own panel, drawn as a layer-shell surface. Every widget, and every visual effect." ;;
            plasma)     label="Plasma"
                        note="Drawn by plasmashell from this same configuration, using stock applets. No shaders, no blur, and any widget without a Plasma equivalent is left out." ;;
            none)       label="Nothing"
                        note="Your stock Plasma panels, exactly as they were. Nothing of ours is drawn." ;;
            *)          name=${r#"$RENDERER_FOREIGN_PREFIX"}
                        label=$name
                        dir=${dirs[$name]:-}; dir=${dir/#"$HOME"/\~}
                        note="Another Quickshell shell, found in $dir. It draws its own bar from its own code; none of ours runs in it." ;;
        esac
        is_current=false
        [ "$r" = "$current" ] && is_current=true
        fields+=("$r" "$label" "$note" "$is_current" false)
    done < <(renderer_ids)
    # A profile can name a configuration that has since been removed. It
    # is still what is configured, so it is still listed -- as missing.
    name=${current#"$RENDERER_FOREIGN_PREFIX"}
    if renderer_is_foreign "$current" && [ -z "${dirs[$name]:-}" ]; then
        fields+=("$current" "$name" "Configured, but no Quickshell configuration of that name is on this machine any more." true true)
    fi

    # Handed over as arguments, after `--` so that none of them can be read
    # as an option of jq's own.
    program='[$ARGS.positional as $f | range(0; $f | length; 5) | $f[.:. + 5]
              | {id: .[0], label: .[1], note: .[2], current: (.[3] == "true")}
                + (if .[4] == "true" then {absent: true} else {} end)]'
    if [ "$JSON" = 1 ]; then
        jq -nc "$program" --args -- "${fields[@]}"
    else
        jq -nr "$program"' | .[] | "\(if .current then "*" else " " end) \(.id | . + " " * ([22 - length, 1] | max))\(.note)"' \
            --args -- "${fields[@]}"
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

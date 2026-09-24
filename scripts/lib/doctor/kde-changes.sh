# shellcheck shell=bash
# Every KDE key this project has changed, from the ledger, beside what the key
# says now.
#
# A section of doctor.sh, which sources it and supplies ok, warn, bad, fix and
# section. Requires brand.sh and kconfig.sh.

doctor_kde_changes() {
    local led drift scope file group key had value gargs live
    section "KDE configuration we have changed"

    led=$(kconfig_ledger)
    if [ -s "$led" ] && [ "$(jq '.entries | length' "$led")" -gt 0 ]; then
        drift=0
        while IFS=$'\t' read -r scope file group key had value; do
            mapfile -t gargs < <(_kconfig_group_args "$group")
            live=$(kreadconfig6 --file "$file" "${gargs[@]}" --key "$key" --default '<unset>' 2>/dev/null)
            printf '  %-9s %s [%s] %s = %s\n' "[$scope]" "$file" "$group" "$key" "$live"
            [ "$live" = "<unset>" ] && drift=$((drift + 1))
        done < <(jq -r '.entries[] | [(.scope // "-"), .file, .group, .key, (.had|tostring), .value] | @tsv' "$led")

        if [ "$drift" -gt 0 ]; then
            warn "$drift recorded key(s) are no longer set"
            fix "something else changed them; revert is still safe and will restore the recorded values"
        fi
        fix "undo everything: $ALIAS theme revert / edges revert / shortcuts revert"
    else
        ok "no KDE settings changed by this project"
    fi
}

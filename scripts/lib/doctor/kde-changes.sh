# shellcheck shell=bash
# Every KDE key this project has changed, from the ledger, beside what the key
# says now.
#
# A section of doctor.sh, which sources it and supplies ok, warn, bad, fix and
# section. Requires brand.sh and kconfig.sh.

doctor_kde_changes() {
    local led drift scope file group key had value live
    section "KDE configuration we have changed"

    led=$(kconfig_ledger)
    if [ -s "$led" ] && [ "$(jq '.entries | length' "$led")" -gt 0 ]; then
        drift=0
        # One kreadconfig6 a key, and it stays: the value KDE reads is the
        # file's cascaded through XDG_CONFIG_DIRS -- kdedefaults/ among them
        # in a Plasma session -- with its escapes, [$i] and [$e] applied, and
        # a second reading of the files here would only be right until it met
        # one of those.
        while IFS=$'\t' read -r scope file group key had value; do
            _kconfig_gargs "$group"
            live=$(kreadconfig6 --file "$file" "${KCONFIG_GARGS[@]}" --key "$key" --default '<unset>' 2>/dev/null)
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

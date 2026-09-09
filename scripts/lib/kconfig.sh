# shellcheck shell=bash
# KDE configuration writes, with an exact undo.
#
# Every key this project sets is recorded with its prior state before being
# changed, so reverting writes back precisely what was there -- including the
# distinction between "the key held this value" and "the key did not exist".
# Deleting a key that KDE had set to its default is not the same as restoring
# it, and a blind delete on revert is how a theme leaves a desktop subtly wrong.
#
# Requires brand.sh, log.sh.

kconfig_ledger() { printf '%s/kconfig-ledger.json' "$STATE_DIR"; }

_kconfig_ledger_init() {
    local led
    led=$(kconfig_ledger)
    mkdir -p "$(dirname "$led")"
    [ -s "$led" ] || printf '{"entries":[]}\n' > "$led"
}

# kconfig_set <scope> <file> <group> <key> <value>
#
# The scope groups related changes -- "theme", "edges", "backend" -- so each
# feature can be undone on its own. Without it a single shared ledger means
# reverting the screen edges also reverts the theme, which is not what anyone
# asked for.
#
# The group may be nested, written as "A/B" -- kwriteconfig6 takes repeated
# --group arguments for that.
kconfig_set() {
    local scope=$1 file=$2 group=$3 key=$4 value=$5
    _kconfig_ledger_init

    local -a gargs=()
    local g
    while IFS= read -r g; do
        [ -n "$g" ] && gargs+=(--group "$g")
    done < <(printf '%s\n' "${group//\// }" | tr ' ' '\n')

    # Read the prior state before touching anything. A plain read cannot
    # distinguish "unset" from "set to empty", so an improbable sentinel is
    # passed as the default and compared exactly. The difference matters: on
    # revert, restoring an empty value and deleting the key produce different
    # desktops.
    local sentinel="__rmpr_absent_1f8b__"
    local prior had
    prior=$(kreadconfig6 --file "$file" "${gargs[@]}" --key "$key" --default "$sentinel" 2>/dev/null || printf '%s' "$sentinel")
    if [ "$prior" = "$sentinel" ]; then
        had=false
        prior=""
    else
        had=true
    fi

    # Recorded only the first time: the ledger must hold the state before this
    # project touched the key, not before the most recent write.
    local led
    led=$(kconfig_ledger)
    if ! jq -e --arg f "$file" --arg g "$group" --arg k "$key" \
            '.entries[] | select(.file == $f and .group == $g and .key == $k)' "$led" >/dev/null 2>&1; then
        local tmp
        tmp=$(mktemp)
        jq --arg s "$scope" --arg f "$file" --arg g "$group" --arg k "$key" \
           --argjson had "$had" --arg v "$prior" \
           '.entries += [{scope: $s, file: $f, group: $g, key: $k, had: $had, value: $v}]' "$led" > "$tmp"
        mv "$tmp" "$led"
    fi

    kwriteconfig6 --file "$file" "${gargs[@]}" --key "$key" "$value"
    log_debug "kconfig: $file [$group] $key = $value (was: $([ "$had" = true ] && printf '%s' "$prior" || printf '<unset>'))"
}

# kconfig_revert <scope|--all>
#
# Puts the recorded keys back and drops them from the ledger. Entries are
# reverted newest first: if two scopes ever touched the same key, the older
# record is the one that holds the state before this project was involved.
kconfig_revert() {
    local scope=${1:---all}
    local led
    led=$(kconfig_ledger)
    [ -s "$led" ] || { log_info "nothing to revert"; return 0; }

    local filter
    if [ "$scope" = "--all" ]; then
        filter='.entries'
    else
        filter=$(printf '[.entries[] | select(.scope == "%s")]' "$scope")
    fi

    local count
    count=$(jq "$filter | length" "$led")
    [ "$count" -gt 0 ] || { log_info "nothing to revert${scope:+ for $scope}"; return 0; }

    local file group key had value
    while IFS=$'\t' read -r file group key had value; do
        local -a gargs=()
        local g
        while IFS= read -r g; do
            [ -n "$g" ] && gargs+=(--group "$g")
        done < <(printf '%s\n' "${group//\// }" | tr ' ' '\n')

        if [ "$had" = "true" ]; then
            kwriteconfig6 --file "$file" "${gargs[@]}" --key "$key" "$value"
            log_debug "kconfig: restored $file [$group] $key = $value"
        else
            kwriteconfig6 --file "$file" "${gargs[@]}" --key "$key" --delete
            log_debug "kconfig: removed $file [$group] $key (was unset)"
        fi
    done < <(jq -r "$filter | reverse | .[] | [.file, .group, .key, (.had|tostring), .value] | @tsv" "$led")

    # Drop only what was reverted; other scopes keep their records.
    local tmp
    tmp=$(mktemp)
    if [ "$scope" = "--all" ]; then
        printf '{"entries":[]}\n' > "$tmp"
    else
        jq --arg s "$scope" '.entries |= map(select(.scope != $s))' "$led" > "$tmp"
    fi
    mv "$tmp" "$led"

    log_step "reverted $count KDE config key(s)$([ "$scope" = "--all" ] || printf ' for %s' "$scope")"
}

# Kept for callers that mean "undo everything".
kconfig_revert_all() { kconfig_revert --all; }

kconfig_ledger_summary() {
    local led
    led=$(kconfig_ledger)
    [ -s "$led" ] || { echo "no ledger"; return 0; }
    local filter='.entries'
    [ $# -gt 0 ] && filter=$(printf '[.entries[] | select(.scope == "%s")]' "$1")
    jq -r "$filter"' | .[] | "  [\(.scope)] \(.file) [\(.group)] \(.key) (was: \(if .had then .value else "<unset>" end))"' "$led"
}

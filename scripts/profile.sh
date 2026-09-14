#!/usr/bin/env bash
# Configuration profiles.
#
#   list            what exists, and which is active
#   use <name>      switch to one
#   new <name>      create one from the current configuration
#   monitors        per-output overrides in the active profile
#
# A profile is a directory holding shell.json and any per-output overrides.
# Switching writes one small file naming the active profile, so it cannot
# damage the configuration it is switching away from.
set -uo pipefail

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
source "$REPO_ROOT/scripts/lib/log.sh"
source "$REPO_ROOT/scripts/lib/brand.sh"

state_file="$CONFIG_DIR/state.json"
profiles_dir="$CONFIG_DIR/profiles"

# active_profile() comes from lib/brand.sh, so every command agrees.

cmd=${1:-list}
[ $# -gt 0 ] && shift

case "$cmd" in
    list)
        active=$(active_profile)
        [ -d "$profiles_dir" ] || { log_info "no profiles yet"; exit 0; }
        for d in "$profiles_dir"/*/; do
            [ -d "$d" ] || continue
            name=$(basename "$d")
            mark=' '
            [ "$name" = "$active" ] && mark='*'
            monitors=$(ls -1 "$d/monitors" 2>/dev/null | wc -l)
            printf '%s %-16s %s override(s), %s monitor file(s)\n' \
                "$mark" "$name" \
                "$(jq '[paths(scalars)] | length' "$d/shell.json" 2>/dev/null || echo '?')" \
                "$monitors"
        done
        ;;

    use)
        name=${1:?usage: $ALIAS profile use <name>}
        [ -d "$profiles_dir/$name" ] || die "no profile called '$name' (create it with: $ALIAS profile new $name)"
        mkdir -p "$CONFIG_DIR"
        # Written whole, then moved into place. The shell watches this file,
        # and a redirect truncates before it writes: a read landing in that
        # window gets a parse error, and the shell answers it by staying on
        # whichever profile it already has -- which at startup is 'default'.
        # Switching profiles then looks like the configuration resetting
        # itself, with a JSON error the only trace.
        tmp_state=$(mktemp "$(dirname "$state_file")/.state.XXXXXX") || die "could not write $state_file"
        jq -n --arg p "$name" '{profile: $p}' > "$tmp_state" \
            || { rm -f "$tmp_state"; die "could not write $state_file"; }
        mv -f "$tmp_state" "$state_file" || { rm -f "$tmp_state"; die "could not write $state_file"; }
        log_step "active profile: $name"
        log_info "the shell switches immediately; no restart needed"
        ;;

    new)
        name=${1:?usage: $ALIAS profile new <name>}
        [ -d "$profiles_dir/$name" ] && die "profile '$name' already exists"
        src="$profiles_dir/$(active_profile)"
        mkdir -p "$profiles_dir/$name"
        # Copied from the current profile rather than started empty: a new
        # profile is nearly always a variation on the one in use.
        if [ -d "$src" ]; then
            cp -a "$src/." "$profiles_dir/$name/"
            log_info "copied from '$(active_profile)'"
        else
            printf '{\n    "schemaVersion": 1\n}\n' > "$profiles_dir/$name/shell.json"
        fi
        log_step "created profile '$name'"
        log_info "switch to it: $ALIAS profile use $name"
        ;;

    monitors)
        d="$profiles_dir/$(active_profile)/monitors"
        if [ -d "$d" ] && [ -n "$(ls -A "$d" 2>/dev/null)" ]; then
            for f in "$d"/*.json; do
                printf '%s\n' "$(basename "$f" .json)"
                jq -c . "$f" | sed 's/^/    /'
            done
        else
            log_info "no per-output overrides in profile '$(active_profile)'"
            log_info "create one at: $d/<OUTPUT>.json"
        fi
        ;;

    *) die "unknown command: $cmd (expected list, use, new or monitors)" ;;
esac

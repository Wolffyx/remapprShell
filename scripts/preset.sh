#!/usr/bin/env bash
# Layouts you can switch between.
#
#   list            what is available
#   show <name>     what applying it would set
#   apply <name>    replace the current profile with it
#
# A preset is an ordinary profile -- the same sparse delta a person would write
# by hand -- so nothing about them is special-cased in the shell, and a user can
# add one by dropping a file in the presets directory.
set -uo pipefail

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
source "$REPO_ROOT/scripts/lib/log.sh"
source "$REPO_ROOT/scripts/lib/brand.sh"
source "$REPO_ROOT/scripts/lib/profiles.sh"

# Shipped presets, plus any the user has added.
preset_dirs() {
    printf '%s\n' "$DATA_DIR/config/presets" "$CONFIG_DIR/presets"
}

find_preset() {
    local name=$1 dir
    while IFS= read -r dir; do
        [ -f "$dir/$name.json" ] && { printf '%s/%s.json' "$dir" "$name"; return 0; }
    done < <(preset_dirs)
    return 1
}

# profile_file() comes from lib/brand.sh: it follows the active profile.

cmd=${1:-list}
[ $# -gt 0 ] && shift

case "$cmd" in
    list)
        seen=""
        while IFS= read -r dir; do
            [ -d "$dir" ] || continue
            for f in "$dir"/*.json; do
                [ -e "$f" ] || continue
                id=$(basename "$f" .json)
                case " $seen " in *" $id "*) continue ;; esac
                seen="$seen $id"
                printf '%-14s %s\n' "$id" "$(jq -r '.description // ""' "$f")"
            done
        done < <(preset_dirs)
        [ -n "$seen" ] || log_info "no presets found"
        ;;

    show)
        name=${1:?usage: $ALIAS preset show <name>}
        f=$(find_preset "$name") || die "no preset called '$name'"
        jq '.config' "$f"
        ;;

    apply)
        name=${1:?usage: $ALIAS preset apply <name>}
        f=$(find_preset "$name") || die "no preset called '$name'"

        target=$(profile_file)
        mkdir -p "$(dirname "$target")"

        # The current profile is kept before it is replaced. This is the user's
        # own configuration, so trying a preset must not be a one-way door --
        # and a preset replaces rather than merges, because merging two layouts
        # produces a third that is neither. How it is kept, and why twice, is
        # in lib/profiles.sh; the wizard's Finish replaces the profile the same
        # way and keeps it with the same call.
        keep_profile "before-$name"

        schema=$(jq -r '.schemaVersion // 1' "$f" 2>/dev/null)
        jq --argjson v "${schema:-1}" '.config + {schemaVersion: $v}' "$f" > "$target"

        log_step "applied preset '$name' to profile '$(active_profile)'"
        log_info "the shell picks it up immediately; no restart needed"
        # Nothing is said on the very first apply: there was nothing to keep,
        # and offering a way back to it would be offering a way back to
        # nowhere.
        say_kept_profile
        ;;

    *) die "unknown command: $cmd (expected list, show or apply)" ;;
esac

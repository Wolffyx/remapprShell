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
        # produces a third that is neither.
        # The configuration being replaced is kept twice, in two places, on
        # purpose.
        #
        # The copy under the state directory is the old one and it is not
        # enough: the state directory is what a restore point rolls back, so a
        # rollback takes the backups along with the thing they were protecting.
        # Someone who lost a layout that way is told there are restore points
        # and finds none of them has it.
        #
        # So the real copy is a profile, beside the one being replaced, in the
        # configuration directory. A profile outlives a state rollback, is
        # listed by `profile list` and by the settings window, and is switched
        # back to with one command rather than a path someone has to have kept.
        saved=""
        backup=""
        if [ -f "$target" ] && [ -s "$target" ]; then
            backup="$STATE_DIR/profile-backups/$(date +%Y%m%d-%H%M%S)-before-$name.json"
            mkdir -p "$(dirname "$backup")"
            cp -a "$target" "$backup"

            # Named for what it is rather than for when it was taken, with the
            # time added only when that name is already in use -- somebody
            # trying three layouts should end up with one "before-meridian",
            # not three timestamps to tell apart.
            saved="before-$name"
            if [ -e "$CONFIG_DIR/profiles/$saved" ]; then
                saved="before-$name-$(date +%H%M%S)"
            fi
            mkdir -p "$CONFIG_DIR/profiles/$saved"
            cp -a "$target" "$CONFIG_DIR/profiles/$saved/shell.json"
            # Per-output overrides belong to the configuration too.
            [ -d "$(dirname "$target")/monitors" ] \
                && cp -a "$(dirname "$target")/monitors" "$CONFIG_DIR/profiles/$saved/" 2>/dev/null
        fi

        schema=$(jq -r '.schemaVersion // 1' "$f" 2>/dev/null)
        jq --argjson v "${schema:-1}" '.config + {schemaVersion: $v}' "$f" > "$target"

        log_step "applied preset '$name' to profile '$(active_profile)'"
        log_info "the shell picks it up immediately; no restart needed"
        # There is nothing to undo to on the very first apply, and naming an
        # unset variable under `set -u` ended the command with an error after
        # the preset had already been written.
        if [ -n "$saved" ]; then
            log_info "what was there is now the profile '$saved'"
            log_info "go back with: $ALIAS profile use $saved"
        fi
        [ -n "$backup" ] && log_info "and a copy is at $backup"
        ;;

    *) die "unknown command: $cmd (expected list, show or apply)" ;;
esac

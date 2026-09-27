#!/usr/bin/env bash
# Configuration profiles.
#
#   list            what exists, and which is active
#   use <name>      switch to one
#   new <name>      create one from the current configuration
#   keep <label>    copy the active profile aside before something replaces it
#   monitors        per-output overrides in the active profile
#
# A profile is a directory holding shell.json and any per-output overrides.
# Switching writes one small file naming the active profile, so it cannot
# damage the configuration it is switching away from.
set -uo pipefail

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
source "$REPO_ROOT/scripts/lib/log.sh"
source "$REPO_ROOT/scripts/lib/brand.sh"
source "$REPO_ROOT/scripts/lib/profiles.sh"

state_file="$CONFIG_DIR/state.json"
profiles_dir="$CONFIG_DIR/profiles"

# active_profile() comes from lib/brand.sh, so every command agrees.

# How many overrides each profile directory's shell.json holds, into
# OVERRIDES in the same order: a count, "?" for a file that is missing or does
# not parse, and nothing for one with no value in it at all.
#
# One jq for every profile, where it was one a profile. Each file goes in whole
# and is parsed on its own inside, so one that does not parse is a "?" for that
# profile alone: jq reading them as one stream stops at the first bad one, and
# reading them as lines runs the end of a file with no last newline into the
# start of the next.
OVERRIDES=()
override_counts() {   # <profile dir>...
    local i=0 d
    local -a args=()
    OVERRIDES=()
    [ $# -gt 0 ] || return 0
    for d in "$@"; do
        [ -f "$d/shell.json" ] && [ -r "$d/shell.json" ] && args+=(--rawfile "p$i" "$d/shell.json")
        i=$((i + 1))
    done
    mapfile -d '' -t OVERRIDES < <(jq -n --raw-output0 --argjson n $# "${args[@]}" '
        range($n) as $i | $ARGS.named["p\($i)"]
        | if . == null then "?"
          elif test("\\A[ \t\r\n]*\\z") then ""
          else try (fromjson | [paths(scalars)] | length | tostring) catch "?" end' 2>/dev/null)
}

cmd=${1:-list}
[ $# -gt 0 ] && shift

case "$cmd" in
    list)
        active=$(active_profile)
        [ -d "$profiles_dir" ] || { log_info "no profiles yet"; exit 0; }
        # The monitor files are counted by a glob, which skips the hidden ones
        # `ls` skipped and starts nothing -- with nullglob, so none counts 0.
        shopt -s nullglob
        dirs=()
        for d in "$profiles_dir"/*/; do
            [ -d "$d" ] && dirs+=("$d")
        done
        override_counts "${dirs[@]}"
        for i in "${!dirs[@]}"; do
            d=${dirs[$i]}
            name=${d%/}; name=${name##*/}
            mark=' '
            [ "$name" = "$active" ] && mark='*'
            monitors=("$d"monitors/*)
            printf '%s %-16s %s override(s), %s monitor file(s)\n' \
                "$mark" "$name" "${OVERRIDES[$i]-?}" "${#monitors[@]}"
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

    keep)
        # For anything that is about to replace the profile rather than edit
        # it. `new` refuses a name already taken, which is right when somebody
        # is naming a profile and wrong here: this is a safety net, and a net
        # that declines to catch you the second time is not one. The rules are
        # in lib/profiles.sh, shared with `preset apply`.
        #
        # Prints the name it saved, and nothing when there was nothing worth
        # saving -- so a caller can pass it on without deciding what "nothing"
        # looks like.
        label=${1:-before-change}
        case "$label" in
            *[!A-Za-z0-9._-]*) die "a label may hold letters, digits, dot, dash and underscore only" ;;
        esac
        keep_profile "$label"
        if [ -z "$KEPT_PROFILE" ]; then
            log_info "nothing to keep: profile '$(active_profile)' is empty or does not exist yet"
            exit 0
        fi
        printf '%s\n' "$KEPT_PROFILE"
        say_kept_profile
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

    *) die "unknown command: $cmd (expected list, use, new, keep or monitors)" ;;
esac

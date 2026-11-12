#!/usr/bin/env bash
# Layouts you can switch between.
#
#   list [--json]          what is available, and which one is in use
#   show <name>            what applying it would set
#   apply <name>           replace the current profile with it
#   save <name> [about]    keep the current configuration as a layout of your own
#   delete <name>          remove a layout of your own
#
# A preset is an ordinary profile -- the same sparse delta a person would write
# by hand -- so nothing about them is special-cased in the shell, and a user can
# add one by dropping a file in the presets directory. `save` is that, done for
# them: the active profile, written into their presets directory.
#
# Applying a layout replaces the profile. When the profile is a layout of the
# person's own that is in no list yet -- they changed things after the last
# layout, or never applied one -- it is saved to the list first, so the layout
# they built is one click away rather than a backup to go looking for.
set -uo pipefail

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
source "$REPO_ROOT/scripts/lib/log.sh"
source "$REPO_ROOT/scripts/lib/brand.sh"
source "$REPO_ROOT/scripts/lib/profiles.sh"
# The title-bar buttons' part of a layout: what is carried across one, and
# kept from before one. Its KDE half is windows.sh's, run after an apply.
source "$REPO_ROOT/scripts/lib/windows/titlebar.sh"

# Dates in what is written are in English, as the rest of the words are,
# whatever the machine's locale: "11 Nov", never "11 nov" or "11 нояб".
stamp() { LC_ALL=C date "+$1"; }

# Where layouts of the person's own live. Shipped ones are under DATA_DIR.
user_presets="$CONFIG_DIR/presets"

# Shipped presets, plus any the user has added.
preset_dirs() {
    printf '%s\n' "$DATA_DIR/config/presets" "$user_presets"
}

find_preset() {
    local name=$1 dir
    while IFS= read -r dir; do
        [ -f "$dir/$name.json" ] && { printf '%s/%s.json' "$dir" "$name"; return 0; }
    done < <(preset_dirs)
    return 1
}

# Every preset file, one a line, the first of each name only: a shipped
# layout wins over one of the user's with the same name, as find_preset
# decides.
preset_files() {
    local seen=" " dir f id
    # lint-nesting: allow -- each preset directory, then each preset in it
    while IFS= read -r dir; do
        for f in "$dir"/*.json; do
            [ -e "$f" ] || continue
            id=$(basename "$f" .json)
            case "$seen" in *" $id "*) continue ;; esac
            seen="$seen$id "
            printf '%s\n' "$f"
        done
    done < <(preset_dirs)
}

# The active profile as a layout is compared: compact JSON without the
# version stamp the shell writes itself, nor the switch that says whether a
# layout may change the title-bar buttons -- that is the person's, never a
# layout's. "{}" for the defaults -- no profile, an empty one, one with
# nothing but the stamp -- and nothing at all for a profile that does not
# parse.
current_config() {
    local target
    target=$(profile_file)
    [ -f "$target" ] && grep -q '[^[:space:]]' "$target" 2>/dev/null || { echo '{}'; return 0; }
    jq -c "$TITLEBAR_JQ_DEFS"'del(.schemaVersion) | unswitched' "$target" 2>/dev/null
}

# Everything known about the layouts, as one JSON object, from one jq over
# every file -- not a jq a layout:
#
#   { state: "defaults" | "saved" | "custom" | "unreadable",
#     current: <id of the layout in use, or "">,
#     layouts: [{ id, name, description, custom, current }] }
#
# "saved" is a profile that is exactly some layout; "custom" one that is
# changed from the defaults and is no layout in the list. The title-bar
# buttons are carried across a layout that does not set them, so they are
# left out of the comparison with one -- and with layouts not allowed to
# change them, out of every comparison, on both sides. A profile that changes
# nothing else is the defaults: there is no layout in it to save.
layouts_json() {
    local cur fixed
    local -a files=()
    cur=$(current_config)
    [ -n "$cur" ] || cur=null
    fixed=$(jq '.windows.titleButtonsFromLayouts == false' "$(profile_file)" 2>/dev/null) || fixed=false
    [ "$fixed" = true ] || fixed=false
    mapfile -t files < <(preset_files)
    # With no files, /dev/null: `jq -n` given no file reads its input from
    # the terminal, and would wait there.
    jq -n --argjson cur "$cur" --argjson fixed "$fixed" --arg mine "$user_presets/" "$TITLEBAR_JQ_DEFS"'
        [inputs | ((.config // {}) | del(.schemaVersion) | if $fixed then bare({}) else . end) as $conf | {
            id: (input_filename | split("/") | last | rtrimstr(".json")),
            name: (.name // ""),
            description: (.description // ""),
            custom: (input_filename | startswith($mine)),
            current: ($cur != null and ($cur | bare({})) != {} and $conf == ($cur | bare($conf)))
        }] as $all
        | ([$all[] | select(.current) | .id] | first // "") as $in
        | { layouts: $all, current: $in,
            state: (if $cur == null then "unreadable" elif ($cur | bare({})) == {} then "defaults"
                    elif $in != "" then "saved" else "custom" end) }' "${files[@]:-/dev/null}" 2>/dev/null \
        || jq -n --argjson cur "$cur" "$TITLEBAR_JQ_DEFS"'{ layouts: [], current: "",
            state: (if $cur == null then "unreadable" elif ($cur | bare({})) == {} then "defaults" else "custom" end) }'
}

# "My Layout, Nov 11" -> "my-layout-nov-11". Lower case letters, digits and
# single hyphens: a name that is safe as a file name on its own, with no
# path in it.
slug() {
    printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g; s/^-+//' | cut -c1-40 | sed -E 's/-+$//'
}

# `id`, or `id-2`, `id-3`... -- whichever is not a layout yet, shipped or not.
free_id() {
    local base=$1 id=$1 n=2
    while find_preset "$id" >/dev/null; do
        id="$base-$n"
        n=$((n + 1))
    done
    printf '%s' "$id"
}

# Writes the active profile as a layout of the person's own and prints its id.
# Refuses the defaults (there is nothing to keep), a profile that does not
# parse, and a configuration that is already a layout (it is in the list
# already, under that name).
save_layout() {
    local name description id target version tmp cur state
    name=$(printf '%s' "${1:-}" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//')
    description=${2:-"Saved $(stamp '%-d %b %Y, %H:%M')"}
    [ -n "$name" ] || die "a layout needs a name"
    [ "${#name}" -le 40 ] || die "a layout's name is at most 40 characters"

    state=$(layouts_json)
    case "$(jq -r '.state' <<<"$state")" in
        defaults)   die "the configuration is the defaults; there is nothing to save as a layout" ;;
        unreadable) die "the active profile does not parse; fix it before saving it as a layout" ;;
        saved)      die "this configuration is already the layout '$(jq -r '.current' <<<"$state")'" ;;
    esac

    cur=$(current_config)
    target=$(profile_file)
    version=$(jq -r '.schemaVersion // 1' "$target" 2>/dev/null)
    id=$(slug "$name")
    id=$(free_id "${id:-layout}")

    mkdir -p "$user_presets" || die "could not create $user_presets"
    tmp=$(mktemp "$user_presets/.layout.XXXXXX") || die "could not write in $user_presets"
    jq -n --arg name "$name" --arg description "$description" --argjson v "${version:-1}" \
          --argjson config "$cur" \
          '{ name: $name, description: $description, schemaVersion: $v, config: $config }' > "$tmp" \
        || { rm -f "$tmp"; die "could not write the layout"; }
    mv -f "$tmp" "$user_presets/$id.json" || { rm -f "$tmp"; die "could not write $user_presets/$id.json"; }
    printf '%s' "$id"
}

# Before a layout replaces the profile: a profile that is the person's own
# layout and in no list yet goes into the list. Anything else -- the
# defaults, a profile that is already a layout, one that does not parse -- is
# left to keep_profile, which keeps every profile anyway.
save_before_apply() {
    local applying=$1 id
    [ "$(layouts_json | jq -r '.state')" = "custom" ] || return 0
    id=$(save_layout "My layout, $(stamp '%-d %b %H:%M')" \
                     "Saved by itself before $applying replaced it, $(stamp '%-d %b %Y, %H:%M')") || return 0
    log_step "your layout was saved to the list first, as '$id'"
}

# profile_file() comes from lib/brand.sh: it follows the active profile.

cmd=${1:-list}
[ $# -gt 0 ] && shift

case "$cmd" in
    list)
        if [ "${1:-}" = "--json" ]; then
            layouts_json
            exit 0
        fi
        mapfile -t files < <(preset_files)
        [ "${#files[@]}" -gt 0 ] || { log_info "no presets found"; exit 0; }
        # One jq for every file: its name and what it says it is.
        jq -r '[(input_filename | split("/") | last | rtrimstr(".json")), (.description // "")] | @tsv' \
            "${files[@]}" 2>/dev/null \
            | while IFS=$'\t' read -r id about; do printf '%-14s %s\n' "$id" "$about"; done
        ;;

    show)
        name=${1:?usage: $ALIAS preset show <name>}
        f=$(find_preset "$name") || die "no preset called '$name'"
        jq '.config' "$f"
        ;;

    save)
        name=${1:?usage: $ALIAS preset save <name> [description]}
        id=$(save_layout "$name" "${2:-}") || exit 1
        log_step "saved the current configuration as the layout '$id'"
        log_info "apply it again with: $ALIAS preset apply $id"
        ;;

    delete)
        name=${1:?usage: $ALIAS preset delete <name>}
        # A name, never a path: it is joined onto a directory below.
        [[ "$name" =~ ^[a-z0-9][a-z0-9-]*$ ]] || die "no layout of yours is called '$name'"
        [ -f "$user_presets/$name.json" ] || die "no layout of yours is called '$name' -- shipped layouts cannot be deleted"
        rm -f "$user_presets/$name.json" || die "could not remove $user_presets/$name.json"
        log_step "deleted the layout '$name'"
        ;;

    apply)
        name=${1:?usage: $ALIAS preset apply <name>}
        f=$(find_preset "$name") || die "no preset called '$name'"

        target=$(profile_file)
        mkdir -p "$(dirname "$target")"

        # A layout of the person's own that is in no list yet goes into it
        # before anything replaces it. See save_before_apply.
        save_before_apply "$(jq -r --arg id "$name" '.name // $id' "$f" 2>/dev/null || printf '%s' "$name")"

        # The current profile is kept before it is replaced. This is the user's
        # own configuration, so trying a preset must not be a one-way door --
        # and a preset replaces rather than merges, because merging two layouts
        # produces a third that is neither. How it is kept, and why twice, is
        # in lib/profiles.sh; the wizard's Finish replaces the profile the same
        # way and keeps it with the same call.
        keep_profile "before-$name"

        # Written whole beside the profile, then renamed over it. The shell
        # watches this file, and a redirect onto it truncates before it writes:
        # a read in that window is a parse error, which the shell answers by
        # keeping the configuration it already had -- the preset would seem
        # not to apply. lib/config.sh writes a single setting the same way.
        #
        # The title-bar buttons are decided first: a layout may set them, and
        # the next one puts back what was there -- or none may, as the person
        # chose. See titlebar_layout_carry.
        schema=$(jq -r '.schemaVersion // 1' "$f" 2>/dev/null)
        laid=$(titlebar_layout_carry "$(jq -c '.config // {}' "$f" 2>/dev/null)") \
            || die "could not read the preset $f"
        tmp=$(mktemp "$(dirname "$target")/.shell.json.XXXXXX") || die "could not write $target"
        jq --argjson v "${schema:-1}" '.config + {schemaVersion: $v}' <<<"$laid" > "$tmp" \
            || { rm -f "$tmp"; die "could not read the preset $f"; }
        mv -f "$tmp" "$target" || { rm -f "$tmp"; die "could not write $target"; }
        titlebar_stash_save "$(jq -c '.stash' <<<"$laid")"

        # KWin's title bars follow the profile now, in windows.sh, which
        # writes kwinrc through the ledger. A layout is the shell's
        # configuration first: one KWin could not be told about is still
        # applied, and says so.
        "$REPO_ROOT/scripts/windows.sh" titlebar apply \
            || log_warn "the title-bar buttons could not be set; $ALIAS windows titlebar status says why"

        log_step "applied preset '$name' to profile '$(active_profile)'"
        log_info "the shell picks it up immediately; no restart needed"
        # Nothing is said on the very first apply: there was nothing to keep,
        # and offering a way back to it would be offering a way back to
        # nowhere.
        say_kept_profile
        ;;

    *) die "unknown command: $cmd (expected list, show, apply, save or delete)" ;;
esac

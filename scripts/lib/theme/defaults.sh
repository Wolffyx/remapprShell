# shellcheck shell=bash
# The package's `defaults` file, written through the ledger, and which parts
# of the desktop the settings let it write.
#
# Sourced by theme.sh, never executed. Requires log.sh, kconfig.sh and
# config.sh -- and install.sh, for where the packages are.

# Which parts would be written, and which are left alone -- for `status` and
# for saying out loud what an apply did.
DESKTOP_PARTS=(colours icons style plasmaTheme decorations switcher gtk)

# Is this part of the desktop ours to theme? `theme.desktop.enabled` is the
# whole question and each part is a second one, so turning the lot off is one
# setting and leaving out just the colour scheme is another. Anything left out
# keeps whatever the user chose in System Settings.
desktop_part_wanted() {
    [ "$(desktop_parts_wanted "$1")" = "$1"$'\t'true ]
}

# desktop_parts_wanted [part...]   -- "<part>\t<true|false>" for each part,
# every one of them when none is named, from one jq.
#
# It was two config_get a part, and so fourteen jq runs for `status` to say
# what an apply would write. Each setting is read as config_get reads it --
# absent, empty or unreadable is the default, true, and anything but "true"
# is off -- so the answer is the one those fourteen gave.
desktop_parts_wanted() {
    [ $# -gt 0 ] || set -- "${DESKTOP_PARTS[@]}"
    config_merged | jq -R -s -r '
        # What config_get reads, as text, less the newlines its command
        # substitution takes off the end -- and "" where it falls back.
        def text(p): (try p catch null) as $v
            | if $v == null then ""
              else $v | if type == "array" or type == "object" then tojson else tostring end end
            | sub("\n+\\z"; "");
        def on(p): text(p) | . == "true" or . == "";
        (try fromjson catch null) as $c
        | ($c | on(.theme.desktop.enabled)) as $all
        | $ARGS.positional[] as $part
        | "\($part)\t\($all and ($c | on(.theme.desktop[$part])))"' --args "$@"
}

# Whether the lines under a `# part:` marker are written, saying so when they
# are not.
_defaults_part_on() {   # <part>
    desktop_part_wanted "$1" && return 0
    log_info "leaving $1 alone (theme.desktop.$1 is off)"
    return 1
}

# A group header, [file][Group] or [file][A][B], into DEFAULTS_FILE and
# DEFAULTS_GROUP -- "A/B" for the nested one, as kconfig_set takes it.
#
# In the shell, where it was sed, head, tail and paste for every header. Empty
# groups at the end are dropped, as they were when the lines they became were
# read into a variable.
_defaults_header() {   # <line>
    local inner=${1#\[}
    inner=${inner%\]}
    while [[ $inner == *'][' ]]; do
        inner=${inner%']['}
    done
    DEFAULTS_FILE=${inner%%']['*}
    DEFAULTS_GROUP=""
    [[ $inner == *']['* ]] || return 0
    DEFAULTS_GROUP=${inner#*']['}
    DEFAULTS_GROUP=${DEFAULTS_GROUP//']['//}
}

# apply_defaults [variant] [variant-only]
#
# Reads contents/defaults and writes each key through the ledger.
#
# The file's group syntax is [file][Group], and a nested group appears as
# [file][A][B] -- which kwriteconfig6 expresses as repeated --group arguments,
# so it is passed through as "A/B".
#
# `variant` is light or dark: the lines under the other one's `# variant:`
# marker are not written at all. `variant-only` writes nothing else, which is
# what `variant` uses to follow day and night without rewriting the whole
# desktop -- the style, the Plasma theme, the decorations and Alt+Tab do not
# change between light and dark, and rewriting them would churn the ledger.
apply_defaults() {
    local want=${1:-dark} variant_only=${2:-0}
    local defaults
    defaults="$(lnf_dest_for "$want")/contents/defaults"
    [ -f "$defaults" ] || { log_error "no defaults file at $defaults"; return 1; }

    local file="" group="" line key value part="" wanted=1 variant="any"
    while IFS= read -r line; do
        line=${line%%$'\r'}
        [ -n "$line" ] || continue

        # `# part: <id>` governs the lines beneath it, up to the next marker.
        # Any other comment is only a comment.
        case "$line" in
            '# variant: '*)
                variant=${line#\# variant: }
                continue
                ;;
            '# part: '*)
                part=${line#\# part: }
                variant="any"
                wanted=0
                _defaults_part_on "$part" && wanted=1
                continue
                ;;
            '#'*)
                continue
                ;;
        esac

        [ "$wanted" = 1 ] || continue

        # The variant being applied, and -- for a variant-only pass -- nothing
        # that belongs to neither. The group headers are skipped with the keys
        # beneath them, because each variant's block carries its own.
        if [ "$variant" = "any" ]; then
            [ "$variant_only" = 0 ] || continue
        else
            [ "$variant" = "$want" ] || continue
        fi

        if [[ "$line" =~ ^\[ ]]; then
            # [file][Group] or [file][A][B]
            _defaults_header "$line"
            file=$DEFAULTS_FILE
            group=$DEFAULTS_GROUP
            continue
        fi

        [ -n "$file" ] || continue
        key=${line%%=*}
        value=${line#*=}
        kconfig_set theme "$file" "$group" "$key" "$value"
    done < "$defaults"
}

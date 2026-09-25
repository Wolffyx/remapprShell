# shellcheck shell=bash
# The package's `defaults` file, written through the ledger, and which parts
# of the desktop the settings let it write.
#
# Sourced by theme.sh, never executed. Requires log.sh, kconfig.sh and
# config.sh -- and install.sh, for where the packages are.

# Is this part of the desktop ours to theme? `theme.desktop.enabled` is the
# whole question and each part is a second one, so turning the lot off is one
# setting and leaving out just the colour scheme is another. Anything left out
# keeps whatever the user chose in System Settings.
desktop_part_wanted() {
    local part=$1
    [ "$(config_get ".theme.desktop.enabled" true)" = "true" ] || return 1
    [ "$(config_get ".theme.desktop.$part" true)" = "true" ]
}

# Which parts would be written, and which are left alone -- for `status` and
# for saying out loud what an apply did.
desktop_parts() { printf '%s\n' colours icons style plasmaTheme decorations switcher gtk; }

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
        case "$line" in
            '#'*)
                case "$line" in
                    '# variant: '*)
                        variant=${line#\# variant: }
                        ;;
                    '# part: '*)
                        part=${line#\# part: }
                        variant="any"
                        if desktop_part_wanted "$part"; then
                            wanted=1
                        else
                            wanted=0
                            log_info "leaving $part alone (theme.desktop.$part is off)"
                        fi
                        ;;
                esac
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
            local parts
            parts=$(printf '%s' "$line" | sed 's/^\[//; s/\]$//; s/\]\[/\n/g')
            file=$(printf '%s' "$parts" | head -1)
            group=$(printf '%s' "$parts" | tail -n +2 | paste -sd'/' -)
            continue
        fi

        [ -n "$file" ] || continue
        key=${line%%=*}
        value=${line#*=}
        kconfig_set theme "$file" "$group" "$key" "$value"
    done < "$defaults"
}

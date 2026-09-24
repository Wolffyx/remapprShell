#!/usr/bin/env bash
# Generates docs/config.md from the schema, the defaults and the widget index.
#
# Written rather than hand-maintained because a configuration reference that is
# updated by hand is a reference that is wrong: the schema gains a key, the
# document does not, and the first person to trust it loses an afternoon.
# scripts/lint-docs.sh fails the build when this output and the committed file
# disagree, which is what keeps that from happening quietly.
#
# The document is committed rather than generated on demand: it is prose people
# read on the forge, where nothing runs.
set -euo pipefail

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
source "$REPO_ROOT/scripts/lib/log.sh"
source "$REPO_ROOT/scripts/lib/brand.sh"

SCHEMA="$REPO_ROOT/config/schema/shell.json"
DEFAULTS="$REPO_ROOT/config/defaults/shell.json"
INDEX="$REPO_ROOT/shell/widgets/index.json"
OUT=${1:-$REPO_ROOT/docs/config.md}

[ -f "$INDEX" ] || "$REPO_ROOT/scripts/gen-widget-index.sh" >/dev/null

# One row per key, from its schema entry -- by one jq for the whole table. It
# was five a key, which on every `make lint` (lint-docs regenerates this) came
# to several hundred.
#
# What a key accepts is said the way a person would: the values of an enum, a
# number's range, and for a fixed set its members -- they are the whole of
# what may be in the list, so the reference names them rather than saying "a
# list" and stopping. Markdown tables end a cell at a pipe, so a pipe in a
# description is escaped: one left in would silently shift every column after
# it.
key_table() {
    local keys=$1
    printf '| Setting | Accepts | Default | Meaning |\n'
    printf '| --- | --- | --- | --- |\n'
    jq -r '
        def cell: tostring | sub("\n+\\z"; "");
        def num: if . == null or . == false then "" else cell end;
        to_entries[] | .key as $name | .value as $spec
        | ($spec.type // "string" | cell) as $type
        | (if $type == "enum" or $type == "set" then [$spec.values[] | "`\(.)`"] | join(", ")
           elif $type == "int" or $type == "number" then
               ($spec.min | num) as $min | ($spec.max | num) as $max
               | if $min != "" and $max != "" then "a number, \($min) to \($max)" else "a number" end
           elif $type == "bool" then "`true` or `false`"
           elif $type == "list" then "a list"
           else "text" end) as $accepts
        | (if $spec | has("default") then ($spec.default | cell) else "--" end) as $default
        | ($spec.description // $spec.label // "" | cell | gsub("\\|"; "\\|")) as $meaning
        | "| `\($name)` | \($accepts) | `\($default)` | \($meaning) |"' <<< "$keys"
}

{
    printf '# Configuration reference\n\n'
    printf 'GENERATED FILE -- do not edit. Regenerate with `make docs`.\n'
    printf 'Source: `config/schema/shell.json`, `config/defaults/shell.json` and each widget'\''s `widget.json`.\n\n'

    printf '## Where it lives\n\n'
    printf '| Path | What it holds |\n| --- | --- |\n'
    printf '| `~/.config/%s/profiles/<profile>/shell.json` | your settings |\n' "$SLUG"
    printf '| `~/.config/%s/profiles/<profile>/monitors/<output>.json` | overrides for one screen |\n' "$SLUG"
    printf '| `~/.config/%s/state.json` | which profile is active |\n' "$SLUG"
    printf '| `~/.local/share/%s/config/defaults/shell.json` | the shipped defaults, read-only |\n' "$SLUG"
    printf '| `~/.local/state/%s/` | ledgers, restore points, reports |\n\n' "$SLUG"

    printf '## How the layers combine\n\n'
    printf 'Four layers, each overriding the one before:\n\n'
    printf '1. **defaults** -- shipped, complete, never written to\n'
    printf '2. **profile** -- your file, a *sparse* delta against the defaults\n'
    printf '3. **monitor** -- a delta on top of that, for one output\n'
    printf '4. **runtime** -- in memory only, never saved\n\n'
    printf 'Your profile holds only what you actually changed. That is deliberate: it means\n'
    printf 'upgrading the defaults moves everything you never touched, and a setting you did\n'
    printf 'not choose does not get frozen at the value it happened to have on the day you\n'
    printf 'installed. Edits are picked up live -- no restart.\n\n'
    printf 'A profile that does not parse blocks writes rather than being overwritten, so a\n'
    printf 'typo cannot cost you the rest of the file.\n\n'

    printf '## Settings\n\n'
    while IFS= read -r section; do
        printf '### %s\n\n' "$(jq -r '.label // .id' <<< "$section")"
        desc=$(jq -r '.description // ""' <<< "$section")
        [ -n "$desc" ] && printf '%s\n\n' "$desc"

        keys=$(jq -c '.keys // {}' <<< "$section")
        if [ "$(jq -r 'length' <<< "$keys")" -gt 0 ]; then
            key_table "$keys"
            printf '\n'
        else
            printf 'No individual settings: this is a page in the settings window rather than a\n'
            printf 'list of values.\n\n'
        fi
    done < <(jq -c '.sections[]' "$SCHEMA")

    printf '## The panel contents\n\n'
    printf '`bar.entries` is an ordered list. Order matters *within* a zone, and every entry\n'
    printf 'needs a `zone` -- an entry without one is reported and skipped rather than\n'
    printf 'silently landing on the left.\n\n'
    printf '```json\n'
    jq '{bar: {entries: .bar.entries}}' "$DEFAULTS"
    printf '```\n\n'

    printf '## Widgets\n\n'
    printf 'Each has its own settings, written under `widgets.<id>`, or inline on one entry\n'
    printf 'when two copies of a widget should differ.\n\n'
    printf '| Widget | id | Zones | Plasma renderer |\n| --- | --- | --- | --- |\n'
    jq -r '.widgets[] |
        "| \(.name) | `\(.id)` | \(.zones | join(", ")) | \(if .renderers.plasma.applet then "`" + .renderers.plasma.applet + "`" + (if .renderers.plasma.inSystemTray then " (in the tray)" else "" end) else "**not supported**" end) |"' "$INDEX"
    printf '\n'
    printf 'A widget with no Plasma applet is left out of the panel under the `plasma`\n'
    printf 'renderer, and is named before you switch rather than discovered afterwards.\n\n'
    printf 'One marked *in the tray* is an applet Plasma'"'"'s system tray hosts by itself.\n'
    printf 'With `tray` also on the panel it is left to the tray rather than drawn twice;\n'
    printf 'without `tray` it stands on the panel alone.\n\n'

    while IFS= read -r widget; do
        id=$(jq -r '.id' <<< "$widget")
        keys=$(jq -c '.config // {}' <<< "$widget")
        [ "$(jq -r 'length' <<< "$keys")" -gt 0 ] || continue
        printf '### `widgets.%s`\n\n' "$id"
        key_table "$keys"
        printf '\n'
    done < <(jq -c '.widgets[]' "$INDEX")

    printf '## A complete example\n\n'
    printf 'Everything below is optional; anything left out comes from the defaults.\n\n'
    printf '```json\n'
    cat <<'EXAMPLE'
{
    "panel": { "position": "top", "thickness": 32 },
    "bar": {
        "entries": [
            { "id": "launcher", "zone": "left" },
            { "id": "clock", "zone": "middle" },
            { "id": "tray", "zone": "right" }
        ]
    },
    "widgets": {
        "clock": { "format": "HH:mm", "showDate": true }
    }
}
EXAMPLE
    printf '```\n'
} > "$OUT"

log_step "wrote $OUT ($(wc -l < "$OUT") lines)"

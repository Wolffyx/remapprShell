#!/usr/bin/env bash
# Generates the Plasma colour schemes from theme/colors/palette.json.
#
# A colour scheme is what themes *everything Plasma draws* -- notifications,
# every applet, every dialogue -- consistently with our panel, without owning
# any of them. It is the single highest-leverage file in the theme layer, and
# the reason the shell reads KDE's colours rather than defining its own.
#
# Generated rather than hand-written because the format repeats the same
# handful of colours across thirteen groups. By hand, two groups drift apart
# within a release and the result is one dialogue that looks subtly wrong for
# reasons nobody can find.
set -euo pipefail

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
source "$REPO_ROOT/scripts/lib/log.sh"
source "$REPO_ROOT/scripts/lib/brand.sh"

PALETTE="$REPO_ROOT/theme/colors/palette.json"
[ -f "$PALETTE" ] || die "no palette at $PALETTE"

# scheme_name <variant>  -- what System Settings shows, and what `defaults` names.
scheme_name() { printf '%s %s' "$DISPLAY_NAME" "$(tr '[:lower:]' '[:upper:]' <<< "${1:0:1}")${1:1}"; }
scheme_file() { printf '%s/%s-%s.colors' "$REPO_ROOT/theme/colors" "$SLUG" "$1"; }

generate() {
    local variant=$1
    local out
    out=$(scheme_file "$variant")

    local -A c
    while IFS=$'\t' read -r key value; do
        c[$key]=$value
    done < <(jq -r --arg v "$variant" '.[$v] | to_entries[] | [.key, .value] | @tsv' "$PALETTE")

    # Every colour group takes the same twelve foreground roles. They are
    # emitted from one function so a group cannot quietly disagree with the
    # others about what "negative" means.
    _roles() {
        printf 'ForegroundNormal=%s\n'   "${c[foreground]}"
        printf 'ForegroundInactive=%s\n' "${c[foregroundInactive]}"
        printf 'ForegroundActive=%s\n'   "${c[accent]}"
        printf 'ForegroundLink=%s\n'     "${c[link]}"
        printf 'ForegroundVisited=%s\n'  "${c[visited]}"
        printf 'ForegroundNegative=%s\n' "${c[negative]}"
        printf 'ForegroundNeutral=%s\n'  "${c[neutral]}"
        printf 'ForegroundPositive=%s\n' "${c[positive]}"
        printf 'DecorationFocus=%s\n'    "${c[accent]}"
        printf 'DecorationHover=%s\n'    "${c[accent]}"
    }

    _group() {
        local name=$1 bg=$2 alt=$3
        printf '\n[Colors:%s]\n' "$name"
        printf 'BackgroundNormal=%s\n'    "$bg"
        printf 'BackgroundAlternate=%s\n' "$alt"
        _roles
    }

    {
        printf '# GENERATED FILE -- DO NOT EDIT. Regenerate: scripts/gen-colors.sh\n'
        printf '# Source: theme/colors/palette.json\n'
        printf '# SPDX-License-Identifier: GPL-3.0-or-later\n'

        printf '\n[General]\n'
        printf 'ColorScheme=%s\n' "$(scheme_name "$variant")"
        printf 'Name=%s\n'        "$(scheme_name "$variant")"
        printf 'shadeSortColumn=true\n'

        printf '\n[KDE]\n'
        printf 'contrast=4\n'

        _group Window      "${c[windowBackground]}"  "${c[windowAlternate]}"
        _group View        "${c[viewBackground]}"    "${c[viewAlternate]}"
        _group Button      "${c[buttonBackground]}"  "${c[buttonAlternate]}"
        _group Tooltip     "${c[tooltipBackground]}" "${c[buttonAlternate]}"
        _group Complementary "${c[windowAlternate]}" "${c[windowBackground]}"
        _group Header      "${c[windowAlternate]}"   "${c[windowBackground]}"

        # Selection is the one group whose foreground is not the normal one:
        # text sits on the accent, so it takes the colour chosen to be legible
        # against it rather than against the window.
        printf '\n[Colors:Selection]\n'
        printf 'BackgroundNormal=%s\n'    "${c[accent]}"
        printf 'BackgroundAlternate=%s\n' "${c[accent]}"
        printf 'ForegroundNormal=%s\n'    "${c[accentText]}"
        printf 'ForegroundInactive=%s\n'  "${c[accentText]}"
        printf 'ForegroundActive=%s\n'    "${c[accentText]}"
        printf 'ForegroundLink=%s\n'      "${c[accentText]}"
        printf 'ForegroundVisited=%s\n'   "${c[accentText]}"
        printf 'ForegroundNegative=%s\n'  "${c[negative]}"
        printf 'ForegroundNeutral=%s\n'   "${c[neutral]}"
        printf 'ForegroundPositive=%s\n'  "${c[positive]}"
        printf 'DecorationFocus=%s\n'     "${c[accent]}"
        printf 'DecorationHover=%s\n'     "${c[accent]}"

        printf '\n[Colors:Header][Inactive]\n'
        printf 'BackgroundNormal=%s\n'    "${c[windowBackground]}"
        printf 'BackgroundAlternate=%s\n' "${c[windowAlternate]}"
        _roles

        # Window decorations.
        printf '\n[WM]\n'
        printf 'activeBackground=%s\n'   "${c[titlebarActive]}"
        printf 'activeForeground=%s\n'   "${c[foreground]}"
        printf 'activeBlend=%s\n'        "${c[accent]}"
        printf 'inactiveBackground=%s\n' "${c[titlebarInactive]}"
        printf 'inactiveForeground=%s\n' "${c[foregroundInactive]}"
        printf 'inactiveBlend=%s\n'      "${c[foregroundInactive]}"
        printf 'frame=%s\n'              "${c[titlebarActive]}"
        printf 'inactiveFrame=%s\n'      "${c[titlebarInactive]}"

        # How Plasma greys out what cannot be used. Left close to Breeze's own
        # values: these are accessibility behaviour, not decoration.
        printf '\n[ColorEffects:Disabled]\n'
        printf 'Color=%s\n' "${c[disabled]}"
        printf 'ColorAmount=0\n'
        printf 'ColorEffect=0\n'
        printf 'ContrastAmount=0.65\n'
        printf 'ContrastEffect=1\n'
        printf 'IntensityAmount=0.1\n'
        printf 'IntensityEffect=2\n'

        printf '\n[ColorEffects:Inactive]\n'
        printf 'ChangeSelectionColor=true\n'
        printf 'Color=%s\n' "${c[foregroundInactive]}"
        printf 'ColorAmount=0.025\n'
        printf 'ColorEffect=2\n'
        printf 'ContrastAmount=0.1\n'
        printf 'ContrastEffect=2\n'
        printf 'Enable=false\n'
        printf 'IntensityAmount=0\n'
        printf 'IntensityEffect=0\n'
    } > "$out"

    log_info "  $(basename "$out")  $(scheme_name "$variant")"
}

for variant in dark light; do
    generate "$variant"
done

log_step "generated $(ls -1 "$REPO_ROOT/theme/colors"/*.colors | wc -l) colour scheme(s)"

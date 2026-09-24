#!/usr/bin/env bash
# Writes a diagnostic report bundle.
#
#   create [--reason <text>] [--qml <file>]   write one now
#          [--crash <id>]                     ... about a quickshell crash dump
#   list                                      what has been collected
#   show [<name>]                             print a bundle (newest by default)
#   remove <name>                             delete one
#
# Local only. Nothing here sends anything anywhere -- a report is a directory of
# text files, and every consumer of one is a separate, opt-in thing.
#
# It is a shell script rather than QML because it has to run when the shell is
# dead: the systemd unit's OnFailure= points at it, so it runs precisely at the
# moment a QML function would be unavailable. In-process failures call the same
# script, so there is one report format and one code path.
#
# The config goes through the redaction in lib/redact.sh before it is written.
# That is the privacy boundary, and it is applied here rather than at the point
# a report is read: a bundle that has to be redacted later is a bundle that will
# eventually be read unredacted.
set -uo pipefail

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
source "$REPO_ROOT/scripts/lib/log.sh"
source "$REPO_ROOT/scripts/lib/brand.sh"
source "$REPO_ROOT/scripts/lib/config.sh"
source "$REPO_ROOT/scripts/lib/renderers.sh"
source "$REPO_ROOT/scripts/lib/redact.sh"
source "$REPO_ROOT/scripts/lib/crashes.sh"
source "$REPO_ROOT/scripts/lib/reports.sh"

JOURNAL_LINES=${JOURNAL_LINES:-200}

# --- the four parts --------------------------------------------------------

part_error() {
    local dir=$1 reason=$2 qml=$3

    {
        printf 'reason: %s\n' "${reason:-not stated}"
        printf 'when:   %s\n' "$(date -Is)"

        if [ -n "$qml" ]; then
            printf 'qml:    %s\n\n' "$qml"
            if [ -f "$qml" ]; then
                # The lint output is the closest thing to a stack trace QML
                # offers for a file that failed to load.
                printf -- '--- qmllint ---\n'
                "$REPO_ROOT/scripts/lint-qml.sh" "$qml" 2>&1 | head -60
            else
                printf 'that file does not exist\n'
            fi
        fi
    } > "$dir/error.txt"
}

# Quickshell's own crash dump, when the report is about one.
#
# The dump is the only record of a crash inside the engine -- systemd never
# sees one, because quickshell catches the signal and restarts itself -- and it
# holds the stack trace and the shell's last words. Both go through the text
# redaction: the dump carries the environment and absolute paths.
part_crash() {
    local dir=$1 id=$2
    local crash
    crash=$(crash_dir "$id") || {
        printf 'no crash dump found for: %s\n' "${id:-<newest>}" >> "$dir/error.txt"
        return 0
    }

    crash_text "$crash" | redact_text > "$dir/crash.txt"
    printf '%s\n' "$(report_crash_line "$(basename "$crash")")" >> "$dir/error.txt"
}

part_environment() {
    local dir=$1
    {
        printf '%-18s %s\n' "$DISPLAY_NAME" "$VERSION"
        printf '%-18s %s\n' "schema" "$(jq -r '.schemaVersion // "?"' "$DATA_DIR/config/defaults/shell.json" 2>/dev/null || echo '?')"
        printf '%-18s %s\n' "profile" "$(active_profile)"
        printf '%-18s %s\n' "renderer" "$("$REPO_ROOT/scripts/renderer.sh" status 2>/dev/null | sed -n 's/^configured: *//p')"
        printf '%-18s %s\n' "shell package" "$(live_shell_package '<unset>')"
        printf '%-18s %s\n' "desktop" "${XDG_CURRENT_DESKTOP:-unset}"
        printf '%-18s %s\n' "session" "${XDG_SESSION_TYPE:-unset}"
        printf '%-18s %s\n' "quickshell" "$(quickshell --version 2>/dev/null | head -1 || echo 'not found')"
        printf '%-18s %s\n' "plasmashell" "$(plasmashell --version 2>/dev/null | head -1 || echo 'not found')"
        printf '%-18s %s\n' "kwin" "$(kwin_wayland --version 2>/dev/null | head -1 || echo 'not found')"
        printf '%-18s %s\n' "qt" "$(qmake6 -query QT_VERSION 2>/dev/null || echo 'not found')"
        printf '%-18s %s\n' "distro" "$(sed -n 's/^PRETTY_NAME=//p' /etc/os-release 2>/dev/null | tr -d '"')"
        printf '%-18s %s\n' "kernel" "$(uname -r)"
    } > "$dir/environment.txt"
}

part_config() {
    local dir=$1

    # Worth saying out loud: an unparseable profile is itself the most likely
    # reason a report is being written.
    config_profile_broken && printf 'the profile does not parse: %s\n' "$(profile_file)" >> "$dir/error.txt"

    config_merged | redact_json "$HOME" "${USER:-$(id -un)}" > "$dir/config.json"

    # Proof the pass ran, for anyone about to paste this somewhere. A bundle
    # that merely claims to be redacted is not worth much.
    {
        printf 'home replaced with ~, username with <user>\n'
        printf 'values masked under keys matching: %s\n' "$REDACT_SECRET_RE"
        printf 'remaining occurrences of the username: %s\n' \
            "$(grep -c -- "${USER:-$(id -un)}" "$dir/config.json" 2>/dev/null || echo 0)"
    } > "$dir/redaction.txt"
}

part_journal() {
    local dir=$1
    journalctl --user -u "$SYSTEMD_UNIT" -n "$JOURNAL_LINES" --no-pager 2>/dev/null \
        | redact_text > "$dir/journal.txt" || : > "$dir/journal.txt"

    local health="$STATE_DIR/widget-health.json"
    if [ -f "$health" ]; then
        redact_json "$HOME" "${USER:-$(id -un)}" < "$health" > "$dir/widget-health.json"
    else
        printf '{}\n' > "$dir/widget-health.json"
    fi
}

# --- commands --------------------------------------------------------------

cmd=${1:-create}
[ $# -gt 0 ] && shift

REASON=""
QML_FILE=""
CRASH_ID=""
WANT_CRASH=no
args=()
while [ $# -gt 0 ]; do
    case "$1" in
        --reason) REASON=${2:?--reason needs a value}; shift ;;
        --qml)    QML_FILE=${2:?--qml needs a value}; shift ;;
        --crash)  CRASH_ID=${2-}; WANT_CRASH=yes; [ $# -gt 1 ] && shift ;;
        -*)       die "unknown option: $1" ;;
        *)        args+=("$1") ;;
    esac
    shift
done

case "$cmd" in
    create)
        # A second is not fine-grained enough to name a directory by: two
        # reports written in the same one -- a widget failing and the unit dying
        # right after it, exactly when reports matter -- would otherwise land in
        # the same directory, and the second would overwrite the first.
        dir=$(unique_path "$REPORT_DIR/$(date +%Y%m%d-%H%M%S)")
        mkdir -p "$dir" || die "cannot write to $REPORT_DIR"

        part_error       "$dir" "$REASON" "$QML_FILE"
        [ "$WANT_CRASH" = yes ] && part_crash "$dir" "$CRASH_ID"
        part_environment "$dir"
        part_config      "$dir"
        part_journal     "$dir"

        # Readable by this user only: it holds a journal tail, and redaction
        # covers what we know to look for rather than everything a log might
        # ever contain.
        chmod 700 "$dir"
        chmod 600 "$dir"/*

        log_step "report: $dir"
        log_info "  nothing has been sent anywhere; read it with: $ALIAS report show"
        printf '%s\n' "$dir"
        ;;

    list)
        [ -d "$REPORT_DIR" ] || { log_info "no reports"; exit 0; }
        found=0
        for d in "$REPORT_DIR"/*/; do
            [ -d "$d" ] || continue
            found=1
            printf '%-20s %s\n' "$(basename "$d")" "$(sed -n 's/^reason: //p' "$d/error.txt" 2>/dev/null | head -1)"
        done
        [ "$found" = 1 ] || log_info "no reports"
        ;;

    show)
        name=${args[0]:-}
        if [ -z "$name" ]; then
            name=$(report_newest)
            [ -n "$name" ] || die "no reports yet"
        fi
        dir="$REPORT_DIR/$(basename "$name")"
        [ -d "$dir" ] || die "no such report: $name"
        # The known parts in a fixed order, then anything `ask` added -- a
        # notification, a unit's journal -- except the bundle it builds from
        # this very output.
        shown=" "
        for f in error.txt crash.txt environment.txt redaction.txt config.json widget-health.json journal.txt; do
            [ -f "$dir/$f" ] || continue
            printf '\n===== %s =====\n' "$f"
            cat "$dir/$f"
            shown="$shown$f "
        done
        for path in "$dir"/*; do
            f=$(basename "$path")
            case "$shown" in *" $f "*) continue ;; esac
            case "$f" in bundle.txt|question.txt) continue ;; esac
            [ -f "$path" ] || continue
            printf '\n===== %s =====\n' "$f"
            cat "$path"
        done
        ;;

    remove)
        name=${args[0]:?usage: $ALIAS report remove <name>}
        dir="$REPORT_DIR/$(basename "$name")"
        [ -d "$dir" ] || die "no such report: $name"
        rm -rf "$dir"
        log_step "removed $dir"
        ;;

    *) die "unknown command: $cmd (expected create, list, show or remove)" ;;
esac

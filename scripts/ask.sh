#!/usr/bin/env bash
# Hands a redacted diagnostic report to an assistant.
#
#   ask                           the newest report, or a fresh one if there is none
#   ask --new [--reason <text>]   write a fresh report first
#   ask --report <name>           a particular report
#   ask --last-notification       the most recent notification the shell has seen
#   ask --notification <n>        the n-th most recent one (0 is the last)
#   ask --unit <name>             a systemd user unit's journal tail
#   ask --failed                  failed user units and recent core dumps
#
#   --provider <p>   clipboard | claude-code | ollama | custom   (default: ai.provider)
#   --show           print exactly what would be sent, then stop (--json for machines)
#   --review         show it in the shell's window instead, whatever the provider
#   --yes            skip the confirmation (the settings window has already shown it)
#   --providers      list the providers and whether each can run here (--json for machines)
#
# Off by default, and nothing leaves this machine without a confirmation that
# shows the actual text. The report is always written locally first -- that
# part needs no permission and is where redaction happens, so every provider
# receives the same bundle `rmpr report show` prints, and nothing else.
#
# The consent is remembered per provider, once given: the first send shows the
# whole bundle and asks; later ones say what is being sent and where, and
# `--show` prints it again at any time. Providers that keep the data here --
# the clipboard, an Ollama on localhost -- ask nothing.
set -uo pipefail

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
source "$REPO_ROOT/scripts/lib/log.sh"
source "$REPO_ROOT/scripts/lib/brand.sh"
source "$REPO_ROOT/scripts/lib/config.sh"
source "$REPO_ROOT/scripts/lib/redact.sh"

REPORT_DIR="$STATE_DIR/diagnostics"
CONSENT_FILE="$STATE_DIR/ai-consent.json"
PROVIDERS=(clipboard claude-code ollama custom)

# --- providers ---------------------------------------------------------------

# provider_available <id>  -- prints why not on failure.
provider_available() {
    case "$1" in
        clipboard)
            command -v wl-copy >/dev/null 2>&1 || command -v xclip >/dev/null 2>&1 \
                || { echo "needs wl-copy or xclip"; return 1; } ;;
        claude-code)
            command -v claude >/dev/null 2>&1 || { echo "the 'claude' command is not installed"; return 1; } ;;
        ollama)
            command -v curl >/dev/null 2>&1 || { echo "needs curl"; return 1; }
            local url; url=$(config_get '.ai.ollamaUrl' 'http://127.0.0.1:11434')
            command -v ollama >/dev/null 2>&1 \
                || curl -sS --max-time 1 "$url/api/tags" >/dev/null 2>&1 \
                || { echo "nothing answers at $url"; return 1; } ;;
        custom)
            [ "$(config_get '.ai.command' '[]')" != "[]" ] || { echo "ai.command is empty"; return 1; } ;;
        *) echo "unknown provider"; return 1 ;;
    esac
    return 0
}

# Whether data would leave this machine. The answer decides whether a
# confirmation is needed, so it errs towards yes: a custom command is
# assumed to send unless proven otherwise, and an Ollama anywhere but
# localhost counts as elsewhere.
provider_leaves_machine() {
    case "$1" in
        clipboard) return 1 ;;
        ollama)
            local url host
            url=$(config_get '.ai.ollamaUrl' 'http://127.0.0.1:11434')
            host=${url#*://}; host=${host%%/*}; host=${host%%:*}
            case "$host" in
                localhost|127.0.0.1|::1|"[::1]") return 1 ;;
                *) return 0 ;;
            esac ;;
        *) return 0 ;;
    esac
}

list_providers() {
    local json=${1:-no}
    [ "$json" = json ] && printf '['
    local first=1 p why avail
    for p in "${PROVIDERS[@]}"; do
        if why=$(provider_available "$p"); then avail=true; why=""; else avail=false; fi
        if [ "$json" = json ]; then
            [ "$first" = 1 ] || printf ','
            jq -cn --arg id "$p" --argjson a "$avail" --arg why "$why" \
                --argjson leaves "$(provider_leaves_machine "$p" && echo true || echo false)" \
                '{id:$id, available:$a, reason:$why, leavesMachine:$leaves}'
        else
            printf '%-12s %-12s %s\n' "$p" "$([ "$avail" = true ] && echo available || echo unavailable)" "$why"
        fi
        first=0
    done
    [ "$json" = json ] && printf ']\n'
    return 0
}

# --- the bundle --------------------------------------------------------------

newest_report() { ls -1 "$REPORT_DIR" 2>/dev/null | sort | tail -1; }

create_report() {
    "$REPO_ROOT/scripts/report.sh" create --reason "$1" 2>/dev/null | tail -1
}

shell_ipc() {
    quickshell ipc --path "$QS_CONFIG_DIR/shell.qml" call "$@" 2>/dev/null
}

# Each of these leaves a report directory in $DIR and a one-line question in
# $QUESTION. Extra parts are written into the report itself, redacted, so the
# bundle stays one directory `report show` can print.
gather_report() {
    if [ -n "$REPORT_NAME" ]; then
        DIR="$REPORT_DIR/$(basename "$REPORT_NAME")"
        [ -d "$DIR" ] || die "no such report: $REPORT_NAME"
    elif [ "$FRESH" = yes ] || [ -z "$(newest_report)" ]; then
        DIR=$(create_report "${REASON:-asked from the command line}")
    else
        DIR="$REPORT_DIR/$(newest_report)"
    fi
    [ -d "$DIR" ] || die "could not write a report"
    # A report that was gathered for a particular question keeps it.
    if [ -f "$DIR/question.txt" ]; then
        QUESTION=$(cat "$DIR/question.txt")
    else
        QUESTION="What is wrong here, and how do I fix it?"
    fi
}

gather_notification() {
    local index=${1:-0} json
    json=$(shell_ipc notifications at "$index") || json=""
    [ -n "$json" ] && [ "$json" != "null" ] && [ "$json" != '""' ] \
        || die "the shell has not seen a notification (is it running, with notifications.history or ai.enabled on?)"
    printf '%s' "$json" | jq -e . >/dev/null 2>&1 || die "the shell returned something that is not a notification"

    local app summary
    app=$(printf '%s' "$json" | jq -r '.appName // "?"')
    summary=$(printf '%s' "$json" | jq -r '.summary // ""')
    DIR=$(create_report "notification from $app: $summary")
    [ -d "$DIR" ] || die "could not write a report"

    printf '%s' "$json" | redact_json "$HOME" "${USER:-$(id -un)}" > "$DIR/notification.json"
    chmod 600 "$DIR/notification.json"
    QUESTION="The application '$app' sent this notification. What does it mean, and what should I do about it?"
}

gather_unit() {
    local unit=$1
    DIR=$(create_report "unit $unit")
    [ -d "$DIR" ] || die "could not write a report"
    {
        printf 'unit:   %s\n' "$unit"
        printf 'state:  %s\n\n' "$(systemctl --user is-active "$unit" 2>/dev/null || echo unknown)"
        journalctl --user -u "$unit" -n "${JOURNAL_LINES:-200}" --no-pager 2>&1
    } | redact_text > "$DIR/unit.txt"
    chmod 600 "$DIR/unit.txt"
    QUESTION="The systemd user unit '$unit' is misbehaving. Its journal is in unit.txt. What is wrong, and how do I fix it?"
}

gather_failed() {
    DIR=$(create_report "failed units and core dumps")
    [ -d "$DIR" ] || die "could not write a report"
    {
        printf -- '--- failed user units ---\n'
        systemctl --user --failed --no-legend --no-pager 2>&1
        printf '\n--- recent core dumps ---\n'
        coredumpctl list --no-legend --no-pager -r --since '-24h' 2>&1 | head -20
    } | redact_text > "$DIR/crashes.txt"
    chmod 600 "$DIR/crashes.txt"
    QUESTION="Something on this desktop has crashed. crashes.txt lists failed units and recent core dumps. What is most likely wrong, and what should I look at first?"
}

write_bundle() {
    BUNDLE="$DIR/bundle.txt"
    printf '%s\n' "$QUESTION" > "$DIR/question.txt"
    chmod 600 "$DIR/question.txt"
    {
        printf '%s %s on KDE Plasma. A redacted diagnostic bundle follows; home directories are shown as ~ and the username as <user>.\n' "$DISPLAY_NAME" "$VERSION"
        printf '\nQuestion: %s\n' "$QUESTION"
        "$REPO_ROOT/scripts/report.sh" show "$(basename "$DIR")" 2>/dev/null
    } > "$BUNDLE"
    chmod 600 "$BUNDLE"
}

# --- consent -----------------------------------------------------------------

consented() {
    [ -f "$CONSENT_FILE" ] && jq -e --arg p "$1" '.[$p] != null' "$CONSENT_FILE" >/dev/null 2>&1
}

record_consent() {
    mkdir -p "$STATE_DIR"
    local now; now=$(date -Is)
    if [ -f "$CONSENT_FILE" ] && jq -e . "$CONSENT_FILE" >/dev/null 2>&1; then
        jq --arg p "$1" --arg t "$now" '.[$p] = $t' "$CONSENT_FILE" > "$CONSENT_FILE.tmp"
    else
        jq -n --arg p "$1" --arg t "$now" '{($p): $t}' > "$CONSENT_FILE.tmp"
    fi
    mv "$CONSENT_FILE.tmp" "$CONSENT_FILE"
    chmod 600 "$CONSENT_FILE"
}

# Returns 0 to go ahead. Every path that sends prints where to first.
confirm() {
    local provider=$1
    provider_leaves_machine "$provider" || return 0

    if [ "$YES" = yes ]; then
        record_consent "$provider"
        return 0
    fi

    if consented "$provider"; then
        log_info "sending $(wc -c < "$BUNDLE") bytes, redacted, to $provider (agreed on $(jq -r --arg p "$provider" '.[$p]' "$CONSENT_FILE"))"
        log_info "  '$ALIAS ask --show' prints exactly what; '$ALIAS ask --forget' withdraws the agreement"
        return 0
    fi

    if [ -t 0 ] && [ -t 1 ]; then
        cat "$BUNDLE"
        echo
        log_warn "everything above would be sent to '$provider', which is outside this machine."
        printf 'send it? [y/N] ' >&2
        local answer; read -r answer
        case "$answer" in
            y|Y|yes) record_consent "$provider"; return 0 ;;
            *) log_info "nothing sent"; return 1 ;;
        esac
    fi

    # No terminal to ask in. If the shell is running, its window can show the
    # bundle and ask; otherwise there is nobody to ask, and the answer is no.
    if open_in_shell; then
        log_info "the shell is showing what would be sent; confirm it there"
        return 2
    fi
    log_error "'$provider' sends the report off this machine, and there is no terminal here to confirm in"
    log_error "  read it:      $ALIAS ask --show"
    log_error "  then send it: $ALIAS ask --yes"
    return 1
}

# The shell's window, on the report already gathered -- so the window and this
# process agree on the bytes, and nothing is gathered twice.
open_in_shell() {
    shell_ipc ask open "$(basename "$DIR")" >/dev/null 2>&1
}

# --- sending -----------------------------------------------------------------

find_terminal() {
    local t
    for t in "${TERMINAL:-}" konsole kitty alacritty foot xterm; do
        [ -n "$t" ] && command -v "$t" >/dev/null 2>&1 && { printf '%s' "$t"; return 0; }
    done
    return 1
}

# run_in_terminal <cmd...>  -- interactive programs need a terminal; from a
# shortcut or the settings window there is none, so one is opened.
run_in_terminal() {
    if [ -t 0 ] && [ -t 1 ]; then
        exec "$@"
    fi
    local term; term=$(find_terminal) || die "no terminal emulator found (set \$TERMINAL)"
    case "$(basename "$term")" in
        kitty|foot) setsid -f "$term" "$@" >/dev/null 2>&1 ;;
        *)          setsid -f "$term" -e "$@" >/dev/null 2>&1 ;;
    esac
    log_step "opened $(basename "$term") running $(basename "$1")"
}

send_clipboard() {
    if command -v wl-copy >/dev/null 2>&1; then
        wl-copy < "$BUNDLE"
    else
        xclip -selection clipboard < "$BUNDLE"
    fi || die "could not copy to the clipboard"
    log_step "copied to the clipboard: $(wc -c < "$BUNDLE") bytes, redacted"
    log_info "  nothing has been sent anywhere; paste it where you like"
    # From a shortcut or a button there is no terminal to read that in.
    if ! [ -t 1 ] && command -v notify-send >/dev/null 2>&1; then
        notify-send -a "$DISPLAY_NAME" -i edit-copy "Report copied to the clipboard" \
            "$(wc -c < "$BUNDLE") bytes, redacted. Nothing has been sent anywhere." 2>/dev/null || true
    fi
}

send_claude_code() {
    run_in_terminal claude "$(cat "$BUNDLE")"
}

send_ollama() {
    local url model
    url=$(config_get '.ai.ollamaUrl' 'http://127.0.0.1:11434')
    model=$(config_get '.ai.ollamaModel' '')
    if [ -z "$model" ]; then
        model=$(curl -sS --max-time 3 "$url/api/tags" 2>/dev/null | jq -r '.models[0].name // empty')
        [ -n "$model" ] || die "Ollama at $url lists no models; set ai.ollamaModel or pull one"
    fi
    log_step "asking $model at $url"
    curl -sS --max-time 600 "$url/api/generate" \
        -d "$(jq -n --arg m "$model" --rawfile p "$BUNDLE" '{model:$m, prompt:$p, stream:false}')" \
        | jq -r '.response // .error // "no answer"'
}

send_custom() {
    local cmd
    cmd=$(config_get '.ai.command' '[]')
    [ "$cmd" != "[]" ] || die "ai.command is empty"
    local argv=() a replaced=no
    while IFS= read -r a; do
        if [ "$a" = "%report" ]; then argv+=("$BUNDLE"); replaced=yes; else argv+=("$a"); fi
    done < <(printf '%s' "$cmd" | jq -r '.[]')
    log_step "running: ${argv[*]}"
    if [ "$replaced" = yes ]; then
        "${argv[@]}"
    else
        "${argv[@]}" < "$BUNDLE"
    fi
}

# --- main --------------------------------------------------------------------

MODE=report; MODE_ARG=""
REPORT_NAME=""; FRESH=no; REASON=""
PROVIDER=""; SHOW=no; REVIEW=no; YES=no; LIST=no; JSON=no; FORGET=no

while [ $# -gt 0 ]; do
    case "$1" in
        --report)            REPORT_NAME=${2:?--report needs a name}; shift ;;
        --new)               FRESH=yes ;;
        --reason)            REASON=${2:?--reason needs a value}; shift ;;
        --last-notification) MODE=notification; MODE_ARG=0 ;;
        --notification)      MODE=notification; MODE_ARG=${2:?--notification needs an index}; shift ;;
        --unit)              MODE=unit; MODE_ARG=${2:?--unit needs a name}; shift ;;
        --failed)            MODE=failed ;;
        --provider)          PROVIDER=${2:?--provider needs a name}; shift ;;
        --show)              SHOW=yes ;;
        --review)            REVIEW=yes ;;
        --yes|-y)            YES=yes ;;
        --providers)         LIST=yes ;;
        --json)              JSON=yes ;;
        --forget)            FORGET=yes ;;
        -h|--help)           sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *)                   die "unknown option: $1" ;;
    esac
    shift
done

if [ "$LIST" = yes ]; then
    list_providers "$([ "$JSON" = yes ] && echo json || echo text)"
    exit 0
fi

if [ "$FORGET" = yes ]; then
    rm -f "$CONSENT_FILE"
    log_step "every provider will ask again before sending"
    exit 0
fi

[ -n "$PROVIDER" ] || PROVIDER=$(config_get '.ai.provider' 'clipboard')
printf '%s\n' "${PROVIDERS[@]}" | grep -qxF "$PROVIDER" || die "unknown provider '$PROVIDER' (one of: ${PROVIDERS[*]})"

# --show needs no provider at all: reading what would be sent is always allowed.
if [ "$SHOW" != yes ]; then
    why=$(provider_available "$PROVIDER") || die "provider '$PROVIDER' cannot run here: $why"
fi

case "$MODE" in
    report)       gather_report ;;
    notification) gather_notification "$MODE_ARG" ;;
    unit)         gather_unit "$MODE_ARG" ;;
    failed)       gather_failed ;;
esac
write_bundle

if [ "$SHOW" = yes ]; then
    if [ "$JSON" = yes ]; then
        jq -n --arg report "$(basename "$DIR")" --arg question "$QUESTION" \
              --arg provider "$PROVIDER" --rawfile bundle "$BUNDLE" \
              --argjson providers "$(list_providers json)" \
              '{report:$report, question:$question, provider:$provider, bundle:$bundle, providers:$providers}'
    else
        cat "$BUNDLE"
    fi
    exit 0
fi

if [ "$REVIEW" = yes ]; then
    open_in_shell || die "the shell is not running, so there is no window to review in; use --show"
    exit 0
fi

confirm "$PROVIDER"; rc=$?
[ "$rc" -eq 0 ] || exit "$rc"

case "$PROVIDER" in
    clipboard)   send_clipboard ;;
    claude-code) send_claude_code ;;
    ollama)      send_ollama ;;
    custom)      send_custom ;;
esac

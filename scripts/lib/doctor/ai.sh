# shellcheck shell=bash
# AI assist: whether its provider can run here, what has been agreed to, and
# the notification listener it reads.
#
# A section of doctor.sh, which sources it and supplies ok, warn, bad, fix and
# section. Requires brand.sh and config.sh.

doctor_ai() {
    local merged_cfg ai_enabled ai_provider history_on avail consent n
    section "AI assist"

    merged_cfg=$(config_merged)
    ai_enabled=$(jq -r '.ai.enabled // false' <<< "$merged_cfg")
    ai_provider=$(jq -r '.ai.provider // "clipboard"' <<< "$merged_cfg")
    history_on=$(jq -r '.notifications.history // false' <<< "$merged_cfg")

    if [ "$ai_enabled" = true ]; then
        avail=$("$REPO_ROOT/scripts/ask.sh" --providers --json 2>/dev/null \
                | jq -r --arg p "$ai_provider" '.[] | select(.id == $p) | if .available then "yes" else .reason end')
        if [ "$avail" = yes ]; then
            ok "AI assist is on, provider '$ai_provider' can run here"
        else
            bad "AI assist is on, but provider '$ai_provider' cannot run here: ${avail:-unknown provider}"
            fix "pick another: $ALIAS ask --providers"
        fi
        consent="$STATE_DIR/ai-consent.json"
        if [ -f "$consent" ]; then
            printf '  %s--%s    agreed to send: %s\n' "$_c_dim" "$_c_off" "$(jq -r 'keys | join(", ")' "$consent" 2>/dev/null)"
            fix "withdraw: $ALIAS ask --forget"
        fi
        if [ "$(kreadconfig6 --file kglobalshortcutsrc --group "$SLUG" --key ask --default '' | cut -d, -f1)" = "" ]; then
            printf '  %s--%s    no key bound to ask about the last notification\n' "$_c_dim" "$_c_off"
            fix "bind one: $ALIAS shortcuts set ask <key>"
        fi
    else
        ok "AI assist is off; nothing is ever sent"
    fi

    if [ "$ai_enabled" = true ] || [ "$history_on" = true ]; then
        if shell_running; then
            n=$(quickshell ipc --path "$(shell_ipc_path)" call notifications count 2>/dev/null || echo '?')
            ok "the notification listener is wanted and the shell is running ($n remembered)"
        else
            warn "the notification listener is wanted, but the shell is not running"
            fix "the history is kept in memory by the shell; nothing is recorded while it is down"
        fi
    else
        ok "no notification listener; nothing on the bus is read"
    fi
}

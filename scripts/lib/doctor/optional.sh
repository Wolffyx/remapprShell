# shellcheck shell=bash
# Optional components, and what each one adds.
#
# A section of doctor.sh, which sources it and supplies ok, warn, bad, fix and
# section. Requires log.sh.

doctor_optional() {
    local pair bin desc
    section "optional components"

    for pair in "union:a Qt style, selectable as the widget style" \
                "claude:the claude-code AI provider" \
                "ollama:the ollama AI provider" \
                "wl-copy:the clipboard AI provider"; do
        bin=${pair%%:*}; desc=${pair#*:}
        if command -v "$bin" >/dev/null 2>&1 || pacman -Qq "$bin" >/dev/null 2>&1; then
            ok "$bin present ($desc)"
        else
            printf '  %s--%s    %s not installed (%s)\n' "$_c_dim" "$_c_off" "$bin" "$desc"
        fi
    done
}

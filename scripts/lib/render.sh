# shellcheck shell=bash
# Renders a *.in template by replacing @VAR@ placeholders.
#
# Deliberately not envsubst: these templates are shell and QML, both of which
# use $VAR legitimately. A distinct @VAR@ marker means template substitution
# and the target language can never collide.
#
# An unresolved @VAR@ left in the output is a hard error -- a typo must fail
# loudly rather than silently render an empty string into a path.

RENDER_VARS=(SLUG ALIAS DISPLAY_NAME APP_ID DBUS_NAME ENV_PREFIX SHELL_PACKAGE_ID
             VERSION QS_CONFIG_DIR CONFIG_DIR DATA_DIR STATE_DIR BIN_DIR
             SESSION_BIN CTL_BIN SYSTEMD_UNIT SAFE_MODE_VAR DEBUG_VAR
             REPO_PUSH REPO_FETCH REPO_ROOT)

render_template() {
    local src=$1 dest=$2 tmp v val
    tmp=$(mktemp)

    local args=()
    for v in "${RENDER_VARS[@]}"; do
        # Escape the replacement for sed: \ & and the | delimiter are special.
        val=${!v-}
        val=${val//\\/\\\\}
        val=${val//&/\\&}
        val=${val//|/\\|}
        args+=(-e "s|@$v@|$val|g")
    done

    sed "${args[@]}" "$src" > "$tmp"

    if grep -qE '@[A-Z_]+@' "$tmp"; then
        log_error "unresolved placeholders in $src:"
        grep -oE '@[A-Z_]+@' "$tmp" | sort -u | sed 's/^/  /' >&2
        rm -f "$tmp"
        return 1
    fi

    mkdir -p "$(dirname "$dest")"
    mv "$tmp" "$dest"
    chmod 755 "$dest"
}

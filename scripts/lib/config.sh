# shellcheck shell=bash
# Reads the effective configuration from shell: defaults merged with the
# active profile. Sourced, never executed. Requires brand.sh and jq.
#
# The same merge the report writer does, in one place, so a CLI command and
# the report can never disagree about what a setting is.

config_active_profile() {
    local state="$CONFIG_DIR/state.json"
    [ -f "$state" ] && jq -r '.profile // "default"' "$state" 2>/dev/null || echo default
}

config_defaults_file() {
    local f="$DATA_DIR/config/defaults/shell.json"
    [ -f "$f" ] || f="$REPO_ROOT/config/defaults/shell.json"
    printf '%s' "$f"
}

# config_merged   -- the merged JSON on stdout. A profile that does not parse
# is ignored, which is also what the running shell does with it.
config_merged() {
    local defaults profile
    defaults=$(config_defaults_file)
    profile="$CONFIG_DIR/profiles/$(config_active_profile)/shell.json"
    if [ -f "$profile" ] && jq -e . "$profile" >/dev/null 2>&1; then
        jq -s '.[0] * .[1]' "$defaults" "$profile"
    else
        cat "$defaults" 2>/dev/null || echo '{}'
    fi
}

# config_get <jq path> [default]   -- one value, raw. Arrays come back as JSON.
config_get() {
    local path=$1 fallback=${2:-}
    local v
    v=$(config_merged | jq -r --arg d "$fallback" "$path // \$d | if type == \"array\" or type == \"object\" then tojson else tostring end" 2>/dev/null)
    printf '%s' "${v:-$fallback}"
}

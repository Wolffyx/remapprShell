# shellcheck shell=bash
# The shell's configuration, from the scripts' side: the shipped defaults
# merged with the active profile, and the one way to write a setting into that
# profile. Sourced, never executed. Requires brand.sh and jq.
#
# One place for both, so a CLI command, the report and the renderer can never
# disagree about what a setting is -- and so every write is made the same safe
# way, rather than five slightly different ways.
#
# Which profile is active, and where it lives, are brand.sh's: active_profile,
# profile_file.

# What config_load read, when it has. Never taken from the environment: a
# merge some other process made is not this one's configuration.
unset CONFIG_MERGED

# The shipped defaults: the installed copy, which is what the running shell
# reads, and the checkout's before anything is installed.
config_defaults_file() {
    local f="$DATA_DIR/config/defaults/shell.json"
    [ -f "$f" ] || f="$REPO_ROOT/config/defaults/shell.json"
    printf '%s' "$f"
}

# Whether the active profile is there and does not parse. Such a profile is
# read as absent -- which is what the running shell does with it -- and never
# written over: it is the user's file, and a missing bracket is not permission
# to replace the rest of it.
config_profile_broken() {
    local file
    file=$(profile_file)
    [ -f "$file" ] && ! jq -e . "$file" >/dev/null 2>&1
}

# config_merged   -- the merged JSON on stdout. A profile that does not parse
# is ignored, which is also what the running shell does with it.
config_merged() {
    [ -n "${CONFIG_MERGED:-}" ] && { printf '%s\n' "$CONFIG_MERGED"; return 0; }
    local defaults profile
    defaults=$(config_defaults_file)
    profile=$(profile_file)
    if [ -f "$profile" ] && jq -e . "$profile" >/dev/null 2>&1; then
        jq -s '.[0] * .[1]' "$defaults" "$profile"
    else
        cat "$defaults" 2>/dev/null || echo '{}'
    fi
}

# config_load   -- merge once, and have every read after it use that.
#
# A command asks for many settings -- `theme status` for eighteen, doctor for
# a dozen -- and each config_get merged the two files again, four jq runs at a
# time. Called at a script's top level, never inside `$(...)`: an assignment
# made in a subshell dies with it, and every read would go on merging.
# config_set loads again after it writes, so nothing reads a setting from
# before its own write. Not exported, so a command this one runs reads the
# files for itself.
config_load() {
    CONFIG_MERGED=""
    CONFIG_MERGED=$(config_merged)
}

# config_get <jq path> [default]   -- one value, raw. Arrays come back as JSON.
#
# Absent means absent, and nothing else does. jq's `//` takes its right-hand
# side when the left is false OR null, so `.x // "true"` answered "true" for a
# setting whose value was `false` -- every boolean that was off read back as
# on. A setting exists to be turned off, so the test is against null alone.
config_get() {
    local path=$1 fallback=${2:-}
    local v
    v=$(config_merged | jq -r --arg d "$fallback" \
        "($path) as \$v | if \$v == null then \$d
         else (\$v | if type == \"array\" or type == \"object\" then tojson else tostring end) end" 2>/dev/null) || v=""
    [ -n "$v" ] || v=$fallback
    printf '%s' "$v"
}

# config_set <jq path> <json>           -- one setting, into the active profile
# config_set_string <jq path> <text>    -- the same, for a value that is text
#
# Sparse: the profile holds what the user changed, not a materialised copy of
# today's defaults, so only the one path is written and everything else in the
# file is left as it was.
#
# Written whole into a file beside the profile, then renamed over it. The shell
# watches the profile, and both of the ways this used to be done could hand it
# half a file: a redirect truncates before it writes, and a temporary file in
# /tmp is a copy across filesystems when `mv` puts it in place, not a rename.
# A read landing in either window gets a parse error, and the shell answers one
# by keeping its last good configuration -- so the setting just written would
# appear not to have been.
#
# 0 written; 1 the write failed; 2 nothing written, because the profile does
# not parse. What to say about a 2 is the caller's -- some refuse outright,
# some carry on and say the setting was not kept -- so none is said here.
config_set()        { _config_write "$1" --argjson "$2"; }
config_set_string() { _config_write "$1" --arg "$2"; }

_config_write() {   # <path> <--arg|--argjson> <value>
    local path=$1 how=$2 value=$3 file dir tmp
    file=$(profile_file)
    dir=${file%/*}
    config_profile_broken && return 2
    mkdir -p "$dir" || return 1
    tmp=$(mktemp "$dir/.shell.json.XXXXXX") || return 1
    if [ -f "$file" ]; then
        jq "$how" v "$value" "$path = \$v" "$file" > "$tmp"
    else
        jq -n "$how" v "$value" "$path = \$v" > "$tmp"
    fi || { rm -f "$tmp"; return 1; }
    mv -f "$tmp" "$file" || { rm -f "$tmp"; return 1; }
    if [ -n "${CONFIG_MERGED:-}" ]; then config_load; fi
    return 0
}

# shellcheck shell=bash
# Keeping a configuration that is about to be replaced.
#
# Two things in this project replace the active profile wholesale rather than
# editing it: `preset apply`, and the first-run wizard's Finish. Both are
# reasonable -- a preset is a layout, and merging two layouts gives a third
# that is neither -- and both are a one-way door without this.
#
# The configuration being replaced is kept twice, in two places, on purpose.
#
# The copy under the state directory is the old one and it is not enough: the
# state directory is what a restore point rolls back, so a rollback takes the
# backups along with the thing they were protecting. Someone who lost a layout
# that way is told there are restore points and finds none of them has it.
#
# So the real copy is a profile, beside the one being replaced, in the
# configuration directory. A profile outlives a state rollback, is listed by
# `profile list` and by the settings window, and is switched back to with one
# command rather than a path someone has to have kept.
#
# Requires brand.sh, log.sh.

# What the last keep_profile saved, for a caller that wants to say so. Both
# are empty when there was nothing worth keeping.
KEPT_PROFILE=""
KEPT_PROFILE_BACKUP=""

# Copies the active profile aside under a name that says what it was.
#
# Sets KEPT_PROFILE and KEPT_PROFILE_BACKUP rather than printing them: a
# command substitution would run this in a subshell, and the two answers would
# be lost with it. Nothing is kept when there is nothing worth keeping -- a
# profile that does not exist yet, or an empty one -- and that is not a
# failure, so the caller tests KEPT_PROFILE rather than the exit status.
#
# Named for what it is rather than for when it was taken, with the time added
# only when that name is already in use: somebody trying three layouts should
# end up with one "before-meridian", not three timestamps to tell apart.
keep_profile() {
    local label=${1:?keep_profile: a label is required}
    local target saved
    KEPT_PROFILE=""
    KEPT_PROFILE_BACKUP=""

    target=$(profile_file)
    [ -f "$target" ] || return 0

    # Nothing but whitespace in it. Checked before the parse below, because a
    # file jq cannot read is otherwise kept on purpose and this one is not
    # worth keeping -- `[ -s ]` called a lone newline a configuration.
    grep -q '[^[:space:]]' "$target" 2>/dev/null || return 0

    # "Empty" is the same question the shell asks before deciding a machine has
    # never been configured (ConfigStore.configured): a profile carrying only
    # `schemaVersion`, which the shell writes itself when it seeds one, is not
    # a configuration. A file of one newline is not either, and `[ -s ]` said
    # it was.
    #
    # A file that does not parse at all IS kept. It is the one someone most
    # wants back after something replaces it, and refusing to copy it because
    # a bracket is missing would be the cruellest reading of "empty".
    if jq -e '[keys[] | select(. != "schemaVersion")] | length == 0' "$target" >/dev/null 2>&1; then
        return 0
    fi

    KEPT_PROFILE_BACKUP="$STATE_DIR/profile-backups/$(date +%Y%m%d-%H%M%S)-$label.json"
    mkdir -p "$(dirname "$KEPT_PROFILE_BACKUP")"
    cp -a "$target" "$KEPT_PROFILE_BACKUP"

    saved="$label"
    if [ -e "$CONFIG_DIR/profiles/$saved" ]; then
        saved="$label-$(date +%H%M%S)"
    fi
    mkdir -p "$CONFIG_DIR/profiles/$saved"
    cp -a "$target" "$CONFIG_DIR/profiles/$saved/shell.json"
    # Per-output overrides belong to the configuration too.
    [ -d "$(dirname "$target")/monitors" ] \
        && cp -a "$(dirname "$target")/monitors" "$CONFIG_DIR/profiles/$saved/" 2>/dev/null

    KEPT_PROFILE=$saved
}

# Says where a kept profile went, in the words both callers use. Says nothing
# when nothing was kept.
say_kept_profile() {
    [ -n "$KEPT_PROFILE" ] || return 0
    log_info "what was there is now the profile '$KEPT_PROFILE'"
    log_info "go back with: $ALIAS profile use $KEPT_PROFILE"
    [ -n "$KEPT_PROFILE_BACKUP" ] && log_info "and a copy is at $KEPT_PROFILE_BACKUP"
    return 0
}

# shellcheck shell=bash
# The configuration: the profile in use and the shipped defaults, each parsed.
#
# A section of doctor.sh, which sources it and supplies ok, warn, bad, fix and
# section. Requires brand.sh.

doctor_configuration() {
    local profile_file defaults_file
    section "configuration"

    # The profile in use, not profiles/default -- checking a file the shell is
    # not reading is a health check that cannot fail when it should.
    profile_file="$(profile_file)"
    if [ -f "$profile_file" ]; then
        if jq -e . "$profile_file" >/dev/null 2>&1; then
            ok "profile parses ($(jq -r '.schemaVersion // "no version"' "$profile_file"))"
        else
            bad "profile is not valid JSON: $profile_file"
            fix "the shell keeps its last good configuration and refuses to write until this parses"
            fix "check it with: jq . $profile_file"
        fi
    else
        warn "no profile yet at $profile_file"
        fix "it is written the first time the shell starts"
    fi

    defaults_file="$DATA_DIR/config/defaults/shell.json"
    if jq -e . "$defaults_file" >/dev/null 2>&1; then
        ok "shipped defaults parse"
    else
        bad "shipped defaults are missing or invalid: $defaults_file"
        fix "run: make link"
    fi
}

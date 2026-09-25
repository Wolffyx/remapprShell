# shellcheck shell=bash
# Starting an application from a script: detached, and in a systemd scope of
# its own.
#
# Sourced, never executed. Requires log.sh and brand.sh already sourced.
#
# The CLI is often run by the shell -- a button in the settings window, a
# notification's "ask" -- and then it is a process of the shell's systemd
# service, and so is anything it starts. `setsid -f` leaves the session, not
# the service's cgroup, and a service that stops, crashes or restarts ends
# every process in that. On 2026-09-24 a restart of the shell took the user's
# game and its store's client with it; a terminal opened from here would have gone the same
# way. So an application started here goes where the shell's own Launch puts
# one (shell/platform/system/Launch.qml): a scope in app.slice, named as
# systemd asks desktops to name them,
#
#     app-<slug>-<application id>-<random>.scope
#
# the slug and the id each escaped by systemd-escape, so a `-` inside either
# is \x2d and the dashes left are the separators.
#
# Where no scope can be made -- no systemd-run, no user manager to ask, a
# process the manager will not take -- the program starts detached as before.
# That is decided once per command, by trying `true` in a scope, and said once.
#
# The tests' no-session switch is not asked: this starts only what the caller
# was going to start anyway, and a suite stands in for systemd-run on its
# PATH, as it does for the program.

# app_scope <app-id> <argv...>: argv, started detached, in a scope named after
# the application -- its desktop entry id where there is one, else the
# program's name. Returns at once; what it started is not waited for.
app_scope() {
    local id=$1; shift
    if _app_scope_available; then
        setsid -f systemd-run --user --scope --slice=app.slice --collect --quiet \
            --unit="$(_app_scope_unit "$id")" -- "$@" >/dev/null 2>&1
    else
        setsid -f "$@" >/dev/null 2>&1
    fi
}

# app-<slug>-<id>-<random>.scope. Sixteen hex digits tell two scopes of the
# same application apart; nothing about them is secret.
_app_scope_unit() {   # <app-id>
    printf 'app-%s-%s-%04x%04x%04x%04x.scope' \
        "$(systemd-escape -- "$SLUG")" "$(systemd-escape -- "$1")" \
        "$RANDOM" "$RANDOM" "$RANDOM" "$RANDOM"
}

# Whether a scope can be made here, found by making one -- it fails the way
# an application's would -- and kept for the rest of the command.
_app_scope_available() {
    if [ -z "${_APP_SCOPE:-}" ]; then
        if command -v systemd-run >/dev/null 2>&1 && command -v systemd-escape >/dev/null 2>&1 \
           && systemd-run --user --scope --slice=app.slice --collect --quiet \
                  --unit="$(_app_scope_unit true)" -- true >/dev/null 2>&1; then
            _APP_SCOPE=yes
        else
            _APP_SCOPE=no
            log_warn "no scope could be made here (no systemd-run, or no systemd user manager); what this starts ends with whatever started it"
        fi
    fi
    [ "$_APP_SCOPE" = yes ]
}

#!/usr/bin/env bash
# Updates the shell, from git or from a local checkout.
#
#   --check            report what an update would bring, change nothing
#   --from <path>      install from a directory instead of the remote
#   --channel <name>   branch to follow (default: from config, else main)
#   --rollback         go back to the state before the last update
#
# Both sources run the same pipeline, on purpose: a local install that skipped
# the migration and verification steps would mean the path most used during
# development is the one least tested.
#
#   preflight -> snapshot -> record -> apply -> migrate -> verify -> restart
#
# and if verification fails, back to where it started.
set -uo pipefail

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
source "$REPO_ROOT/scripts/lib/log.sh"
source "$REPO_ROOT/scripts/lib/brand.sh"
source "$REPO_ROOT/scripts/lib/protected.sh"
source "$REPO_ROOT/scripts/lib/snapshot.sh"

# A throwaway HOME does not sandbox the user's systemd instance. Without this,
# a test updating a copy of the repo restarted the real, running shell -- and
# every run of the suite did exactly that, until 2026-09-11.
session_available() { [ -z "${!NO_SESSION_VAR:-}" ]; }

MODE=update
LOCAL_SOURCE=""
CHANNEL=""

while [ $# -gt 0 ]; do
    case "$1" in
        --check)    MODE=check ;;
        --rollback) MODE=rollback ;;
        --from)     LOCAL_SOURCE=${2:?--from needs a path}; shift ;;
        --channel)  CHANNEL=${2:?--channel needs a branch}; shift ;;
        -h|--help)  sed -n '2,16p' "${BASH_SOURCE[0]}" | sed 's/^# \?//'; exit 0 ;;
        *) die "unknown argument: $1" ;;
    esac
    shift
done

profile="$CONFIG_DIR/profiles/default/shell.json"
config_get() {
    [ -f "$profile" ] || { printf '%s' "$2"; return; }
    local v
    v=$(jq -r "$1 // empty" "$profile" 2>/dev/null)
    printf '%s' "${v:-$2}"
}

[ -n "$CHANNEL" ]      || CHANNEL=$(config_get '.update.channel' 'main')
[ -n "$LOCAL_SOURCE" ] || LOCAL_SOURCE=$(config_get '.update.localSource' '')
# Where to update from, most specific first:
#
#   1. update.remote in the configuration
#   2. the checkout's own origin -- a clone should update from where it came
#      from, and this is also the only URL guaranteed to work for a private
#      repository, since branding.json carries the public HTTPS one
#   3. the URL in branding.json
REMOTE=$(config_get '.update.remote' '')
if [ -z "$REMOTE" ] && git -C "$REPO_ROOT" remote get-url origin >/dev/null 2>&1; then
    REMOTE=$(git -C "$REPO_ROOT" remote get-url origin)
fi
[ -n "$REMOTE" ] || REMOTE=$REPO_FETCH

STATE_FILE="$STATE_DIR/update-state.json"

# ------------------------------------------------------------------ rollback

if [ "$MODE" = rollback ]; then
    [ -f "$STATE_FILE" ] || die "no update has been recorded; nothing to roll back to"
    prev=$(jq -r '.previousCommit // empty' "$STATE_FILE")
    [ -n "$prev" ] || die "the recorded update has no commit to return to"

    log_step "returning to $prev"
    git -C "$REPO_ROOT" checkout --quiet "$prev" || die "could not check out $prev"

    prof_backup=$(jq -r '.profileBackup // empty' "$STATE_FILE")
    if [ -n "$prof_backup" ] && [ -f "$prof_backup" ]; then
        cp -a "$prof_backup" "$profile"
        log_info "configuration restored from $prof_backup"
    fi

    "$REPO_ROOT/scripts/install.sh" --link >/dev/null || die "reinstall failed"
    if session_available; then
        systemctl --user restart "$SYSTEMD_UNIT" 2>/dev/null || true
    else
        log_info "no session: not restarting the shell"
    fi
    log_step "rolled back"
    exit 0
fi

# -------------------------------------------------------------------- source

is_git=0
git -C "$REPO_ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1 && is_git=1

if [ -n "$LOCAL_SOURCE" ]; then
    [ -d "$LOCAL_SOURCE" ] || die "local source is not a directory: $LOCAL_SOURCE"
    [ -f "$LOCAL_SOURCE/branding.json" ] || die "$LOCAL_SOURCE does not look like a checkout of this project"
    log_step "source: $LOCAL_SOURCE (local)"
else
    [ "$is_git" = 1 ] || die "not a git checkout and no local source configured; set update.localSource or use --from"
    log_step "source: $REMOTE ($CHANNEL)"
fi

# --------------------------------------------------------------------- check

if [ "$MODE" = check ]; then
    if [ -n "$LOCAL_SOURCE" ]; then
        log_info "would install from $LOCAL_SOURCE"
        diff -rq --exclude=.git "$REPO_ROOT/shell" "$LOCAL_SOURCE/shell" 2>/dev/null | head -20 \
            || log_info "shell trees are identical"
        exit 0
    fi

    # Distinguish the three ways this fails, because "could not reach" sends
    # someone looking at their network when the branch simply does not exist yet.
    if ! git -C "$REPO_ROOT" ls-remote --exit-code "$REMOTE" >/dev/null 2>&1; then
        die "cannot reach $REMOTE (network, credentials, or the repository does not exist)"
    fi
    if ! git -C "$REPO_ROOT" ls-remote --exit-code --heads "$REMOTE" "$CHANNEL" >/dev/null 2>&1; then
        log_warn "$REMOTE has no branch '$CHANNEL' yet"
        log_info "nothing to update from; push this branch first, or use --from <path>"
        exit 0
    fi
    git -C "$REPO_ROOT" fetch --quiet "$REMOTE" "$CHANNEL" || die "fetch from $REMOTE failed"

    behind=$(git -C "$REPO_ROOT" rev-list --count HEAD..FETCH_HEAD 2>/dev/null || echo 0)
    if [ "${behind:-0}" -eq 0 ]; then
        log_step "already up to date"
    else
        log_step "$behind commit(s) available"
        git -C "$REPO_ROOT" log --oneline HEAD..FETCH_HEAD | sed 's/^/  /'
    fi
    exit 0
fi

# ------------------------------------------------------------------ preflight

log_step "preflight"
"$REPO_ROOT/scripts/preflight.sh" >/dev/null 2>&1 \
    || die "preflight failed; run '$ALIAS preflight' to see why"

# Uncommitted work is the user's, and an update would either destroy it or
# refuse halfway through. Better to stop before anything has happened.
if [ "$is_git" = 1 ] && [ -z "$LOCAL_SOURCE" ]; then
    if [ -n "$(git -C "$REPO_ROOT" status --porcelain)" ]; then
        die "the checkout has uncommitted changes; commit or stash them first"
    fi
fi

# ------------------------------------------------------------------- snapshot

snapshot_create "before-update" >/dev/null || die "could not take a restore point; refusing to update"

mkdir -p "$STATE_DIR/profile-backups"
prof_backup=""
if [ -f "$profile" ]; then
    prof_backup="$STATE_DIR/profile-backups/$(date +%Y%m%d-%H%M%S)-before-update.json"
    cp -a "$profile" "$prof_backup"
fi

previous_commit=""
[ "$is_git" = 1 ] && previous_commit=$(git -C "$REPO_ROOT" rev-parse HEAD)
previous_version=$(cat "$REPO_ROOT/VERSION" 2>/dev/null || echo "0.0.0")

jq -n --arg c "$previous_commit" --arg v "$previous_version" --arg p "$prof_backup" \
      --arg t "$(date -Is)" \
      '{previousCommit: $c, previousVersion: $v, profileBackup: $p, at: $t}' \
      > "$STATE_FILE"

# ---------------------------------------------------------------------- apply

log_step "applying"
if [ -n "$LOCAL_SOURCE" ]; then
    # Only the parts that make up an install. Copying the whole tree would drag
    # in the source checkout's git history and state.
    for d in shell config theme plasma bin share scripts; do
        [ -d "$LOCAL_SOURCE/$d" ] || continue
        rm -rf "${REPO_ROOT:?}/$d"
        cp -a "$LOCAL_SOURCE/$d" "$REPO_ROOT/$d"
    done
    for f in branding.json VERSION Makefile; do
        [ -f "$LOCAL_SOURCE/$f" ] && cp -a "$LOCAL_SOURCE/$f" "$REPO_ROOT/$f"
    done
else
    git -C "$REPO_ROOT" ls-remote --exit-code --heads "$REMOTE" "$CHANNEL" >/dev/null 2>&1 \
        || die "$REMOTE has no branch '$CHANNEL'"
    git -C "$REPO_ROOT" fetch --quiet "$REMOTE" "$CHANNEL" || die "fetch from $REMOTE failed"
    git -C "$REPO_ROOT" merge --ff-only FETCH_HEAD || die "cannot fast-forward; the checkout has diverged from $CHANNEL"
fi

new_version=$(cat "$REPO_ROOT/VERSION" 2>/dev/null || echo "0.0.0")

# -------------------------------------------------------------------- migrate

# Configuration migrations run inside the shell when it next reads the profile,
# because that is the only place that knows the schema. What matters here is
# that a migration exists for the jump, so the shell is not asked to make one up.
shipped_version=$(jq -r '.schemaVersion // 1' "$REPO_ROOT/config/defaults/shell.json" 2>/dev/null || echo 1)
current_version=$(jq -r '.schemaVersion // 1' "$profile" 2>/dev/null || echo "$shipped_version")

if [ "$current_version" -lt "$shipped_version" ]; then
    log_step "configuration schema $current_version -> $shipped_version"
    v=$((current_version + 1))
    while [ "$v" -le "$shipped_version" ]; do
        if ! ls "$REPO_ROOT"/config/migrations/"$(printf '%03d' "$v")"-*.js >/dev/null 2>&1; then
            log_error "no migration for schema version $v"
            log_error "the shell would refuse to load this configuration"
            "$0" --rollback
            exit 1
        fi
        v=$((v + 1))
    done
    log_info "migrations present for every step; the shell applies them on next read"
fi

# --------------------------------------------------------------------- verify

log_step "verifying"
"$REPO_ROOT/scripts/gen-branding.sh"     >/dev/null || true
"$REPO_ROOT/scripts/gen-qmldir.sh"       >/dev/null || true
"$REPO_ROOT/scripts/gen-widget-index.sh" >/dev/null || true

if ! "$REPO_ROOT/scripts/lint-qml.sh" >/dev/null 2>&1; then
    log_error "the new version does not pass its own QML lint"
    "$0" --rollback
    exit 1
fi

"$REPO_ROOT/scripts/install.sh" --link >/dev/null || {
    log_error "install failed"
    "$0" --rollback
    exit 1
}

# --------------------------------------------------------------------- restart

if ! session_available; then
    log_info "no session: not restarting the shell"
elif systemctl --user is-active "$SYSTEMD_UNIT" >/dev/null 2>&1; then
    log_step "restarting"
    systemctl --user restart "$SYSTEMD_UNIT"
    sleep 3
    if ! systemctl --user is-active "$SYSTEMD_UNIT" >/dev/null 2>&1; then
        log_error "the shell did not come back up"
        "$0" --rollback
        exit 1
    fi
fi

log_step "updated $previous_version -> $new_version"
log_info "roll back with: $ALIAS update --rollback"

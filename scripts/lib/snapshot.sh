# shellcheck shell=bash
# Restore points.
#
# Three tiers, of which only Tier 0 is guaranteed:
#
#   0  our own archive of the protected set     no root, no btrfs, always
#   1  a btrfs snapshot of /home                needs btrfs + root
#   2  a snapper snapshot of /                  needs a snapper config + root
#
# Tier 0 is the contract: if it cannot be written, an install must not start.
# It needs no privileges and no particular filesystem, so it works on any
# machine. Tiers 1 and 2 are extra safety and never a substitute -- and both
# are only ever *suggested*, never taken automatically, because silently
# changing a machine's snapshot policy is precisely the surprise this whole
# mechanism exists to prevent.
#
# Requires brand.sh, log.sh, protected.sh.

# Deliberately NOT inside STATE_DIR. The state directory is part of what a
# snapshot captures and therefore part of what a restore overwrites, so an
# archive kept inside it destroys itself the moment it is used.
snapshot_root() { printf '%s/%s-snapshots' "$XDG_STATE_HOME" "$SLUG"; }

# Nothing in this project ever deletes a snapshot.
#
# Not on restore, not on uninstall, not to prune old ones, not to reclaim
# space. A restore point is worthless if the software that might need it is
# also allowed to remove it, and the one time an earlier version deleted its
# own archive it took a user's configuration with it. Snapshots are removed
# only when the user asks, through `snapshot remove` or `snapshot prune`.
#
# This is the guard that enforces it: every delete path checks it first.
snapshot_is_store_path() {
    local path=$1 root
    root=$(snapshot_root)
    case "$path" in
        "$root"|"$root"/*) return 0 ;;
        *) return 1 ;;
    esac
}

# Refuses to delete anything inside the snapshot store. Used everywhere this
# project removes a path, so the rule cannot be forgotten at one call site.
snapshot_safe_rm() {
    local path=$1
    if snapshot_is_store_path "$path"; then
        log_warn "refusing to delete inside the snapshot store: $path"
        return 1
    fi
    rm -rf "$path"
}

# --- tier detection -------------------------------------------------------

snapshot_home_is_btrfs() {
    [ "$(findmnt -no FSTYPE --target "$HOME" 2>/dev/null)" = "btrfs" ]
}

snapshot_snapper_configs() {
    command -v snapper >/dev/null 2>&1 || return 1
    ls /etc/snapper/configs/ 2>/dev/null
}

snapshot_report_tiers() {
    log_info "restore tiers available here:"
    log_info "  tier 0  our own archive             yes (always)"

    if snapshot_home_is_btrfs; then
        log_info "  tier 1  btrfs snapshot of \$HOME     yes, with root"
    else
        log_info "  tier 1  btrfs snapshot of \$HOME     no ($HOME is not btrfs)"
    fi

    local configs
    if configs=$(snapshot_snapper_configs) && [ -n "$configs" ]; then
        log_info "  tier 2  snapper snapshot of /       yes, with root (configs: $(echo "$configs" | tr '\n' ' '))"
    else
        log_info "  tier 2  snapper snapshot of /       no (no snapper config)"
    fi
}

# Printed, never run. Rolling back a subvolume is the user's decision.
snapshot_suggest_commands() {
    echo
    log_info "to take the optional tiers yourself, before installing:"
    if snapshot_home_is_btrfs; then
        log_info "  sudo btrfs subvolume snapshot -r $HOME $HOME/.snapshots/${SLUG}-preinstall-\$(date +%s)"
        if ! [ -d "$HOME/.snapshots" ]; then
            log_info "  (that needs $HOME/.snapshots to exist and \$HOME to be its own subvolume)"
        fi
    fi
    if snapshot_snapper_configs >/dev/null 2>&1; then
        log_info "  sudo snapper -c root create -d '${SLUG} pre-install'"
    fi
}

# --- tier 0 ---------------------------------------------------------------

# Copies a file or directory, skipping the snapshot store itself.
#
# The state directory is part of what a snapshot captures, and the snapshots
# live inside it -- so a plain recursive copy would try to copy the archive
# into itself. tar is used rather than cp because cp has no exclusion.
_snapshot_copy() {
    local src=$1 dest=$2

    if [ -f "$src" ]; then
        cp -a "$src" "$dest"
        return
    fi

    mkdir -p "$dest"
    tar -C "$(dirname "$src")" -cf - \
        --exclude="$(basename "$src")/*-snapshots" \
        --exclude="$(basename "$src")/snapshots" \
        "$(basename "$src")" 2>/dev/null \
      | tar -C "$(dirname "$dest")" -xf - 2>/dev/null
}

# Writes an archive of the protected set plus a manifest of what it contains.
# Echoes the snapshot directory on success.
snapshot_create() {
    local label=${1:-manual}
    # Two snapshots taken in the same second with the same label would share a
    # directory and merge into each other -- a restore point that is quietly
    # half of one state and half of another is worse than no restore point.
    local base dir n
    base="$(snapshot_root)/$(date +%Y%m%d-%H%M%S)-${label}"
    dir=$base
    n=2
    while [ -e "$dir" ]; do dir="$base-$n"; n=$((n + 1)); done

    mkdir -p "$dir/files" || { log_error "cannot create $dir"; return 1; }

    local manifest="$dir/manifest.txt"
    : > "$manifest"

    local path rel
    while IFS= read -r path; do
        [ -n "$path" ] || continue
        [ -e "$path" ] || continue
        rel=${path#"$HOME"/}
        mkdir -p "$dir/files/$(dirname "$rel")"
        _snapshot_copy "$path" "$dir/files/$rel" || {
            log_error "could not capture $path"
            return 1
        }
        printf '%s\n' "$path" >> "$manifest"
    done < <(protected_files; protected_dirs; owned_paths)

    {
        printf 'slug=%s\n' "$SLUG"
        printf 'version=%s\n' "$VERSION"
        printf 'label=%s\n' "$label"
        printf 'created=%s\n' "$(date -Is)"
        printf 'home=%s\n' "$HOME"
    } > "$dir/meta"

    log_step "snapshot: $dir ($(wc -l < "$manifest") path(s))"
    printf '%s\n' "$dir"
}

snapshot_latest() {
    local root
    root=$(snapshot_root)
    [ -d "$root" ] || return 1
    # Names begin with a sortable timestamp, so the last one is the newest.
    ls -1 "$root" 2>/dev/null | sort | tail -1 | sed "s|^|$root/|"
}

# Restores a snapshot.
#
# Two rules learned the hard way, after an earlier version deleted a user's
# KDE configuration:
#
#   1. Read the manifest into memory first. The previous version re-read it
#      from disk on every iteration, so once the restore had overwritten the
#      directory the archive lived in, every subsequent lookup failed -- and a
#      failed lookup meant "not in the snapshot", which meant "delete".
#
#   2. Only ever delete paths this project owns. Restoring KDE's files means
#      putting their contents back, not removing files that appeared since. A
#      restore that leaves an extra file behind is a nuisance; one that deletes
#      the wrong file is unrecoverable, and the asymmetry decides the design.
snapshot_restore() {
    local dir=$1
    [ -d "$dir/files" ]        || { log_error "not a snapshot: $dir"; return 1; }
    [ -s "$dir/manifest.txt" ] || { log_error "snapshot has no manifest, refusing to restore: $dir"; return 1; }

    # Read once, up front. Nothing below touches the archive again.
    local manifest
    manifest=$(cat "$dir/manifest.txt") || { log_error "cannot read manifest"; return 1; }
    [ -n "$manifest" ] || { log_error "manifest is empty, refusing to restore"; return 1; }

    # Stage the archive somewhere the restore cannot overwrite, so restoring a
    # path that contains the archive is harmless.
    local staging
    staging=$(mktemp -d) || { log_error "cannot create staging directory"; return 1; }
    cp -a "$dir/files/." "$staging/" || { rm -rf "$staging"; log_error "cannot stage archive"; return 1; }

    local path rel restored=0 removed=0 skipped=0

    while IFS= read -r path; do
        [ -n "$path" ] || continue
        if snapshot_is_store_path "$path"; then
            log_debug "skipping the snapshot store itself: $path"
            continue
        fi
        rel=${path#"$HOME"/}
        [ -e "$staging/$rel" ] || continue

        mkdir -p "$(dirname "$path")"

        if [ -f "$staging/$rel" ]; then
            cp -a "$staging/$rel" "$path"
        else
            # Directories are merged, not replaced. Replacing one wholesale
            # would delete anything added inside it since the snapshot -- a
            # colour scheme or look-and-feel package the user installed in the
            # meantime, which has nothing to do with us. Our own additions are
            # removed by the ledger, which knows what we put there; guessing
            # from absence is how the wrong things get deleted.
            mkdir -p "$path"
            cp -a "$staging/$rel/." "$path/"
        fi
        restored=$((restored + 1))
    done <<< "$manifest"

    # Paths we own that did not exist when the snapshot was taken are ours and
    # are removed. Nothing outside owned_paths is ever deleted.
    #
    # Except the configuration directory, which is what the user wrote.
    #
    # "Not in the manifest" does not mean "added since". The oldest snapshots
    # were taken before the configuration directory was captured at all, so
    # restoring one read its absence as ours-to-delete and removed every
    # profile the user had -- on a command they ran to *recover* settings. An
    # old snapshot cannot say what the configuration looked like, and a restore
    # that deletes more than it restores is not a restore.
    #
    # The state directory is not exempt and should not be: it is ours and
    # derived, and the ledger in it must not survive to claim ownership of
    # files that have just been put back. What used to be lost with it was the
    # profile backups, and those are written into the configuration directory
    # as profiles now, which is the half of this that makes the rule safe.
    while IFS= read -r path; do
        [ -n "$path" ] || continue
        [ -e "$path" ] || continue
        if [ "$path" = "$CONFIG_DIR" ] && ! grep -qxF -- "$path" <<< "$manifest"; then
            log_warn "this snapshot predates $path being captured; leaving your configuration as it is"
            continue
        fi
        if ! grep -qxF -- "$path" <<< "$manifest"; then
            snapshot_safe_rm "$path" && removed=$((removed + 1))
        fi
    done < <(owned_paths)

    # Anything else that appeared since is reported, not deleted.
    while IFS= read -r path; do
        [ -n "$path" ] || continue
        [ -e "$path" ] || continue
        if ! grep -qxF -- "$path" <<< "$manifest"; then
            log_warn "created since the snapshot, left in place: $path"
            skipped=$((skipped + 1))
        fi
    done < <(protected_files; protected_dirs)

    rm -rf "$staging"
    log_step "restored $restored path(s), removed $removed of ours, left $skipped in place"
}

# --- removal: user-invoked only -------------------------------------------

snapshot_list() {
    local root d
    root=$(snapshot_root)
    [ -d "$root" ] || { log_info "no snapshots"; return 0; }

    local found=0
    for d in "$root"/*/; do
        [ -d "$d" ] || continue
        found=1
        printf '%-34s %-26s %s path(s)  %s\n' \
            "$(basename "$d")" \
            "$(sed -n 's/^created=//p' "$d/meta" 2>/dev/null)" \
            "$(wc -l < "$d/manifest.txt" 2>/dev/null || echo '?')" \
            "$(du -sh "$d" 2>/dev/null | cut -f1)"
    done
    [ "$found" = 1 ] || log_info "no snapshots"
}

# Removes one snapshot by name. The only place a snapshot is ever deleted,
# and it is reached only from an explicit command.
snapshot_remove() {
    local name=$1 root dir
    root=$(snapshot_root)
    dir="$root/$(basename "$name")"

    [ -d "$dir" ] || { log_error "no such snapshot: $name"; return 1; }
    # Removing the oldest means losing the pre-install state, which is the one
    # most likely to be wanted and the least likely to be missed until then.
    local oldest
    oldest=$(ls -1 "$root" 2>/dev/null | sort | head -1)
    if [ "$(basename "$dir")" = "$oldest" ]; then
        log_warn "this is the oldest snapshot -- usually the pre-install state"
    fi

    rm -rf "$dir"
    log_step "removed $dir"
}

# Removes all but the newest N. Never runs on its own.
snapshot_prune() {
    local keep=${1:-5} root
    root=$(snapshot_root)
    [ -d "$root" ] || { log_info "no snapshots"; return 0; }

    case "$keep" in ''|*[!0-9]*) log_error "keep must be a number"; return 1 ;; esac
    [ "$keep" -ge 1 ] || { log_error "keep must be at least 1"; return 1; }

    local total
    total=$(ls -1 "$root" 2>/dev/null | wc -l)
    [ "$total" -gt "$keep" ] || { log_info "$total snapshot(s), keeping $keep: nothing to do"; return 0; }

    local n
    while IFS= read -r n; do
        rm -rf "$root/$n"
        log_info "  removed $n"
    done < <(ls -1 "$root" | sort | head -n "$((total - keep))")

    log_step "pruned $((total - keep)), kept $keep"
}

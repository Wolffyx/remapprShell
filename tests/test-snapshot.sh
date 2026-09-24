#!/usr/bin/env bash
# Tests snapshot and restore inside a throwaway HOME.
#
# This exists because an earlier version of snapshot_restore deleted a real
# user's KDE configuration. Destructive code must be exercised against a fake
# home, never a real one -- so this test builds one, populates it, and asserts
# on the result.
set -uo pipefail

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
source "$REPO_ROOT/tests/lib/harness.sh"
harness_init
source "$REPO_ROOT/scripts/lib/protected.sh"
source "$REPO_ROOT/scripts/lib/snapshot.sh"

# A snapshot is named for the second it was taken in, and the order of those
# names is what pruning and "newest" read -- so the cases below needed a
# different second each, and slept for one between snapshots: nine seconds of
# a suite that does nothing else slow. This `date` answers that one format
# with a clock that moves on a second per call, and passes anything else to
# the real one.
REAL_DATE=$(command -v date)
cat > "$FAKEBIN/date" <<STUB
#!/usr/bin/env bash
if [ "\$*" = "+%Y%m%d-%H%M%S" ]; then
    n=\$(( \$(cat "$SANDBOX/clock" 2>/dev/null || echo 0) + 1 ))
    printf '%s' "\$n" > "$SANDBOX/clock"
    printf '20260101-%06d\n' "\$n"
    exit 0
fi
exec "$REAL_DATE" "\$@"
STUB
chmod +x "$FAKEBIN/date"

# --- a plausible KDE home -------------------------------------------------

printf '[General]\noriginal=yes\n' > "$XDG_CONFIG_HOME/kdeglobals"
printf '[Shell]\nShellPackage=something\n' > "$XDG_CONFIG_HOME/plasmashellrc"
printf '[Containments][1]\nplugin=org.kde.panel\n' > "$XDG_CONFIG_HOME/plasma-test.desktop-appletsrc"
mkdir -p "$XDG_CONFIG_HOME/autostart"
printf 'x\n' > "$XDG_CONFIG_HOME/autostart/someapp.desktop"
mkdir -p "$PLASMA_LNF_DIR/preexisting.lookandfeel"
printf 'theirs\n' > "$PLASMA_LNF_DIR/preexisting.lookandfeel/metadata.json"
mkdir -p "$CONFIG_DIR"
printf '{"schemaVersion":1}\n' > "$CONFIG_DIR/state.json"

echo "== snapshot =="
snap=$(snapshot_create preinstall) || { echo "snapshot_create failed" >&2; exit 1; }
check "snapshot directory exists" "$([ -d "$snap" ] && echo yes)" "yes"
check "snapshot store is outside the state dir" \
      "$(case "$(snapshot_root)" in "$STATE_DIR"/*) echo inside ;; *) echo outside ;; esac)" "outside"

echo "== modify, the way the theme layer will =="
printf '[General]\noriginal=no\nplanted=yes\n' > "$XDG_CONFIG_HOME/kdeglobals"
printf '[KSplash]\nTheme=planted\n' > "$XDG_CONFIG_HOME/ksplashrc"          # did not exist before
mkdir -p "$PLASMA_LNF_DIR/ours.lookandfeel"
printf 'ours\n' > "$PLASMA_LNF_DIR/ours.lookandfeel/metadata.json"
mkdir -p "$STATE_DIR"
printf 'junk\n' > "$STATE_DIR/ledger.json"                                   # ours, created since
rm -f "$XDG_CONFIG_HOME/autostart/someapp.desktop"                           # a deletion to undo

echo "== restore =="
snapshot_restore "$snap" || { echo "snapshot_restore failed" >&2; exit 1; }

echo "== assertions =="
check "modified file restored"          "$(grep -c 'original=yes' "$XDG_CONFIG_HOME/kdeglobals")" "1"
check "planted key gone"                "$(grep -c 'planted' "$XDG_CONFIG_HOME/kdeglobals")" "0"
check "deleted file is back"            "$([ -e "$XDG_CONFIG_HOME/autostart/someapp.desktop" ] && echo yes)" "yes"
check "pre-existing look-and-feel kept" "$([ -e "$PLASMA_LNF_DIR/preexisting.lookandfeel/metadata.json" ] && echo yes)" "yes"

# The blast-radius rule: a KDE file created since is left alone, because
# deleting the wrong file is unrecoverable while leaving one is a nuisance.
check "KDE file created since is NOT deleted" "$([ -e "$XDG_CONFIG_HOME/ksplashrc" ] && echo yes)" "yes"
check "our own stray state IS removed"        "$([ -e "$STATE_DIR/ledger.json" ] && echo yes || echo no)" "no"

# The case that destroyed a real look-and-feel directory: a package installed
# after the snapshot lives inside a captured directory, and must survive.
check "package added to a captured dir survives" \
      "$([ -e "$PLASMA_LNF_DIR/ours.lookandfeel/metadata.json" ] && echo yes)" "yes"

# The failure that caused real damage: the archive must survive its own use.
check "snapshot survived being restored"  "$([ -s "$snap/manifest.txt" ] && echo yes)" "yes"
check "snapshot can be restored twice"    "$(snapshot_restore "$snap" >/dev/null 2>&1 && echo yes)" "yes"

echo "== snapshots are never deleted by us =="

# The store must survive a restore that names it, and every delete path must
# refuse to touch it. This is the rule that an earlier version broke.
check "store path is recognised" \
      "$(snapshot_is_store_path "$(snapshot_root)/anything" && echo yes)" "yes"
check "unrelated path is not"    \
      "$(snapshot_is_store_path "$XDG_CONFIG_HOME/kdeglobals" && echo yes || echo no)" "no"

snapshot_safe_rm "$(snapshot_root)/$(basename "$snap")" >/dev/null 2>&1
check "safe_rm refuses inside the store" "$([ -d "$snap" ] && echo yes)" "yes"

count_before=$(ls -1 "$(snapshot_root)" | wc -l)
snapshot_restore "$snap" >/dev/null 2>&1
check "restore leaves every snapshot in place" "$(ls -1 "$(snapshot_root)" | wc -l)" "$count_before"

echo "== removal is possible, but only when asked =="
extra=$(snapshot_create disposable)
check "a second snapshot exists" "$([ -d "$extra" ] && echo yes)" "yes"
snapshot_remove "$(basename "$extra")" >/dev/null 2>&1
check "explicit remove works" "$([ -d "$extra" ] && echo yes || echo no)" "no"

for i in 1 2 3; do snapshot_create "p$i" >/dev/null; done

# `keep` is a floor, not a target. The oldest snapshot is the pre-install
# state -- the only one that can put the machine back the way it was found --
# and pruning never takes it, so the newest N plus that one is what remains.
oldest=$(ls -1 "$(snapshot_root)" | sort | head -1)
snapshot_prune 2 >/dev/null 2>&1
check "prune keeps the newest N"      "$(ls -1 "$(snapshot_root)" | sort | tail -2 | wc -l)" "2"
check "and never the oldest"          "$([ -d "$(snapshot_root)/$oldest" ] && echo yes)" "yes"

echo "== locking =="
for i in 4 5 6; do snapshot_create "q$i" >/dev/null; done
keepme=$(ls -1 "$(snapshot_root)" | sort | sed -n '2p')     # not the oldest
snapshot_lock "$keepme" on >/dev/null 2>&1
check "a locked snapshot reads as locked" \
    "$(snapshot_is_locked "$(snapshot_root)/$keepme" && echo yes || echo no)" "yes"
snapshot_prune 1 >/dev/null 2>&1
check "pruning does not take a locked one" "$([ -d "$(snapshot_root)/$keepme" ] && echo yes)" "yes"
snapshot_lock "$keepme" off >/dev/null 2>&1
check "unlock lets it go"                  "$(snapshot_is_locked "$(snapshot_root)/$keepme" && echo yes || echo no)" "no"
snapshot_prune 1 >/dev/null 2>&1
check "and then pruning takes it"          "$([ -d "$(snapshot_root)/$keepme" ] && echo yes || echo no)" "no"
check "prune refuses keep=0" "$(snapshot_prune 0 >/dev/null 2>&1 && echo ran || echo refused)" "refused"

echo "== fail-closed =="
broken=$(mktemp -d); mkdir -p "$broken/files"; : > "$broken/manifest.txt"
check "empty manifest is refused" "$(snapshot_restore "$broken" >/dev/null 2>&1 && echo restored || echo refused)" "refused"
check "nothing deleted after refusal" "$([ -e "$XDG_CONFIG_HOME/kdeglobals" ] && echo yes)" "yes"
rm -rf "$broken"

echo
echo "== what a label may make of a directory name =="
# The label is part of a directory name: a slash made directories inside the
# root, `..` one outside it, and a leading dash a name that reads as a flag.
name_of() { basename "$(snapshot_create "$1")" | sed -E 's/^[0-9]{8}-[0-9]{6}-//'; }
check "a slash is a dash"           "$(name_of 'a/b')" "a-b"
check "nothing climbs out"          "$(name_of '../../escape')" "escape"
check "no leading dash"             "$(name_of '--label')" "label"
check "spaces are kept"             "$(name_of 'My shell setup')" "My shell setup"
check "nothing left is manual"      "$(name_of '///')" "manual"
check "every one inside the root"   "$(find "$(snapshot_root)" -mindepth 1 -maxdepth 1 -type d | wc -l)" \
                                    "$(find "$(snapshot_root)" -name manifest.txt | wc -l)"

echo "== the CLI takes --label =="
cli() { "$REPO_ROOT/scripts/snapshot.sh" create "$@" >/dev/null 2>&1; }
newest() { ls "$(snapshot_root)" | sort | tail -1 | sed -E 's/^[0-9]{8}-[0-9]{6}-//'; }
cli --label flagged;            check "--label X"     "$(newest)" "flagged"
cli --label=equals;             check "--label=X"     "$(newest)" "equals"
cli plain;                      check "a bare label"  "$(newest)" "plain"
cli --bogus;                    check "an unknown flag is refused" "$?" "1"

# `snapshot create` read `snapshots.keep` through config.sh, which it never
# sourced. The lookup failed out of sight, the setting read as 0, and a machine
# told to keep two restore points went on keeping every one.
echo "== snapshots.keep prunes after a create =="
rm -rf "$(snapshot_root)"
mkdir -p "$CONFIG_DIR/profiles/default"
for l in k1 k2 k3; do cli "$l"; done
check "unset, nothing is pruned"   "$(ls -1 "$(snapshot_root)" | wc -l)" "3"
printf '{"snapshots": {"keep": 2}}\n' > "$CONFIG_DIR/profiles/default/shell.json"
cli k4
kept=$(ls -1 "$(snapshot_root)" | sed -E 's/^[0-9]{8}-[0-9]{6}-//' | paste -sd' ')
check "keep=2 prunes on create"    "$kept" "k1 k3 k4"
rm -f "$CONFIG_DIR/profiles/default/shell.json"

harness_done

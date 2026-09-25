#!/usr/bin/env bash
# Tests `rmpr ask` inside a throwaway HOME, with every provider faked.
#
# The thing under test is the boundary: nothing may leave without consent,
# what leaves must be the redacted bundle and nothing else, and the clipboard
# and a local model must not ask for a permission they do not need.
set -uo pipefail

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
source "$REPO_ROOT/tests/lib/harness.sh"
harness_init

# --- fakes on PATH, each recording what it was handed ------------------------
cat > "$FAKEBIN/wl-copy" <<F
#!/usr/bin/env bash
cat > "$SANDBOX/clipboard.txt"
F
cat > "$FAKEBIN/claude" <<F
#!/usr/bin/env bash
printf '%s' "\$1" > "$SANDBOX/claude-prompt.txt"
F
cat > "$FAKEBIN/fake-term" <<F
#!/usr/bin/env bash
# a terminal emulator: records the command, then runs it so the fake claude
# gets its argument, the way a real one would
printf '%s\n' "\$@" > "$SANDBOX/term-args.txt"
shift   # -e
"\$@"
F
cat > "$FAKEBIN/fake-custom" <<F
#!/usr/bin/env bash
cp "\$1" "$SANDBOX/custom-got.txt"
F
cat > "$FAKEBIN/quickshell" <<F
#!/usr/bin/env bash
# the shell, answering only what ask.sh asks of it
case "\$*" in
    *"notifications at 0")
        printf '%s\n' '{"appName":"probe-app","summary":"Disk nearly full","body":"Only 1 GB left on $HOME/Videos","urgency":2,"when":1}' ;;
    *"ask open"*)
        [ -f "$SANDBOX/shell-running" ] || exit 1
        printf '%s\n' "\$*" > "$SANDBOX/ipc-open.txt" ;;
    *) exit 1 ;;
esac
F
chmod +x "$FAKEBIN"/*
# Only the fakes and a whitelist of system tools: a real `claude` anywhere on
# this machine's PATH must not stand in for the missing one, and the test that
# a missing program is refused is only a test if the program can be missing.
path_only bash sh jq cat wc cmp diff sed awk grep ls sort tail head date mktemp stat \
          chmod mkdir rm mv cp basename dirname tr printf setsid sleep seq id uname \
          env journalctl systemctl coredumpctl kreadconfig6 curl systemd-escape
export TERMINAL=fake-term
unset DISPLAY WAYLAND_DISPLAY

ASK="$REPO_ROOT/scripts/ask.sh"

mkdir -p "$(dirname "$profile")"
cat > "$profile" <<PROFILE
{
    "wallpaper": "$HOME/Pictures/holiday.png",
    "widgets": { "weather": { "apiToken": "sk-live-must-not-appear" } },
    "ai": { "enabled": true, "provider": "clipboard", "command": ["fake-custom", "%report"] }
}
PROFILE

# --- providers ---------------------------------------------------------------
json=$("$ASK" --providers --json 2>/dev/null)
check "providers is JSON"            "$(printf '%s' "$json" | jq -r 'type')" "array"
check "clipboard available"          "$(printf '%s' "$json" | jq -r '.[] | select(.id=="clipboard") | .available')" "true"
check "claude-code available"        "$(printf '%s' "$json" | jq -r '.[] | select(.id=="claude-code") | .available')" "true"
check "custom available"             "$(printf '%s' "$json" | jq -r '.[] | select(.id=="custom") | .available')" "true"
check "clipboard stays here"         "$(printf '%s' "$json" | jq -r '.[] | select(.id=="clipboard") | .leavesMachine')" "false"
check "claude-code leaves"           "$(printf '%s' "$json" | jq -r '.[] | select(.id=="claude-code") | .leavesMachine')" "true"

# --- --show: always allowed, always redacted ---------------------------------
"$ASK" --show > "$SANDBOX/show.txt" 2>/dev/null
check "show exits 0"                 "$?" "0"
present "show carries the question"  "$SANDBOX/show.txt" "Question:"
present "show carries the config"    "$SANDBOX/show.txt" "===== config.json ====="
absent  "no token in what is shown"  "$SANDBOX/show.txt" "sk-live-must-not-appear"
absent  "no home path in it"         "$SANDBOX/show.txt" "$HOME"
check "one report written"           "$(ls -1 "$STATE_DIR/diagnostics" | wc -l)" "1"

"$ASK" --show > /dev/null 2>&1
check "asking again reuses it"       "$(ls -1 "$STATE_DIR/diagnostics" | wc -l)" "1"

shown=$("$ASK" --show --json 2>/dev/null)
check "show --json names the report" "$(printf '%s' "$shown" | jq -r '.report')" "$(ls -1 "$STATE_DIR/diagnostics")"
check "and the provider from config" "$(printf '%s' "$shown" | jq -r '.provider')" "clipboard"

# --- clipboard: no consent needed ----------------------------------------------
"$ASK" >/dev/null 2>&1
check "clipboard send exits 0"       "$?" "0"
check "clipboard got the bundle"     "$(cmp -s "$SANDBOX/clipboard.txt" "$SANDBOX/show.txt" && echo same)" "same"
check "no consent recorded for it"   "$([ -f "$STATE_DIR/ai-consent.json" ] && echo yes || echo no)" "no"

# --- claude-code: nothing leaves without consent -------------------------------
"$ASK" --provider claude-code >/dev/null 2>"$SANDBOX/refused.txt"
check "refused without a terminal"   "$?" "1"
check "nothing sent"                 "$([ -f "$SANDBOX/claude-prompt.txt" ] && echo sent || echo no)" "no"
present "says how to read it first"  "$SANDBOX/refused.txt" "ask --show"

"$ASK" --provider claude-code --yes >/dev/null 2>&1
check "sent with --yes"              "$?" "0"
wait_for "$SANDBOX/claude-prompt.txt"
check "opened a terminal"            "$(head -1 "$SANDBOX/term-args.txt")" "-e"
# `claude "$(cat bundle)"` loses the final newline, as any $(...) does.
check "claude got the bundle"        "$(diff <(cat "$SANDBOX/claude-prompt.txt"; echo) "$SANDBOX/show.txt" >/dev/null && echo same)" "same"
check "consent recorded"             "$(jq -r 'has("claude-code")' "$STATE_DIR/ai-consent.json")" "true"
check "consent file is private"      "$(stat -c '%a' "$STATE_DIR/ai-consent.json")" "600"

rm -f "$SANDBOX/claude-prompt.txt"
"$ASK" --provider claude-code >/dev/null 2>&1
wait_for "$SANDBOX/claude-prompt.txt"
check "consent is remembered"        "$([ -f "$SANDBOX/claude-prompt.txt" ] && echo sent || echo no)" "sent"

"$ASK" --forget >/dev/null 2>&1
check "forget removes it"            "$([ -f "$STATE_DIR/ai-consent.json" ] && echo yes || echo no)" "no"

# With the shell running, a refusal becomes a window instead.
: > "$SANDBOX/shell-running"
"$ASK" --provider claude-code >/dev/null 2>&1
check "hands off to the shell"       "$?" "2"
check "on the very same report"      "$(awk '{print $NF}' "$SANDBOX/ipc-open.txt")" "$(ls -1 "$STATE_DIR/diagnostics")"

# --- the terminal: the one this desktop is set to use --------------------------
# Every terminal here is a stand-in that writes down what it was handed, then
# runs the command after its own options, as a real one would.
fake_terminal() {   # <name> <file its arguments go to>
    cat > "$FAKEBIN/$1" <<F
#!/usr/bin/env bash
printf '%s\n' "\$@" > "$2"
while [ \$# -gt 0 ] && [ "\$1" != -e ]; do shift; done
[ "\${1-}" = -e ] && shift
"\$@"
F
    chmod +x "$FAKEBIN/$1"
}

# KDE's choice first, before $TERMINAL, with the options it was given.
fake_terminal fake-kterm "$SANDBOX/kterm-args.txt"
printf '[General]\nTerminalApplication=fake-kterm --hold\n' > "$XDG_CONFIG_HOME/kdeglobals"
rm -f "$SANDBOX/claude-prompt.txt"
"$ASK" --provider claude-code --yes >/dev/null 2>&1
wait_for "$SANDBOX/claude-prompt.txt"
check "KDE's terminal, over \$TERMINAL"  "$(awk 'NR <= 3 {printf "%s%s", (NR > 1 ? " " : ""), $0}' "$SANDBOX/kterm-args.txt")" "--hold -e claude"
check "and the command ran in it"       "$([ -f "$SANDBOX/claude-prompt.txt" ] && echo sent || echo no)" "sent"

# One KDE names but this machine lacks is passed over, and said so.
printf '[General]\nTerminalApplication=not-installed-term\n' > "$XDG_CONFIG_HOME/kdeglobals"
rm -f "$SANDBOX/claude-prompt.txt" "$SANDBOX/term-args.txt"
"$ASK" --provider claude-code --yes >/dev/null 2>"$SANDBOX/err.txt"
wait_for "$SANDBOX/claude-prompt.txt"
present "a missing one is said"         "$SANDBOX/err.txt" "not-installed-term"
check "and \$TERMINAL is next"           "$(head -1 "$SANDBOX/term-args.txt")" "-e"
rm -f "$XDG_CONFIG_HOME/kdeglobals"

# xdg-terminal-exec next, before $TERMINAL, given the command as it is.
fake_terminal xdg-terminal-exec "$SANDBOX/xte-args.txt"
rm -f "$SANDBOX/claude-prompt.txt"
"$ASK" --provider claude-code --yes >/dev/null 2>&1
wait_for "$SANDBOX/claude-prompt.txt"
check "then xdg-terminal-exec"          "$(head -1 "$SANDBOX/xte-args.txt")" "claude"
rm -f "$FAKEBIN/xdg-terminal-exec"

# None of the three: no guessing, and a message that says what to set.
rm -f "$SANDBOX/claude-prompt.txt"
TERMINAL= "$ASK" --provider claude-code --yes >/dev/null 2>"$SANDBOX/err.txt"
check "no terminal is a failure"        "$?" "1"
present "that says where to choose one" "$SANDBOX/err.txt" "Default Applications"
check "and nothing ran"                 "$([ -f "$SANDBOX/claude-prompt.txt" ] && echo sent || echo no)" "no"

# In a scope of its own where one can be made: run by the shell, this is a
# process of the shell's service, and a terminal left there closes with the
# next restart of the shell. systemd-run is a stand-in too, writing down its
# own options and the program, then running it; `true` is the check whether
# a scope can be made at all.
cat > "$FAKEBIN/systemd-run" <<F
#!/usr/bin/env bash
opts=()
while [ \$# -gt 0 ] && [ "\$1" != -- ]; do opts+=("\$1"); shift; done
shift
printf '%s -- %s\n' "\${opts[*]}" "\$1" >> "$SANDBOX/scopes.txt"
"\$@"
F
chmod +x "$FAKEBIN/systemd-run"
rm -f "$SANDBOX/claude-prompt.txt"
"$ASK" --provider claude-code --yes >/dev/null 2>&1
wait_for "$SANDBOX/claude-prompt.txt"
check "a scope is tried, then made"     "$(awk '{printf "%s%s", (NR > 1 ? " " : ""), $NF}' "$SANDBOX/scopes.txt")" "true fake-term"
scope=$(tail -1 "$SANDBOX/scopes.txt")
contains "in app.slice, gone once done" "$scope" "--user --scope --slice=app.slice --collect --quiet --unit="
unit=${scope#*--unit=}; unit=${unit%% *}
check "named app-<slug>-<app>-<random>" "$([[ $unit =~ ^app-$(systemd-escape -- "$SLUG" | sed 's/\\/\\\\/g')-fake\\x2dterm-[0-9a-f]{16}\.scope$ ]] && echo yes || echo "$unit")" "yes"
check "and the command ran in it"       "$([ -f "$SANDBOX/claude-prompt.txt" ] && echo sent || echo no)" "sent"
rm -f "$FAKEBIN/systemd-run"

# --- custom: %report is the bundle path ----------------------------------------
"$ASK" --provider custom --yes >/dev/null 2>&1
check "custom exits 0"               "$?" "0"
check "custom got the bundle"        "$(cmp -s "$SANDBOX/custom-got.txt" "$SANDBOX/show.txt" && echo same)" "same"

# --- a notification, fetched from the shell and redacted -----------------------
"$ASK" --last-notification --show > "$SANDBOX/notif.txt" 2>/dev/null
check "notification ask exits 0"     "$?" "0"
present "the summary is in it"       "$SANDBOX/notif.txt" "Disk nearly full"
present "the app is in the question" "$SANDBOX/notif.txt" "probe-app"
absent  "the body's home path is not" "$SANDBOX/notif.txt" "$HOME"
present "but the rest of the body is" "$SANDBOX/notif.txt" "~/Videos"
check "a second report, for it"      "$(ls -1 "$STATE_DIR/diagnostics" | wc -l)" "2"

# --- a unit's journal ----------------------------------------------------------
"$ASK" --unit nonexistent-unit.service --show > "$SANDBOX/unit.txt" 2>/dev/null
check "unit ask exits 0"             "$?" "0"
present "unit part present"          "$SANDBOX/unit.txt" "===== unit.txt ====="
present "names the unit"             "$SANDBOX/unit.txt" "unit:   nonexistent-unit.service"

# --- the question survives a resend of the same report -------------------------
name=$(ls -1 "$STATE_DIR/diagnostics" | sort | tail -1)
"$ASK" --report "$name" --show > "$SANDBOX/resend.txt" 2>/dev/null
present "the unit question is kept"  "$SANDBOX/resend.txt" "The systemd user unit 'nonexistent-unit.service'"

# --- an unknown provider, and one that cannot run ------------------------------
"$ASK" --provider nothing >/dev/null 2>&1
check "unknown provider refused"     "$?" "1"
rm -f "$FAKEBIN/claude"
"$ASK" --provider claude-code --yes >/dev/null 2>"$SANDBOX/err.txt"
check "missing program refused"      "$?" "1"
present "and says why"               "$SANDBOX/err.txt" "not installed"

harness_done

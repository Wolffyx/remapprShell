# shellcheck shell=bash
# The privacy boundary, in shell.
#
# This exists as well as domain/diagnostics/Redact.qml because the crash
# reporter runs precisely when the shell is dead -- a QML function is no use at
# the moment it is most needed. Two implementations is a drift risk, so both are
# held to one corpus: tests/fixtures/redact-cases.json, run by test-redact.sh
# here and by tst_Redact.qml there. Change a rule in one and a test fails in the
# other.
#
# The rules, and why the order matters, are documented once in Redact.qml.
#
# Requires jq.

REDACT_SECRET_RE='token|key|password|secret|auth'
REDACT_MASK='<redacted>'
REDACT_USER_MASK='<user>'

# redact_json <home> <user>   -- JSON on stdin, redacted JSON on stdout.
redact_json() {
    local home=$1 user=$2

    # Keys are masked on the way down, before any string is examined: an entry
    # named `auth` loses its whole subtree, so nothing inside it is ever
    # reached. A value-only scrub would pass an object full of credentials
    # through untouched.
    jq --arg home "$home" --arg user "$user" \
       --arg mask "$REDACT_MASK" --arg umask "$REDACT_USER_MASK" \
       --arg re "$REDACT_SECRET_RE" '
        def scrub_text:
            # Home before username: the home path contains the username, and
            # replacing the username first leaves /home/<user>/... behind.
            (if ($home | length) > 0 then split($home) | join("~") else . end)
            | (if ($user | length) > 0 then split($user) | join($umask) else . end);

        def redact:
            if type == "object" then
                with_entries(
                    if (.key | test($re; "i")) then .value = $mask
                    else .value |= redact end
                )
            elif type == "array" then map(redact)
            elif type == "string" then scrub_text
            else . end;

        redact
    '
}

# redact_text [home] [user]   -- plain text on stdin, redacted text on stdout.
#
# For the journal tail, which is lines rather than JSON. Replacement is literal:
# sed and awk's gsub both take a regex, and a home directory containing a
# regex metacharacter would then either fail to match or match too much.
redact_text() {
    local home=${1:-$HOME} user=${2:-${USER:-$(id -un)}}
    awk -v home="$home" -v user="$user" -v umask="$REDACT_USER_MASK" '
        function literal_replace(s, needle, replacement,   out, at) {
            if (needle == "") return s;
            out = "";
            while ((at = index(s, needle)) > 0) {
                out = out substr(s, 1, at - 1) replacement;
                s = substr(s, at + length(needle));
            }
            return out s;
        }
        {
            # Home before username, for the same reason as in the JSON pass.
            $0 = literal_replace($0, home, "~");
            $0 = literal_replace($0, user, umask);
            print;
        }
    '
}

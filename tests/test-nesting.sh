#!/usr/bin/env bash
# What the nesting lint calls a loop in a loop, over a tree of small cases.
#
# The ones that must be found, in each language, and the ones that must not:
# a callback written as an expression, a comprehension, an elif, and an `if`
# inside a quoted awk or jq program or a heredoc -- which the first version
# counted, and found a nest twenty deep in a function with one loop.
set -uo pipefail

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
source "$REPO_ROOT/tests/lib/harness.sh"
harness_init --no-home

tree="$SANDBOX/tree"
mkdir -p "$tree"
git -C "$tree" init -q

put() {   # <path> <content>
    mkdir -p "$(dirname "$tree/$1")"
    printf '%s' "$2" > "$tree/$1"
    git -C "$tree" add "$1"
}

put braced.qml 'function a() {
    for (const x of y) {
        if (x) continue;
        for (let i = 0; i < 3; i++) {
            if (i) z();
        }
    }
}
'
put unbraced.js 'function b() {
    for (const x of y)
        for (const q of x)
            if (q)
                z(q);
}
'
put handler.qml 'Item {
    onX: for (const a of b) if (a) for (const c of a) if (c) f(c)
}
'
put siblings.qml 'function c() {
    for (const x of y) f(x);
    for (const q of z) { if (q) g(); }
}
'
put callback.qml 'function d() {
    for (const x of y) {
        x.items.forEach(i => { if (i) h(i); });
    }
}
'
put expression.qml 'function e() {
    for (const x of y) {
        if (x.items.some(i => i.ok)) h(x);
    }
}
'
put strings.qml 'function f() {
    const s = `a ${ {x: 1}.x } } for (;;) { if (1) }`;
    const r = /[/]for/g;
    for (const x of y) { if (x) g(); }
}
'
put allowed.qml 'function g() {
    // lint-nesting: allow -- each row, then each cell
    for (const r of rows) { for (const c of r) { if (c) h(c); } }
}
'
put nested.sh '#!/usr/bin/env bash
f() {
    for a in 1 2; do
        while read -r l; do
            if [ -n "$l" ]; then :; fi
        done
    done
}
'
put quoted.sh '#!/usr/bin/env bash
g() {
    for a in 1 2; do
        jq "if . then 1
            else 2 end" <<< "$a"
        awk '"'"'{ for (i = 1; i <= NF; i++) if ($i) print }'"'"'
        cat <<EOF
while true; do if x; then y; fi; done
EOF
    done
}
'
put nested.py 'def h():
    for a in b:
        if a:
            pass
        elif a > 1:
            for c in a:
                if c:
                    pass
'
put flat.py 'def i():
    for a in b:
        if a:
            pass
        elif a > 1:
            pass
        elif a > 2:
            pass
    return [q for q in r if q]
'

out=$(python3 "$REPO_ROOT/scripts/lib/nesting.py" "$tree")

found() {   # <path> -> "func: shape", or nothing
    awk -F'\t' -v p="$1" 'index($1, p ":") == 1 { print $2 ": " $3 }' <<< "$out"
}

check "a braced for in a for"              "$(found braced.qml)"     "a: for > for > if"
check "unbraced bodies"                    "$(found unbraced.js)"    "b: for > for > if"
check "a QML handler with no semicolons"   "$(found handler.qml)"    "(top level): for > if > for > if"
check "two loops side by side"             "$(found siblings.qml)"   ""
check "a callback with a body is a loop"   "$(found callback.qml)"   "d: for > each > if"
check "an expression callback is not"      "$(found expression.qml)" ""
check "templates and regexes are text"     "$(found strings.qml)"    ""
check "an allowed nest"                    "$(found allowed.qml)"    ""
check "shell: while in a for"              "$(found nested.sh)"      "f: for > while > if"
check "shell: awk, jq and heredocs"        "$(found quoted.sh)"      ""
check "python: a for under an elif"        "$(found nested.py)"      "h: for > if > for > if"
check "python: elifs and a comprehension"  "$(found flat.py)"        ""

# And the tree this lives in passes its own rule.
check "this tree is clean"                 "$(python3 "$REPO_ROOT/scripts/lib/nesting.py" "$REPO_ROOT")" ""

harness_done

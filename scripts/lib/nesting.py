#!/usr/bin/env python3
"""Loops nested in loops with a condition among them, for lint-nesting.sh.

Reads every tracked QML, JavaScript, C++, shell and Python file and prints one
line per outermost loop that holds such a nest:

    <path>:<line>\t<function>\t<shape>

where the shape is the deepest chain under it, e.g. "for > if > for > if".
A nest whose outermost loop carries `lint-nesting: allow`, on its line
or the one above, is not printed.

A loop is `for`, `while`, `do` and `until`, and in QML and JavaScript an
array method (`forEach`, `map`, `filter`, ...) whose callback has a body in
braces. One written as an expression -- `.some(a => a.id === id)` -- holds
no statement, so nothing can be nested in it, and it is not counted. Python's
comprehensions are not counted for the same reason, and an `elif` is the `if`
it continues, not one inside it.

Each language is read for what nests, not parsed in full: strings, comments,
regular expressions and heredocs are stepped over, and braces, `do`/`done`
and indentation followed. Good enough to find a nest; not a compiler.
"""
import ast
import os
import re
import subprocess
import sys

LOOPS = {"for", "while", "do", "until", "each"}
CONDS = {"if", "switch", "case"}
ITER_METHODS = {"forEach", "map", "filter", "some", "every", "reduce", "find",
                "findIndex", "flatMap"}
ALLOW = "lint-nesting: allow"


class Scan:
    def __init__(self):
        self.found = {}   # (path, line) -> (func, chain)

    def record(self, path, func, chain):
        kinds = [k for k, _ in chain]
        if sum(k in LOOPS for k in kinds) < 2 or not any(k in CONDS for k in kinds):
            return
        # Keyed by the outermost loop, which is where an allow goes: keyed
        # by the outermost statement, a nest under a script's top-level
        # `case "$cmd"` would be allowed for every command in it at once.
        key = (path, next(line for k, line in chain if k in LOOPS))
        if key not in self.found or len(chain) > len(self.found[key][1]):
            self.found[key] = (func, list(chain))


# ---- QML, JavaScript and C++ ----------------------------------------------

TOKEN = re.compile(r"""
  (?P<nl>\n)
 |(?P<ws>[ \t\r]+)
 |(?P<lc>//[^\n]*)
 |(?P<bc>/\*.*?\*/)
 |(?P<id>[A-Za-z_$][\w$]*)
 |(?P<num>\d[\w.]*)
 |(?P<p>=>|->|&&|\|\||\?\?|[{}()\[\];,.?:<>=!+\-*/%&|^~@#])
""", re.S | re.X)

# After these a `/` starts a regular expression rather than dividing.
REGEX_AFTER = set("(,=:[!&|?{};") | {"return", "typeof", None}
# A line ending in one of these, or the next starting with one, carries the
# statement on; otherwise a newline ends an unbraced one, as in QML handlers.
CONT_END = set("+-*/%&|^=<>?:,.([{!") | {"&&", "||", "??", "=>"}
CONT_START = set(".?:+-*/%&|^=<>),]") | {"&&", "||", "??", "=>"}


def lex(src):
    toks = []   # (type, value, line)
    i, line, n, prev = 0, 1, len(src), None
    while i < n:
        c = src[i]
        if c in "'\"":
            toks.append(("str", "S", line))
            prev, i = "S", string_end(src, i) + 1
            continue
        if c == "`":
            j = template_end(src, i)
            toks.append(("str", "S", line))
            line += src.count("\n", i, j)
            prev, i = "S", j + 1
            continue
        if c == "/" and prev in REGEX_AFTER and src[i:i + 2] not in ("//", "/*"):
            toks.append(("str", "R", line))
            prev, i = "R", regex_end(src, i) + 1
            continue
        m = TOKEN.match(src, i)
        if not m:
            i += 1
            continue
        kind, val = m.lastgroup, m.group()
        if kind == "nl":
            toks.append(("nl", "\n", line))
            line += 1
        elif kind in ("lc", "bc"):
            if "\n" in val:
                line += val.count("\n")
                toks.append(("nl", "\n", line))
        elif kind != "ws":
            toks.append((kind, val, line))
            prev = val
        i = m.end()
    return toks


# The quote that closes the string opening at `i`, or the end of its line.
def string_end(src, i):
    j, n = i + 1, len(src)
    while j < n and src[j] not in (src[i], "\n"):
        j += 2 if src[j] == "\\" else 1
    return j


# The backquote that closes the template string opening at `i`, stepping over
# whatever is inside each ${...}.
def template_end(src, i):
    j, depth, n = i + 1, 0, len(src)
    while j < n:
        if src[j] == "\\":
            j += 2
            continue
        if depth == 0 and src[j] == "`":
            break
        if src.startswith("${", j):
            depth += 1
            j += 2
            continue
        if depth and src[j] == "}":
            depth -= 1
        j += 1
    return j


# The last character of the regular expression opening at `i`: its closing
# slash, or the last of its flags. A slash inside [...] does not close it.
def regex_end(src, i):
    j, in_class, n = i + 1, False, len(src)
    while j < n and src[j] != "\n":
        if src[j] == "\\":
            j += 2
            continue
        if src[j] == "[":
            in_class = True
        elif src[j] == "]":
            in_class = False
        elif src[j] == "/" and not in_class:
            break
        j += 1
    while j + 1 < n and src[j + 1].isalpha():
        j += 1
    return j


class Braces:
    def __init__(self, scan, path, toks, cpp):
        self.scan, self.path, self.t, self.cpp = scan, path, toks, cpp
        self.func = "?"
        self.candidate = None

    def tok(self, i):
        return self.t[i][1] if 0 <= i < len(self.t) else None

    def skip_nl(self, i):
        while i < len(self.t) and self.t[i][0] == "nl":
            i += 1
        return i

    def prev_sig(self, i):
        j = i - 1
        while j >= 0 and self.t[j][0] == "nl":
            j -= 1
        return self.t[j][1] if j >= 0 else None

    def is_control(self, i):
        return (self.tok(i) in ("if", "for", "while", "switch", "do")
                and self.prev_sig(i) not in (".", "->"))

    def push(self, stack, kind, line):
        stack.append((kind, line))
        self.scan.record(self.path, self.func, stack)

    def note_function(self, i, stack):
        v = self.tok(i)
        if v == "function" and i + 1 < len(self.t) and self.t[i + 1][0] == "id":
            self.func = self.tok(i + 1)
        elif (self.cpp and not stack and self.t[i][0] == "id" and self.tok(i + 1) == "("
              and self.prev_sig(i) not in (".", "->", "=", "(", ",", "return")
              and not self.is_control(i)):
            self.candidate = v

    # A callback with a body in braces, somewhere in this argument list.
    def has_block_callback(self, i):
        depth = 0
        while i < len(self.t):
            v = self.tok(i)
            if v in ("(", "[", "{"):
                depth += 1
            elif v in (")", "]", "}"):
                depth -= 1
                if depth == 0:
                    return False
            elif depth == 1 and (v == "function" or (v == "=>" and self.tok(self.skip_nl(i + 1)) == "{")):
                return True
            i += 1
        return False

    def group(self, i, stack):
        close = ")" if self.tok(i) == "(" else "]"
        i += 1
        while i < len(self.t) and self.tok(i) != close:
            i = self.item(i, stack)
        return i + 1

    def block(self, i, stack):
        i += 1
        while i < len(self.t) and self.tok(i) != "}":
            i = self.item(i, stack)
        return i + 1

    def item(self, i, stack):
        v = self.tok(i)
        self.note_function(i, stack)
        if v == "{":
            if self.cpp and not stack and self.candidate:
                self.func = self.candidate
            return self.block(i, stack)
        if v in ("(", "["):
            return self.group(i, stack)
        if self.is_control(i):
            return self.control(i, stack)
        if (v in ITER_METHODS and self.prev_sig(i) == "." and self.tok(i + 1) == "("
                and self.has_block_callback(i + 1)):
            self.push(stack, "each", self.t[i][2])
            j = self.group(i + 1, stack)
            stack.pop()
            return j
        return i + 1

    def control(self, i, stack):
        kw = self.tok(i)
        self.push(stack, kw, self.t[i][2])
        j = self.skip_nl(i + 1)
        if kw == "do":
            j = self.skip_nl(self.body(j, stack))
            stack.pop()
            if self.tok(j) == "while":
                j = self.skip_nl(j + 1)
                if self.tok(j) == "(":
                    j = self.group(j, stack)
            return j
        if self.cpp and self.tok(j) == "constexpr":
            j = self.skip_nl(j + 1)
        if self.tok(j) == "(":
            j = self.group(j, stack)
        j = self.body(j, stack)
        stack.pop()
        if kw == "if":
            k = self.skip_nl(j)
            if self.tok(k) == "else":
                return self.body(k + 1, stack)
        return j

    # The body of a control statement: a block, another control statement, or
    # one statement, which ends at `;`, at a closing bracket, or at a newline
    # that does not carry it on.
    def body(self, j, stack):
        j = self.skip_nl(j)
        if self.tok(j) == "{":
            return self.block(j, stack)
        if self.is_control(j):
            return self.control(j, stack)
        started = False
        while j < len(self.t):
            kind, v, _ = self.t[j]
            if v == ";":
                return j + 1
            if v in ("}", ")", "]"):
                return j
            if kind == "nl":
                if started and self.prev_sig(j) not in CONT_END:
                    nxt = self.tok(self.skip_nl(j))
                    if nxt == "else" or nxt not in CONT_START:
                        return j
                j += 1
                continue
            started = True
            j = self.item(j, stack)
        return j

    def run(self):
        i = 0
        while i < len(self.t):
            if self.tok(i) in ("}", ")", "]"):
                i += 1
                continue
            i = self.item(i, [])


# ---- shell ------------------------------------------------------------------

def blank_shell(src):
    """The script with comments, quoted text and heredoc bodies blanked out and
    every newline kept, so a keyword is seen only where bash would see it --
    not in an awk or jq program in quotes, which have `if` and `for` of their
    own."""
    out, n, heredocs = [], len(src), []

    def blank(s):
        return "".join("\n" if ch == "\n" else " " for ch in s)

    def code(i, stop):
        depth = 0
        while i < n:
            c = src[i]
            if c == "\\" and i + 1 < n:
                out.append(blank(src[i:i + 2]))
                i += 2
                continue
            if stop == ")" and c == "(":
                depth += 1
            if stop and c == stop:
                if depth == 0:
                    out.append(c)
                    return i + 1
                depth -= 1
            if c == "#" and (i == 0 or src[i - 1] in " \t\n;(|&"):
                j = src.find("\n", i)
                j = n if j < 0 else j
                out.append(" " * (j - i))
                i = j
                continue
            if c == "'":
                j = single_quote_end(i)
                out.append(blank(src[i:j + 1]))
                i = j + 1
                continue
            if c == '"':
                out.append(" ")
                i = quoted(i + 1)
                continue
            if src.startswith("<<", i) and not src.startswith("<<<", i):
                m = re.match(r"<<-?\s*(['\"]?)(\w+)\1", src[i:])
                if m:
                    heredocs.append(m.group(2))
                    out.append(" " * m.end())
                    i += m.end()
                    continue
            if src.startswith("$(", i) and not src.startswith("$((", i):
                out.append("$(")
                i = code(i + 2, ")")
                continue
            if c == "\n" and heredocs:
                out.append("\n")
                i = heredoc_bodies(i + 1)
                continue
            out.append(c)
            i += 1
        return i

    # The quote that closes the one at `i`. Only $'...' takes escapes.
    def single_quote_end(i):
        ansi = i > 0 and src[i - 1] == "$"
        j = i + 1
        while j < n and src[j] != "'":
            j += 2 if ansi and src[j] == "\\" else 1
        return j

    # The heredocs opened on the line just ended, one after another from `i`,
    # blanked through each one's closing word.
    def heredoc_bodies(i):
        while heredocs:
            i = heredoc_body(i, heredocs.pop(0))
        return i

    def heredoc_body(i, end):
        while i < n:
            j = src.find("\n", i)
            j = n if j < 0 else j
            body_line = src[i:j]
            out.append(" " * len(body_line) + ("\n" if j < n else ""))
            i = j + 1
            if body_line.strip() == end:
                break
        return i

    def quoted(i):
        while i < n:
            c = src[i]
            if c == "\\" and i + 1 < n:
                out.append(blank(src[i:i + 2]))
                i += 2
                continue
            if c == '"':
                out.append(" ")
                return i + 1
            if src.startswith("$(", i) and not src.startswith("$((", i):
                out.append("$(")
                i = code(i + 2, ")")
                continue
            out.append("\n" if c == "\n" else " ")
            i += 1
        return i

    code(0, None)
    return "".join(out)


SHELL_WORD = re.compile(r"\b(for|while|until|if|case|done|fi|esac)\b")
COMMAND_POSITION = re.compile(r"(?:^|;|&&|\|\||\||\bdo|\bthen|\belse|\{|\(|!)\s*$")
SHELL_FUNCTION = re.compile(r"\s*(?:function\s+)?([\w-]+)\s*\(\)\s*\{?")


def scan_shell(scan, path, src):
    stack, func = [], "?"
    for lineno, text in enumerate(blank_shell(src).split("\n"), 1):
        m = SHELL_FUNCTION.match(text)
        if m and not stack:
            func = m.group(1)
        elif text.startswith("}") and not stack:
            func = "?"   # the function is over; what follows is the script
        shell_line(scan, path, func, stack, lineno, text)


# One line's keywords, each opening a statement on `stack` or closing one.
def shell_line(scan, path, func, stack, lineno, text):
    words = [m.group(1) for m in SHELL_WORD.finditer(text)
             if COMMAND_POSITION.search(text[:m.start()])]
    for word in words:
        if word in ("done", "fi", "esac"):
            del stack[-1:]   # the statement it closes; nothing, if stray
            continue
        stack.append((word, lineno))
        scan.record(path, func, stack)


# ---- Python -----------------------------------------------------------------

def scan_python(scan, path, src):
    try:
        tree = ast.parse(src)
    except SyntaxError:
        return   # a template, filled in at install time

    def walk(nodes, stack, func):
        for node in nodes:
            f = node.name if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef)) else func
            if isinstance(node, ast.If):
                inner = stack + [("if", node.lineno)]
                scan.record(path, f, inner)
                walk(node.body, inner, f)
                # An elif is this if's own next branch.
                walk(node.orelse, stack, f)
                continue
            kind = None
            if isinstance(node, (ast.For, ast.AsyncFor)):
                kind = "for"
            elif isinstance(node, ast.While):
                kind = "while"
            elif isinstance(node, ast.Match):
                kind = "switch"
            if kind:
                inner = stack + [(kind, node.lineno)]
                scan.record(path, f, inner)
                walk(ast.iter_child_nodes(node), inner, f)
            else:
                walk(ast.iter_child_nodes(node), stack, f)

    walk([tree], [], "?")


# ---- the tree -----------------------------------------------------------------

def main(root):
    scan = Scan()
    files = subprocess.run(["git", "-C", root, "ls-files"], capture_output=True,
                           text=True, check=True).stdout.split("\n")
    sources = {}
    for rel in filter(None, files):
        path = os.path.join(root, rel)
        if not os.path.isfile(path) or os.path.islink(path):
            continue
        try:
            with open(path, encoding="utf-8") as fh:
                src = fh.read()
        except (UnicodeDecodeError, OSError):
            continue
        name = rel[:-3] if rel.endswith(".in") else rel
        first = src.split("\n", 1)[0] if src.startswith("#!") else ""
        if name.endswith((".qml", ".js")):
            Braces(scan, rel, lex(src), cpp=False).run()
        elif name.endswith((".cpp", ".h")):
            Braces(scan, rel, lex(src), cpp=True).run()
        elif name.endswith(".py") or "python" in first:
            scan_python(scan, rel, src)
        elif name.endswith(".sh") or re.search(r"\b(ba)?sh\b", first):
            scan_shell(scan, rel, src)
        else:
            continue
        sources[rel] = src.split("\n")

    for (path, line), (func, chain) in sorted(scan.found.items()):
        near = sources[path][max(0, line - 2):line]
        if any(ALLOW in text for text in near):
            continue
        print(f"{path}:{line}\t{func if func != '?' else '(top level)'}\t{' > '.join(k for k, _ in chain)}")


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else ".")

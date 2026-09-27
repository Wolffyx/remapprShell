#!/usr/bin/env python3
"""Statements nested three deep, and ladders of tests, for lint-nesting.sh.

Reads every tracked QML, JavaScript, C++, shell and Python file and prints one
line per finding:

    <path>:<line>\t<function>\t<shape>

Two shapes are found:

  three deep  three control statements, each inside the last -- loops,
              conditions and switches -- counted from the function they are
              in. The shape is the deepest chain under the outermost one,
              e.g. "for > if > for > if", printed at the outermost. A shell
              script's `case` on its command, outside every function, is not
              counted: each of its arms is a command, read as a function is.
  a ladder    three or more tests of one thing in a row, each an `==` or `!=`
              -- `if (kind === "a") ... else if (kind === "b") ...`, an
              `elif` chain, or `?:` after `?:` -- printed as "ladder: 4 tests
              of kind". A table from each value to what it does says it once.

A finding with `lint-nesting: allow` on the line of any statement in it, or
on the line above one, is not printed.

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

ITER_METHODS = {"forEach", "map", "filter", "some", "every", "reduce", "find",
                "findIndex", "flatMap"}
ALLOW = "lint-nesting: allow"
DEEP = 3      # statements, each inside the last
LADDER = 3    # tests of one thing in a row


class Scan:
    def __init__(self):
        # (path, line, rule) -> (function, shape, lines of its statements)
        self.found = {}

    # A chain of statements, each inside the last, as (keyword, line). The
    # deepest under one outermost statement is the one kept.
    def record(self, path, func, chain):
        if len(chain) < DEEP:
            return
        key = (path, chain[0][1], "deep")
        if key in self.found and len(self.found[key][2]) >= len(chain):
            return
        self.found[key] = (func, " > ".join(k for k, _ in chain), [line for _, line in chain])

    # The tests of one `if` and whatever continues it, as (subject, line):
    # the subject is what an `==` or `!=` compares, or None.
    def ladder(self, path, func, tests):
        run = longest_run(tests)
        if len(run) < LADDER:
            return
        subject, line = run[0]
        self.found[(path, line, "ladder")] = (func, f"ladder: {len(run)} tests of {subject}", [line])


# The longest run of tests of one subject, one after another.
def longest_run(tests):
    best, run = [], []
    for test in tests:
        if not (run and run[-1][0] == test[0]):
            run = []
        run = run + [test] if test[0] else []
        if len(run) > len(best):
            best = run
    return best


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
            line = comment(toks, val, line)
        elif kind != "ws":
            toks.append((kind, val, line))
            prev = val
        i = m.end()
    return toks


# A comment is dropped; one over several lines still ends the line it began
# on. The line after it.
def comment(toks, text, line):
    if "\n" not in text:
        return line
    line += text.count("\n")
    toks.append(("nl", "\n", line))
    return line


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


OPEN = ("(", "[", "{")
CLOSE = (")", "]", "}")


class Braces:
    def __init__(self, scan, path, toks, cpp):
        self.scan, self.path, self.t, self.cpp = scan, path, toks, cpp
        self.func = "?"
        self.candidate = None
        # Each `?` that asks `x == literal`, by where its `x` starts:
        # (subject, line, index of the `?`, function).
        self.asks = {}

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

    # A callback with a body in braces, somewhere in the argument list that
    # opens at `i`.
    def has_block_callback(self, i):
        depth = 0
        while i < len(self.t):
            v = self.tok(i)
            if v in OPEN:
                depth += 1
            elif v in CLOSE:
                depth -= 1
            if depth == 0:
                return False
            if depth == 1 and self.is_block_function(i):
                return True
            i += 1
        return False

    def is_block_function(self, i):
        v = self.tok(i)
        return v == "function" or (v == "=>" and self.tok(self.skip_nl(i + 1)) == "{")

    # What the condition from `start` to `end` compares with `==` or `!=`
    # (either many `=`), as written -- `item.kind` -- or None.
    def subject(self, start, end):
        vals = [v for kind, v, _ in self.t[start:end] if kind != "nl"]
        at = next((k for k in range(1, len(vals) - 1)
                   if vals[k] == "=" and vals[k + 1] == "=" and vals[k - 1] != "="), None)
        if at is None:
            return None
        left = vals[:at - 1] if vals[at - 1] == "!" else vals[:at]
        first = max((k + 1 for k, v in enumerate(left) if v in ("(", "&&", "||", ",", "!")), default=0)
        return "".join(left[first:]) or None

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
        self.note_ask(i)
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

    # A control statement from its keyword. `tests` are those of the `if`s
    # this one is the `else if` of.
    def control(self, i, stack, tests=()):
        kw, line = self.tok(i), self.t[i][2]
        self.push(stack, kw, line)
        j = self.skip_nl(i + 1)
        if kw == "do":
            return self.do_while(j, stack)
        if self.cpp and self.tok(j) == "constexpr":
            j = self.skip_nl(j + 1)
        cond = j
        if self.tok(j) == "(":
            j = self.group(j, stack)
        test = (self.subject(cond + 1, j - 1), line)
        j = self.body(j, stack)
        stack.pop()
        if kw != "if":
            return j
        tests = list(tests) + [test]
        k = self.skip_nl(j)
        if self.tok(k) != "else":
            self.scan.ladder(self.path, self.func, tests)
            return j
        k = self.skip_nl(k + 1)
        if self.tok(k) == "if":
            return self.control(k, stack, tests)
        self.scan.ladder(self.path, self.func, tests)
        return self.body(k, stack)

    # The rest of a `do` from its body: the body, and the `while (...)` after.
    def do_while(self, j, stack):
        j = self.skip_nl(self.body(j, stack))
        stack.pop()
        if self.tok(j) != "while":
            return j
        j = self.skip_nl(j + 1)
        return self.group(j, stack) if self.tok(j) == "(" else j

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
            if kind == "nl" and started and self.ends_statement(j):
                return j
            if kind == "nl":
                j += 1
                continue
            started = True
            j = self.item(j, stack)
        return j

    # Whether the newline at `j` ends the statement before it.
    def ends_statement(self, j):
        if self.prev_sig(j) in CONT_END:
            return False
        nxt = self.tok(self.skip_nl(j))
        return nxt == "else" or nxt not in CONT_START

    # ---- ?: ladders
    #
    # `x === "a" ? p : x === "b" ? q : r` -- each `?` that asks whether a
    # thing equals a string or a number is noted where its thing starts, and
    # a ladder is one whose answer-otherwise starts with the next.

    def note_ask(self, i):
        if self.tok(i) != "?" or self.tok(i + 1) == "." or i < 2 or self.t[i - 1][0] not in ("str", "num"):
            return
        k, equals = i - 2, 0
        while k >= 0 and self.tok(k) == "=":
            k, equals = k - 1, equals + 1
        negated = self.tok(k) == "!"
        if equals < (1 if negated else 2):
            return
        end = k - negated
        if self.t[end][0] != "id":
            return
        start = self.name_start(end)
        subject = "".join(v for _, v, _ in self.t[start:end + 1])
        self.asks[start] = (subject, self.t[i][2], i, self.func)

    # Where the dotted name ending at `end` starts: `a.b`, `a?.b`.
    def name_start(self, end):
        start = end
        while start >= 2 and self.tok(start - 1) == ".":
            back = 3 if self.tok(start - 2) == "?" else 2
            if start < back or self.t[start - back][0] != "id":
                break
            start -= back
        return start

    # Just past the `:` that answers the `?` at `q`, or -1 for none.
    def otherwise(self, q):
        depth = asked = 0
        for k in range(q + 1, len(self.t)):
            v = self.tok(k)
            depth += (v in OPEN) - (v in CLOSE)
            if depth < 0 or (depth == 0 and v == ";"):
                return -1
            if depth == 0 and v == "?" and self.tok(k + 1) != ".":
                asked += 1
            elif depth == 0 and v == ":" and asked:
                asked -= 1
            elif depth == 0 and v == ":":
                return k + 1
        return -1

    def ternaries(self):
        seen = set()
        for start in sorted(self.asks):
            if start in seen:
                continue
            tests, func = [], self.asks[start][3]
            while start in self.asks:
                subject, line, q, _ = self.asks[start]
                seen.add(start)
                tests.append((subject, line))
                start = self.skip_nl(self.otherwise(q))
            self.scan.ladder(self.path, func, tests)

    def run(self):
        i = 0
        while i < len(self.t):
            if self.tok(i) in CLOSE:
                i += 1
                continue
            i = self.item(i, [])
        self.ternaries()


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
            if stop and c == stop and depth == 0:
                out.append(c)
                return i + 1
            if stop and c == stop:
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
            m = heredoc_at(i)
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

    # The heredoc that opens at `i`: its `<<` and closing word.
    def heredoc_at(i):
        if not src.startswith("<<", i) or src.startswith("<<<", i):
            return None
        return re.match(r"<<-?\s*(['\"]?)(\w+)\1", src[i:])

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


SHELL_WORD = re.compile(r"\b(for|while|until|if|elif|case|done|fi|esac)\b")
# After one of these a word is a command -- a case pattern's `)` too.
COMMAND_POSITION = re.compile(r"(?:^|;|&&|\|\||\||\bdo|\bthen|\belse|\{|\(|\)|!)\s*$")
SHELL_FUNCTION = re.compile(r"\s*(?:function\s+)?([\w-]+)\s*\(\)\s*\{?")
# What a test compares with `=`, `==` or `!=`: `[ "$kind" = a ]` is `kind`.
SHELL_TEST = re.compile(r"""\s*(?:!\s*)?\[\[?\s+"?\$\{?(\w+)\}?"?\s+(?:==?|!=)\s""")


def scan_shell(scan, path, src):
    script = ShellScript(scan, path)
    for lineno, (text, raw) in enumerate(zip(blank_shell(src).split("\n"), src.split("\n")), 1):
        script.line(lineno, text, raw)


# One script, a line at a time: the statements open at the end of each, and
# beside each `if` among them, its tests so far.
class ShellScript:
    def __init__(self, scan, path):
        self.scan, self.path = scan, path
        self.func = "?"
        self.stack = []   # (keyword, line)
        self.tests = []   # beside each statement: its tests, if an `if`

    # `text` is the line blanked, `raw` as written: the same length, so a
    # keyword found in one is where it is in the other.
    def line(self, lineno, text, raw):
        m = SHELL_FUNCTION.match(text)
        if m and not self.stack:
            self.func = m.group(1)
        elif text.startswith("}") and not self.stack:
            self.func = "?"   # the function is over; what follows is the script
        for m in SHELL_WORD.finditer(text):
            if COMMAND_POSITION.search(text[:m.start()]):
                self.word(m.group(1), lineno, raw[m.end():])

    def word(self, word, lineno, rest):
        test = SHELL_TEST.match(rest)
        subject = test.group(1) if test else None
        if word in ("done", "fi", "esac"):
            self.close()
        elif word == "elif" and self.tests and self.tests[-1] is not None:
            self.tests[-1].append((subject, lineno))
        elif word != "elif":
            self.open(word, lineno, subject)

    def open(self, word, lineno, subject):
        self.stack.append((word, lineno))
        self.tests.append([(subject, lineno)] if word == "if" else None)
        # A script's case on its command is its list of commands.
        dispatch = self.func == "?" and self.stack[0][0] == "case"
        self.scan.record(self.path, self.func, self.stack[1:] if dispatch else self.stack)

    # The statement a done, fi or esac closes; nothing, if stray.
    def close(self):
        if not self.stack:
            return
        self.stack.pop()
        tests = self.tests.pop()
        if tests:
            self.scan.ladder(self.path, self.func, tests)


# ---- Python -----------------------------------------------------------------

PY_LOOPS = {ast.For: "for", ast.AsyncFor: "for", ast.While: "while", ast.Match: "switch"}
PY_EQUALS = (ast.Eq, ast.NotEq, ast.Is, ast.IsNot)


def scan_python(scan, path, src):
    try:
        tree = ast.parse(src)
    except SyntaxError:
        return   # a template, filled in at install time
    elifs = set()

    def walk(nodes, stack, func):
        for node in nodes:
            f = node.name if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef)) else func
            if isinstance(node, ast.If):
                walk_if(node, stack, f)
                continue
            kind = PY_LOOPS.get(type(node))
            inner = stack + [(kind, node.lineno)] if kind else stack
            if kind:
                scan.record(path, f, inner)
            walk(ast.iter_child_nodes(node), inner, f)

    def walk_if(node, stack, func):
        if id(node) not in elifs:
            chain = if_chain(node)
            elifs.update(id(n) for n in chain[1:])
            scan.ladder(path, func, [(py_subject(n.test), n.lineno) for n in chain])
        inner = stack + [("if", node.lineno)]
        scan.record(path, func, inner)
        walk(node.body, inner, func)
        # An elif is this if's own next branch.
        walk(node.orelse, stack, func)

    walk([tree], [], "?")


# An `if` and each `elif` after it.
def if_chain(node):
    chain = [node]
    while len(chain[-1].orelse) == 1 and isinstance(chain[-1].orelse[0], ast.If):
        chain.append(chain[-1].orelse[0])
    return chain


# What a test compares with `==`, `!=` or `is`, as written, or None.
def py_subject(test):
    if isinstance(test, ast.Compare) and len(test.ops) == 1 and isinstance(test.ops[0], PY_EQUALS):
        return ast.unparse(test.left)
    return None


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

    for (path, line, _), (func, shape, lines) in sorted(scan.found.items()):
        if allowed(sources[path], lines):
            continue
        print(f"{path}:{line}\t{func if func != '?' else '(top level)'}\t{shape}")


# Whether any of `lines` is marked, on it or on the line above.
def allowed(text, lines):
    return any(ALLOW in near for line in lines for near in text[max(0, line - 2):line])


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else ".")

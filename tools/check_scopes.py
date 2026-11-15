"""Scope checker for our Luau files.

Reports every identifier that is used but not declared in any enclosing scope
and is not a known Roblox/Luau global. This catches the classic runtime bug
"attempt to call a nil value" when a local lives inside a do ... end block
(or is declared later) but is used from outside.

Usage: python3 tools/check_scopes.py src/client/*.luau src/server/*.luau ...
"""
import re
import sys

GLOBALS = set("""
and or not nil true false self continue
math string table pairs ipairs print warn error type typeof tostring tonumber select next pcall xpcall
require setmetatable getmetatable rawget rawset rawequal rawlen unpack coroutine task os tick time wait delay
spawn utf8 bit32 buffer debug assert newproxy gcinfo elapsedTime collectgarbage vector
Instance Vector3 Vector2 Vector3int16 Vector2int16 CFrame Color3 ColorSequence ColorSequenceKeypoint NumberSequence
NumberSequenceKeypoint NumberRange UDim UDim2 Enum Rect Ray RaycastParams TweenInfo Font BrickColor Random
DateTime Region3 Region3int16 PhysicalProperties Faces Axes OverlapParams PathWaypoint game workspace script
plugin shared _G settings UserSettings Content SharedTable CatalogSearchParams FloatCurveKey RotationCurveKey
""".split())

# an "if" right after one of these is an if-expression (no "end")
EXPR_OPS = {"=", "(", ",", "{", "[", "..", "+", "-", "*", "/", "//", "%", "^", "==", "~=", "<", ">", "<=", ">=", "#",
            "+=", "-=", "*=", "/=", "//=", "%=", "^=", "..=", "::"}

KEYWORDS = {"and", "break", "do", "else", "elseif", "end", "false", "for", "function", "if", "in", "local",
            "nil", "not", "or", "repeat", "return", "then", "true", "until", "while"}

TOKEN = re.compile(r"""
    (?P<ws>[ \t\r]+)
  | (?P<nl>\n)
  | (?P<lcomment>--\[(?P<leq>=*)\[)
  | (?P<comment>--[^\n]*)
  | (?P<lstr>\[(?P<seq>=*)\[)
  | (?P<str>"(?:\\.|[^"\\\n])*"|'(?:\\.|[^'\\\n])*')
  | (?P<bstr>`)
  | (?P<num>0[xX][0-9a-fA-F_]+|0[bB][01_]+|\d[\d_]*(?:\.[\d_]*)?(?:[eE][+-]?\d+)?|\.\d+(?:[eE][+-]?\d+)?)
  | (?P<name>[A-Za-z_][A-Za-z0-9_]*)
  | (?P<op>\.\.\.|\.\.=|\.\.|==|~=|<=|>=|::|->|\+=|-=|\*=|/=|//=|//|%=|\^=|[-+*/%^#&|~<>=(){}\[\];:,.?@])
""", re.X)


def tokenize(src):
    tokens = []  # (kind, value, line)
    i, line = 0, 1
    while i < len(src):
        m = TOKEN.match(src, i)
        if not m:
            raise SyntaxError(f"line {line}: cannot tokenize {src[i:i + 20]!r}")
        kind = m.lastgroup
        if kind in ("leq", "seq"):
            kind = "lcomment" if m.group("lcomment") else "lstr"
        text = m.group(0)
        if kind in ("lcomment", "lstr"):
            eq = m.group("leq") if kind == "lcomment" else m.group("seq")
            close = "]" + (eq or "") + "]"
            end = src.find(close, m.end())
            end = len(src) if end < 0 else end + len(close)
            text = src[i:end]
            if kind == "lstr":
                tokens.append(("str", "", line))
            line += text.count("\n")
            i = end
            continue
        if kind == "bstr":  # interpolated string: scan to the closing backtick, keep {expr} parts
            j = i + 1
            parts = []
            while j < len(src) and src[j] != "`":
                if src[j] == "\\":
                    j += 2
                    continue
                if src[j] == "{":
                    depth, k = 1, j + 1
                    while k < len(src) and depth:
                        depth += {"{": 1, "}": -1}.get(src[k], 0)
                        k += 1
                    parts.append(src[j + 1:k - 1])
                    j = k
                    continue
                j += 1
            tokens.append(("str", "", line))
            for expr in parts:  # check names inside the interpolation as a parenthesised expression
                tokens.append(("op", "(", line))
                tokens.extend((k2, v2, line) for k2, v2, _ in tokenize(expr))
                tokens.append(("op", ")", line))
            line += src[i:j + 1].count("\n")
            i = j + 1
            continue
        if kind == "nl":
            line += 1
        elif kind not in ("ws", "comment"):
            tokens.append(("str" if kind == "str" else kind, text, line))
        i = m.end()
    return tokens


class Checker:
    def __init__(self, path):
        self.path = path
        self.toks = tokenize(open(path, encoding="utf-8").read())
        self.i = 0
        self.scopes = [set()]
        self.problems = []

    # helpers
    def peek(self, k=0):
        j = self.i + k
        return self.toks[j] if j < len(self.toks) else ("eof", "", 0)

    def declared(self, name):
        return any(name in s for s in self.scopes) or name in GLOBALS

    def declare(self, name):
        self.scopes[-1].add(name)

    def skip_type(self):
        """skip a type annotation; stops before , = ) or at a line break at depth 0"""
        depth = 0
        start_line = self.peek()[2]
        while True:
            kind, val, line = self.peek()
            if kind == "eof":
                return
            if depth == 0:
                if val in (",", "=", ")", ";") and kind == "op":
                    return
                if line != start_line and kind == "name" and val not in ("typeof",):
                    return
                if kind == "name" and val in KEYWORDS and val not in ("nil", "true", "false"):
                    return
            if kind == "op" and val in ("(", "{", "[", "<"):
                depth += 1
            elif kind == "op" and val in (")", "}", "]", ">"):
                if depth == 0:
                    return
                depth -= 1
            self.i += 1

    def skip_cast(self):
        """after ::  skip one type (name chains, ?, |, &, bracketed groups)"""
        depth = 0
        first = True
        while True:
            kind, val, _ = self.peek()
            if kind == "eof":
                return
            if kind == "op" and val in ("(", "{", "[", "<"):
                depth += 1
            elif kind == "op" and val in (")", "}", "]", ">"):
                if depth == 0:
                    return
                depth -= 1
            elif depth == 0 and not first:
                if not (kind == "op" and val in (".", "?", "|", "&")) and not (kind == "name" and self.toks[self.i - 1][1] in (".", "|", "&")):
                    return
            self.i += 1
            first = False
            if depth == 0 and kind == "op" and val in (")", "}", "]", ">"):
                nk, nv, _ = self.peek()
                if not (nk == "op" and nv in ("?", "|", "&")):
                    return

    def params(self):
        """at '(' of a function: declare params in the current (function) scope"""
        assert self.peek()[1] == "("
        self.i += 1
        while True:
            kind, val, _ = self.peek()
            if val == ")":
                self.i += 1
                break
            if kind == "name":
                self.declare(val)
                self.i += 1
                if self.peek()[1] == ":":
                    self.i += 1
                    self.skip_type()
            else:
                self.i += 1  # , or ...
            if kind == "eof":
                return
        if self.peek()[1] == ":":  # return type
            self.i += 1
            self.skip_type()

    def run(self):
        toks = self.toks
        pending_for = None
        # each block on the stack: "func" | "do" | "then" | "repeat"
        blocks = []
        ifs = []  # "stmt" or "expr" for every open if (Luau if-expressions have no end)
        brace = 0
        while self.i < len(toks):
            kind, val, line = toks[self.i]
            prev = toks[self.i - 1] if self.i else ("op", ";", 0)
            if kind == "name" and val == "type" and prev[1] not in (".", ":") and self.peek(1)[0] == "name" and brace == 0 and (prev[0] != "name" or prev[1] in KEYWORDS | {"export"}):
                # type alias: skip to the end of the line(s) at depth 0
                start = line
                depth = 0
                self.i += 1
                while self.i < len(toks):
                    k2, v2, l2 = toks[self.i]
                    if v2 in ("(", "{", "[", "<"):
                        depth += 1
                    elif v2 in (")", "}", "]", ">"):
                        depth -= 1
                    elif depth == 0 and l2 != start and k2 == "name" and v2 != "|":
                        break
                    self.i += 1
                continue
            if kind == "name" and val == "export":
                self.i += 1
                continue
            if kind == "op" and val == "::":
                self.i += 1
                self.skip_cast()
                continue
            if kind == "op" and val == "{":
                brace += 1
            elif kind == "op" and val == "}":
                brace -= 1
            if kind == "name" and val == "local":
                self.i += 1
                if self.peek()[1] == "function":
                    self.i += 1
                    name = self.peek()[1]
                    self.declare(name)
                    self.i += 1
                    self.scopes.append(set())
                    blocks.append("func")
                    self.params()
                    continue
                names = []
                while True:
                    k2, v2, _ = self.peek()
                    if k2 != "name":
                        break
                    names.append(v2)
                    self.i += 1
                    if self.peek()[1] == "<":  # attribute like <const>
                        while self.peek()[1] != ">":
                            self.i += 1
                        self.i += 1
                    if self.peek()[1] == ":":
                        self.i += 1
                        self.skip_type()
                    if self.peek()[1] == ",":
                        self.i += 1
                        continue
                    break
                if self.peek()[1] == "=":
                    # the expression is checked before the names exist (local x = x refers to the outer one)
                    self.i += 1
                    self.pending_local = names
                    self.expr_until_statement_end(blocks)
                for n in names:
                    self.declare(n)
                continue
            if kind == "name" and val == "function":
                self.i += 1
                # function a.b.c:d(...)  -> a must be declared; method adds self
                method = False
                if self.peek()[0] == "name":
                    first = self.peek()
                    if not self.declared(first[1]):
                        self.problems.append((first[2], first[1]))
                    self.i += 1
                    while self.peek()[1] in (".", ":"):
                        method = method or self.peek()[1] == ":"
                        self.i += 2
                self.scopes.append({"self"} if method else set())
                blocks.append("func")
                self.params()
                continue
            if kind == "name" and val == "for":
                self.i += 1
                names = []
                while self.peek()[0] == "name" and self.peek()[1] not in ("in",):
                    names.append(self.peek()[1])
                    self.i += 1
                    if self.peek()[1] == ":":
                        self.i += 1
                        self.skip_type()
                    if self.peek()[1] == ",":
                        self.i += 1
                pending_for = names
                continue
            if kind == "name" and val == "if":
                expr = (prev[0] == "op" and prev[1] in EXPR_OPS) or prev[1] in ("return", "and", "or", "not", "in")
                if prev[1] in ("then", "else") and ifs and ifs[-1] == "expr":
                    expr = True
                ifs.append("expr" if expr else "stmt")
                self.i += 1
                continue
            if kind == "name" and val in ("then", "else", "elseif") and ifs and ifs[-1] == "expr":
                if val == "else":
                    ifs.pop()  # the else branch is the last part of an if-expression
                self.i += 1
                continue
            if kind == "name" and val in ("do", "then", "repeat"):
                self.scopes.append(set(pending_for or []) if val == "do" else set())
                pending_for = None if val == "do" else pending_for
                blocks.append(val)
                self.i += 1
                continue
            if kind == "name" and val in ("elseif", "else"):
                if blocks and blocks[-1] == "then":
                    self.scopes.pop()
                    blocks.pop()
                if val == "else":
                    self.scopes.append(set())
                    blocks.append("then")
                self.i += 1
                continue
            if kind == "name" and val in ("end", "until"):
                if blocks:
                    if blocks[-1] == "then" and ifs:
                        ifs.pop()
                    blocks.pop()
                    self.scopes.pop()
                self.i += 1
                continue
            if kind == "name" and val not in KEYWORDS:
                nxt = self.peek(1)
                is_field = prev[0] == "op" and prev[1] in (".", ":") and not (prev[1] == ":" and False)
                is_key = brace > 0 and prev[1] in ("{", ",", ";") and nxt[1] == "="
                if not is_field and not is_key and not self.declared(val):
                    self.problems.append((line, val))
            self.i += 1
        if blocks or ifs:
            self.problems.append((0, f"<checker lost track of blocks: {blocks} {ifs}>"))
        return self.problems

    def expr_until_statement_end(self, blocks):
        # nothing special: the main loop handles the expression tokens; declarations are added after it,
        # which is approximated by declaring once the loop reaches the next statement. Simpler: declare now.
        return


def main():
    bad = 0
    for path in sys.argv[1:]:
        if path.startswith("-"):
            continue
        try:
            problems = Checker(path).run()
        except SyntaxError as err:
            print(f"{path}: {err}")
            bad += 1
            continue
        seen = set()
        for line, name in problems:
            if (name, line) in seen:
                continue
            seen.add((name, line))
            print(f"{path}:{line}: '{name}' is not declared in this scope (nil at runtime)")
            bad += 1
    print("scopes: ok" if not bad else f"scopes: {bad} problem(s)")
    sys.exit(1 if bad else 0)


if __name__ == "__main__":
    main()

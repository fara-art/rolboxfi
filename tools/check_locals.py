"""Counts top-level locals of each Luau file. Roblox fails with
"Out of local registers ... exceeded limit 200" when a chunk has too many.
Keep every file well under ~180 (wrap self-contained sections in do ... end)."""
import re, sys

LIMIT = 180
bad = False
for path in [a for a in sys.argv[1:] if not a.startswith("-")]:
    count = 0
    for line in open(path, encoding="utf-8"):
        if line.startswith("local function "):
            count += 1
        elif line.startswith("local "):
            names = re.match(r"local ([^=]*)", line).group(1)
            count += len([n for n in names.split(",") if re.match(r"^\s*\w+", n)])
    flag = "  <-- TOO MANY" if count > LIMIT else ""
    bad = bad or count > LIMIT
    if flag or "-v" in sys.argv:
        print(f"{path}: {count} top-level locals{flag}")
# a nested "local X" without a value that hides a top-level "local X": the inner one stays nil
for path in [a for a in sys.argv[1:] if not a.startswith("-")]:
    lines = open(path, encoding="utf-8").read().split("\n")
    top = set()
    for line in lines:
        m = re.match(r"local ([\w, ]+)\s*(--.*)?$", line)
        if m:
            top.update(n.strip() for n in m.group(1).split(","))
    for i, line in enumerate(lines, 1):
        m = re.match(r"\s+local ([\w, ]+)\s*(--.*)?$", line)
        if m:
            for n in (x.strip() for x in m.group(1).split(",")):
                if n in top:
                    print(f"{path}:{i}: nested 'local {n}' hides the top-level one (stays nil)")
                    bad = True
print("locals: FAIL" if bad else "locals: ok")
sys.exit(1 if bad else 0)

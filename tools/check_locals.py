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
print("locals: FAIL" if bad else "locals: ok")
sys.exit(1 if bad else 0)

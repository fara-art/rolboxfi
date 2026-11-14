# Finds locals used before their "local" declaration (Luau would read a nil global instead).
# Run: python3 tools/check_forward_refs.py src/client/*.luau src/server/*.luau src/shared/*.luau
import re,sys
for path in sys.argv[1:]:
    lines=open(path).read().split('\n')
    decl={}
    for i,l in enumerate(lines):
        m=re.match(r'^local function (\w+)',l) or re.match(r'^local (\w+)\s*(=|:|$)',l)
        if m and m.group(1) not in decl: decl[m.group(1)]=i
        m2=re.match(r'^local ([\w, ]+)=',l)
        if m2 and ',' in m2.group(1):
            for n in m2.group(1).split(','):
                n=n.strip().split(':')[0]
                if n and n not in decl: decl[n]=i
    for name,i in decl.items():
        if name=='_': continue
        pat=re.compile(r'(?<![\w.:])'+re.escape(name)+r'\b')
        for j in range(i):
            code=lines[j].split('--')[0]
            code=re.sub(r'"[^"]*"','""',code)
            if pat.search(code):
                print(f"{path}:{j+1}: '{name}' used before local declaration at line {i+1}: {lines[j].strip()[:90]}")
                break

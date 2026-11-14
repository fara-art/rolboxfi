# Собирает ConstellationsRNG.rbxlx из src/ (без Rojo). Запуск: python3 tools/build_place.py
import pathlib, itertools
root = pathlib.Path(__file__).resolve().parent.parent
ref = (f"RBX{i}" for i in itertools.count(1))

def src(path):
    text = (root / path).read_text(encoding="utf-8")
    assert "]]>" not in text, path
    return text

def item(cls, name, children="", source=None, extra=""):
    props = f'<string name="Name">{name}</string>{extra}'
    if source is not None:
        props += f'<ProtectedString name="Source"><![CDATA[{source}]]></ProtectedString>'
    return f'<Item class="{cls}" referent="{next(ref)}"><Properties>{props}</Properties>{children}</Item>\n'

def part(cls, name, y, size):
    cf = (f'<CoordinateFrame name="CFrame"><X>0</X><Y>{y}</Y><Z>0</Z>'
          '<R00>1</R00><R01>0</R01><R02>0</R02><R10>0</R10><R11>1</R11><R12>0</R12>'
          '<R20>0</R20><R21>0</R21><R22>1</R22></CoordinateFrame>')
    sx, sy, sz = size
    extra = f'<bool name="Anchored">true</bool>{cf}<Vector3 name="size"><X>{sx}</X><Y>{sy}</Y><Z>{sz}</Z></Vector3>'
    return item(cls, name, extra=extra)

shared = "".join(item("ModuleScript", p.stem, source=src(p.relative_to(root)))
                 for p in sorted((root / "src/shared").glob("*.luau")))
server = item("Script", "Main", source=src("src/server/Main.server.luau")) + "".join(
    item("ModuleScript", p.stem, source=src(p.relative_to(root)))
    for p in sorted((root / "src/server").glob("*.luau")) if not p.name.endswith(".server.luau"))
client = item("LocalScript", "Main", source=src("src/client/Main.client.luau"))

xml = ('<roblox xmlns:xmime="http://www.w3.org/2005/05/xmlmime" '
       'xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" '
       'xsi:noNamespaceSchemaLocation="http://www.roblox.com/roblox.xsd" version="4">\n'
       + item("Workspace", "Workspace", part("SpawnLocation", "SpawnLocation", 0.5, (12, 1, 12)))
       + item("Lighting", "Lighting", extra='<float name="ClockTime">0</float><float name="Brightness">1</float>')
       + item("ReplicatedStorage", "ReplicatedStorage", item("Folder", "Shared", shared))
       + item("ServerScriptService", "ServerScriptService", item("Folder", "Server", server))
       + item("StarterPlayer", "StarterPlayer",
              item("StarterPlayerScripts", "StarterPlayerScripts", item("Folder", "Client", client)))
       + '</roblox>\n')
(root / "ConstellationsRNG.rbxlx").write_text(xml, encoding="utf-8")
print("ok", len(xml))

# Runs INSIDE Blender (headless). Converts Tripo AI exports into Roblox-ready FBX.
#   blender --background --python tools/tripo_to_roblox.py -- <input> <output.fbx> [target_tris]
#
# What it does:
#   1. Imports .glb/.gltf/.fbx/.obj (Tripo exports GLB by default)
#   2. Joins meshes, applies transforms
#   3. Decimates down to target triangle count (default 8000 — Roblox cap is 10k/MeshPart)
#   4. Exports FBX with textures packed alongside

import bpy
import sys
import os

argv = sys.argv[sys.argv.index("--") + 1:]
src = os.path.abspath(argv[0])
dst = os.path.abspath(argv[1])
target_tris = int(argv[2]) if len(argv) > 2 else 8000

# Clean scene
bpy.ops.wm.read_factory_settings(use_empty=True)

ext = os.path.splitext(src)[1].lower()
if ext in (".glb", ".gltf"):
    bpy.ops.import_scene.gltf(filepath=src)
elif ext == ".fbx":
    bpy.ops.import_scene.fbx(filepath=src)
elif ext == ".obj":
    bpy.ops.wm.obj_import(filepath=src)
else:
    raise SystemExit(f"Unsupported input format: {ext}")

meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
if not meshes:
    raise SystemExit("No meshes found in input file")

# Join everything into one object
bpy.ops.object.select_all(action="DESELECT")
for o in meshes:
    o.select_set(True)
bpy.context.view_layer.objects.active = meshes[0]
if len(meshes) > 1:
    bpy.ops.object.join()
obj = bpy.context.view_layer.objects.active
obj.name = os.path.splitext(os.path.basename(dst))[0]

bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)

# Decimate if over budget
tri_count = sum(len(p.vertices) - 2 for p in obj.data.polygons)
print(f"[pipeline] input tris: {tri_count}, target: {target_tris}")
if tri_count > target_tris:
    mod = obj.modifiers.new("Decimate", "DECIMATE")
    mod.ratio = target_tris / tri_count
    bpy.ops.object.modifier_apply(modifier=mod.name)
    final = sum(len(p.vertices) - 2 for p in obj.data.polygons)
    print(f"[pipeline] decimated to: {final} tris")

os.makedirs(os.path.dirname(dst), exist_ok=True)
bpy.ops.export_scene.fbx(
    filepath=dst,
    use_selection=False,
    path_mode="COPY",       # pack textures next to the FBX
    embed_textures=True,
    apply_scale_options="FBX_SCALE_ALL",
)
print(f"[pipeline] exported: {dst}")

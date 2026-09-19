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

# Tripo exports flat-shaded meshes with every face's vertices split, which makes
# collapse decimation stall (it cannot collapse across unshared vertices). Weld first.
bpy.ops.object.mode_set(mode="EDIT")
bpy.ops.mesh.select_all(action="SELECT")
bpy.ops.mesh.remove_doubles(threshold=0.0005)
bpy.ops.object.mode_set(mode="OBJECT")

# Decimate if over budget
tri_count = sum(len(p.vertices) - 2 for p in obj.data.polygons)
print(f"[pipeline] input tris: {tri_count}, target: {target_tris}")
# Rough collapse first: planar dissolve on the raw 1.5-2M-tri Tripo mesh takes minutes,
# on ~150k tris it takes seconds and the shape is still intact at that density.
ROUGH = 150000
if tri_count > ROUGH:
    mod = obj.modifiers.new("Rough", "DECIMATE")
    mod.ratio = ROUGH / tri_count
    bpy.ops.object.modifier_apply(modifier=mod.name)
    tri_count = sum(len(p.vertices) - 2 for p in obj.data.polygons)
    print(f"[pipeline] rough collapse: {tri_count} tris")

# Hard-surface models (buildings, props): a planar dissolve merges coplanar faces so
# walls stay flat and windows crisp instead of collapsing into shards. Pass "organic"
# as the 4th argument to skip it (characters, creatures).
if (argv[3] if len(argv) > 3 else "hard") != "organic":
    mod = obj.modifiers.new("Planar", "DECIMATE")
    mod.decimate_type = "DISSOLVE"
    mod.angle_limit = 0.0873  # 5 degrees
    mod.use_dissolve_boundaries = False
    bpy.ops.object.modifier_apply(modifier=mod.name)
    tri_count = sum(len(p.vertices) - 2 for p in obj.data.polygons)
    print(f"[pipeline] planar dissolve: {tri_count} tris")

# Decimate in passes: a single very small ratio stalls far above the target on dense
# Tripo meshes (1.9M -> 142k), and Roblox MeshParts must stay under 10k triangles.
passes = 0
while tri_count > target_tris and passes < 6:
    passes += 1
    mod = obj.modifiers.new("Decimate", "DECIMATE")
    mod.ratio = max(target_tris / tri_count, 0.02)
    bpy.ops.object.modifier_apply(modifier=mod.name)
    tri_count = sum(len(p.vertices) - 2 for p in obj.data.polygons)
    print(f"[pipeline] decimate pass {passes}: {tri_count} tris")

# Smooth shading by angle so the decimated surface reads as panels, not shards.
bpy.ops.object.select_all(action="DESELECT")
obj.select_set(True)
bpy.context.view_layer.objects.active = obj
try:
    bpy.ops.object.shade_smooth_by_angle(angle=0.6109)  # 35 degrees
except Exception:  # older Blender
    bpy.ops.object.shade_smooth()

os.makedirs(os.path.dirname(dst), exist_ok=True)
bpy.ops.export_scene.fbx(
    filepath=dst,
    use_selection=False,
    path_mode="COPY",       # pack textures next to the FBX
    embed_textures=True,
    apply_scale_options="FBX_SCALE_ALL",
)
print(f"[pipeline] exported: {dst}")

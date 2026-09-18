# Runs INSIDE Blender headless. Converts an ANIMATED Tripo FBX to Roblox-ready FBX
# while preserving the armature, skin weights, and animation tracks.
#   blender --background --python tools/animated_to_roblox.py -- <input.fbx> <output.fbx> [target_tris]
# Unlike tripo_to_roblox.py this does NOT join meshes — joining breaks the rig.
# Decimate runs per-mesh; vertex groups (skin weights) survive the modifier.

import os
import sys

import bpy

argv = sys.argv[sys.argv.index("--") + 1:]
src = os.path.abspath(argv[0])
dst = os.path.abspath(argv[1])
target_tris = int(argv[2]) if len(argv) > 2 else 8000

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.fbx(filepath=src)

meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
armatures = [o for o in bpy.context.scene.objects if o.type == "ARMATURE"]
if not meshes:
    raise SystemExit("No meshes found")
print(f"[anim-pipeline] meshes: {len(meshes)}, armatures: {len(armatures)}")

total_tris = 0
for obj in meshes:
    total_tris += sum(len(p.vertices) - 2 for p in obj.data.polygons)
print(f"[anim-pipeline] input tris: {total_tris}, target: {target_tris}")

if total_tris > target_tris:
    ratio = target_tris / total_tris
    for obj in meshes:
        bpy.context.view_layer.objects.active = obj
        mod = obj.modifiers.new("Decimate", "DECIMATE")
        mod.ratio = ratio
        # apply while keeping the Armature modifier(s) intact and last
        bpy.ops.object.modifier_apply(modifier=mod.name)
    final = sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in meshes)
    print(f"[anim-pipeline] decimated to: {final} tris")

os.makedirs(os.path.dirname(dst), exist_ok=True)
bpy.ops.export_scene.fbx(
    filepath=dst,
    use_selection=False,
    path_mode="COPY",
    embed_textures=True,
    add_leaf_bones=False,
    bake_anim=True,
    apply_scale_options="FBX_SCALE_ALL",
)
print(f"[anim-pipeline] exported: {dst}")

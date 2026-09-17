# Runs INSIDE Blender headless. Renders a preview PNG for every GLB in assets/raw.
#   blender --background --python tools/render_previews.py
# Output: assets/previews/<name>.png (Workbench engine — fast, shows textures)

import math
import pathlib
import sys

import bpy

ROOT = pathlib.Path(__file__).resolve().parent.parent
RAW = ROOT / "assets" / "raw"
OUT = ROOT / "assets" / "previews"
OUT.mkdir(parents=True, exist_ok=True)

for glb in sorted(RAW.glob("*.glb")):
    out_path = OUT / f"{glb.stem}.png"
    if out_path.exists():
        print(f"[skip] {glb.stem}")
        continue

    bpy.ops.wm.read_factory_settings(use_empty=True)
    try:
        bpy.ops.import_scene.gltf(filepath=str(glb))
    except Exception as error:
        print(f"[fail] {glb.stem}: {error}")
        continue

    meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    if not meshes:
        continue

    # frame the model: find bounds
    min_v = [1e9] * 3
    max_v = [-1e9] * 3
    for obj in meshes:
        for corner in obj.bound_box:
            world = obj.matrix_world @ __import__("mathutils").Vector(corner)
            for i in range(3):
                min_v[i] = min(min_v[i], world[i])
                max_v[i] = max(max_v[i], world[i])
    center = [(min_v[i] + max_v[i]) / 2 for i in range(3)]
    span = max(max_v[i] - min_v[i] for i in range(3))

    cam_data = bpy.data.cameras.new("cam")
    cam = bpy.data.objects.new("cam", cam_data)
    bpy.context.scene.collection.objects.link(cam)
    distance = span * 1.8
    cam.location = (center[0] + distance * 0.8, center[1] - distance, center[2] + distance * 0.55)
    direction = __import__("mathutils").Vector(center) - cam.location
    cam.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
    bpy.context.scene.camera = cam

    scene = bpy.context.scene
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.display.shading.light = "STUDIO"
    scene.display.shading.color_type = "TEXTURE"
    scene.render.resolution_x = 512
    scene.render.resolution_y = 512
    scene.render.filepath = str(out_path)
    bpy.ops.render.render(write_still=True)
    print(f"[ok] {glb.stem}")

print("PREVIEWS DONE")

# Runs INSIDE Blender (headless). Converts a dense Tripo GLB into a Roblox-ready FBX by
# decimating for SHAPE only, re-unwrapping the low-poly, and baking the original base
# colour onto it. Decimating the original with its UVs (tools/tripo_to_roblox.py) shreds
# the texture into slivers; baking keeps it intact.
#   blender --background --python tools/tripo_bake.py -- <input.glb> <output.fbx> [tris] [texsize]
import bpy, sys, os, math, time, mathutils

argv = sys.argv[sys.argv.index("--") + 1:]
src = os.path.abspath(argv[0]); dst = os.path.abspath(argv[1])
target_tris = int(argv[2]) if len(argv) > 2 else 8000
tex = int(argv[3]) if len(argv) > 3 else 1024
mode = argv[4] if len(argv) > 4 else "remesh"   # collapse | remesh | remesh_planar
voxel_div = float(argv[5]) if len(argv) > 5 else 160.0
samples = int(argv[6]) if len(argv) > 6 else 16
name = os.path.splitext(os.path.basename(dst))[0]
t0 = time.time()
def log(m): print(f"[bake] {m} ({time.time()-t0:.0f}s)", flush=True)

bpy.ops.wm.read_factory_settings(use_empty=True)
ext = os.path.splitext(src)[1].lower()
if ext in (".glb", ".gltf"): bpy.ops.import_scene.gltf(filepath=src)
elif ext == ".fbx": bpy.ops.import_scene.fbx(filepath=src)
elif ext == ".obj": bpy.ops.wm.obj_import(filepath=src)
else: raise SystemExit(f"unsupported {ext}")
meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
if not meshes: raise SystemExit("no meshes")
bpy.ops.object.select_all(action="DESELECT")
for o in meshes: o.select_set(True)
bpy.context.view_layer.objects.active = meshes[0]
if len(meshes) > 1: bpy.ops.object.join()
high = bpy.context.view_layer.objects.active
high.name = name + "_high"
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
tris = sum(len(p.vertices) - 2 for p in high.data.polygons)
log(f"input tris {tris}")

# ---- low-poly copy: weld, then collapse decimate in passes (shape only, UVs discarded)
low = high.copy(); low.data = high.data.copy(); low.name = name
bpy.context.scene.collection.objects.link(low)
bpy.ops.object.select_all(action="DESELECT"); low.select_set(True)
bpy.context.view_layer.objects.active = low
bpy.ops.object.mode_set(mode="EDIT"); bpy.ops.mesh.select_all(action="SELECT")
bpy.ops.mesh.remove_doubles(threshold=0.0005); bpy.ops.object.mode_set(mode="OBJECT")
while low.data.uv_layers: low.data.uv_layers.remove(low.data.uv_layers[0])
span0 = max(high.dimensions)
if mode.startswith("remesh"):
    # voxel remesh: watertight solid shell, thin junk (cables, railings) fused or dropped
    mod = low.modifiers.new("Remesh", "REMESH")
    mod.mode = "VOXEL"; mod.voxel_size = span0 / voxel_div; mod.use_smooth_shade = False
    bpy.ops.object.modifier_apply(modifier=mod.name)
    cur = sum(len(p.vertices) - 2 for p in low.data.polygons)
    log(f"voxel remesh ({span0/voxel_div:.4f}): {cur} tris")
def collapse_to(goal):
    global cur
    passes = 0
    while cur > goal and passes < 8:
        passes += 1
        mod = low.modifiers.new("Decimate", "DECIMATE")
        mod.ratio = max(goal / cur, 0.02)
        mod.use_collapse_triangulate = True
        bpy.ops.object.modifier_apply(modifier=mod.name)
        cur = sum(len(p.vertices) - 2 for p in low.data.polygons)
        log(f"decimate pass {passes}: {cur} tris")
cur = sum(len(p.vertices) - 2 for p in low.data.polygons)
if mode == "remesh_planar":
    collapse_to(max(target_tris * 6, 40000))
    mod = low.modifiers.new("Planar", "DECIMATE")
    mod.decimate_type = "DISSOLVE"; mod.angle_limit = math.radians(6); mod.use_dissolve_boundaries = False
    bpy.ops.object.modifier_apply(modifier=mod.name)
    bpy.ops.object.mode_set(mode="EDIT"); bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.mesh.quads_convert_to_tris(); bpy.ops.object.mode_set(mode="OBJECT")
    cur = sum(len(p.vertices) - 2 for p in low.data.polygons)
    log(f"planar dissolve: {cur} tris")
collapse_to(target_tris)
try: bpy.ops.object.shade_smooth_by_angle(angle=math.radians(35))
except Exception: bpy.ops.object.shade_smooth()

# ---- fresh UVs on the low-poly
bpy.ops.object.mode_set(mode="EDIT"); bpy.ops.mesh.select_all(action="SELECT")
bpy.ops.uv.smart_project(angle_limit=math.radians(66), island_margin=0.003, correct_aspect=True, scale_to_bounds=False)
bpy.ops.object.mode_set(mode="OBJECT")
log("unwrapped")

# ---- bake material on low: one image node per bake target
img = bpy.data.images.new(name + "_basecolor", tex, tex, alpha=False)
img.generated_color = (0.5, 0.5, 0.5, 1)
mat = bpy.data.materials.new(name + "_mat"); mat.use_nodes = True
nt = mat.node_tree
bsdf = nt.nodes.get("Principled BSDF")
texnode = nt.nodes.new("ShaderNodeTexImage"); texnode.image = img
nt.links.new(texnode.outputs["Color"], bsdf.inputs["Base Color"])
nt.nodes.active = texnode
low.data.materials.clear(); low.data.materials.append(mat)

# high-poly materials: make sure base colour is what gets baked (kill emission/specular noise)
for m in high.data.materials:
    if m and m.use_nodes:
        b = m.node_tree.nodes.get("Principled BSDF")
        if b:
            for k in ("Metallic", "Specular IOR Level", "Emission Strength"):
                if k in b.inputs: b.inputs[k].default_value = 0.0
            if "Roughness" in b.inputs: b.inputs["Roughness"].default_value = 1.0

# ---- bake settings
sc = bpy.context.scene
sc.render.engine = "CYCLES"
sc.cycles.device = "CPU"
sc.cycles.samples = samples
sc.cycles.use_denoising = False
sc.render.bake.use_selected_to_active = True
sc.render.bake.use_cage = False
span = max(high.dimensions)
sc.render.bake.cage_extrusion = span * 0.01
sc.render.bake.max_ray_distance = span * 0.05
sc.render.bake.margin = 8
sc.render.bake.use_pass_direct = False
sc.render.bake.use_pass_indirect = False
sc.render.bake.use_pass_color = True
bpy.ops.object.select_all(action="DESELECT")
high.select_set(True); low.select_set(True)
bpy.context.view_layer.objects.active = low
log("baking base colour")
bpy.ops.object.bake(type="DIFFUSE", pass_filter={"COLOR"}, use_selected_to_active=True,
                    cage_extrusion=span * 0.01, max_ray_distance=span * 0.05, margin=8)
os.makedirs(os.path.dirname(dst), exist_ok=True)
texdir = os.path.join(os.path.dirname(dst), name + ".fbm"); os.makedirs(texdir, exist_ok=True)
img.filepath_raw = os.path.join(texdir, name + "_basecolor.png"); img.file_format = "PNG"; img.save()
texnode.image = bpy.data.images.load(img.filepath_raw)
log("baked")

# ---- export only the low-poly
bpy.data.objects.remove(high, do_unlink=True)
bpy.ops.object.select_all(action="DESELECT"); low.select_set(True)
bpy.context.view_layer.objects.active = low
bpy.ops.export_scene.fbx(filepath=dst, use_selection=True, path_mode="COPY", embed_textures=True,
                         apply_scale_options="FBX_SCALE_ALL")
log(f"exported {dst} tris={cur}")

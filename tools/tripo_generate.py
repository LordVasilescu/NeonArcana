# Text -> 3D model via Tripo AI, auto-converted to Roblox-ready FBX.
#   python tools/tripo_generate.py "low-poly cyberpunk hoverboard, neon accents" hoverboard [--tris 8000]
# Requires TRIPO_API_KEY in environment or in .env at the project root.
# Pipeline: submit task -> poll -> download GLB to assets/raw/ -> Blender decimate+export to assets/export/

import json
import os
import pathlib
import subprocess
import sys
import time
import urllib.request

ROOT = pathlib.Path(__file__).resolve().parent.parent
API = "https://api.tripo3d.ai/v2/openapi"


def find_blender() -> str:
    """BLENDER_PATH env var, then the standard installer location (newest version), then Steam."""
    candidates = []
    if os.environ.get("BLENDER_PATH"):
        candidates.append(pathlib.Path(os.environ["BLENDER_PATH"]))
    foundation = pathlib.Path(r"C:\Program Files\Blender Foundation")
    if foundation.exists():
        for folder in sorted(foundation.iterdir(), reverse=True):
            candidates.append(folder / "blender.exe")
    candidates.append(pathlib.Path(r"C:\Program Files (x86)\Steam\steamapps\common\Blender\blender.exe"))
    for candidate in candidates:
        if candidate.exists():
            return str(candidate)
    sys.exit("Blender not found. Install it (winget install BlenderFoundation.Blender) or set BLENDER_PATH.")


BLENDER = find_blender()


def load_env():
    env_file = ROOT / ".env"
    if env_file.exists():
        for line in env_file.read_text().splitlines():
            line = line.strip()
            if line and not line.startswith("#") and "=" in line:
                key, value = line.split("=", 1)
                os.environ.setdefault(key.strip(), value.strip())


def api_call(path, payload=None, key=None):
    req = urllib.request.Request(
        API + path,
        data=json.dumps(payload).encode() if payload else None,
        headers={"Authorization": f"Bearer {key}", "Content-Type": "application/json"},
        method="POST" if payload else "GET",
    )
    with urllib.request.urlopen(req) as response:
        return json.load(response)


def main():
    load_env()
    key = os.environ.get("TRIPO_API_KEY")
    if not key:
        sys.exit("TRIPO_API_KEY not set. Put TRIPO_API_KEY=... in .env (get one at platform.tripo3d.ai)")

    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    prompt, name = args[0], args[1]
    tris = 8000
    if "--tris" in sys.argv:
        tris = int(sys.argv[sys.argv.index("--tris") + 1])

    print(f"[tripo] submitting: {prompt}")
    result = api_call("/task", {"type": "text_to_model", "prompt": prompt}, key)
    task_id = result["data"]["task_id"]
    print(f"[tripo] task {task_id} — polling...")

    model_url = None
    for _ in range(120):  # up to ~10 minutes
        time.sleep(5)
        status = api_call(f"/task/{task_id}", key=key)["data"]
        state = status.get("status")
        print(f"[tripo] {state} {status.get('progress', '')}%")
        if state == "success":
            output = status.get("output", {})
            model_url = output.get("pbr_model") or output.get("model")
            break
        if state in ("failed", "cancelled", "banned"):
            sys.exit(f"[tripo] task ended: {state}")
    if not model_url:
        sys.exit("[tripo] timed out waiting for the model")

    raw = ROOT / "assets" / "raw" / f"{name}.glb"
    raw.parent.mkdir(parents=True, exist_ok=True)
    print(f"[tripo] downloading -> {raw}")
    urllib.request.urlretrieve(model_url, raw)

    out = ROOT / "assets" / "export" / f"{name}.fbx"
    print(f"[blender] converting -> {out} (target {tris} tris)")
    subprocess.run(
        [BLENDER, "--background", "--python", str(ROOT / "tools" / "tripo_to_roblox.py"),
         "--", str(raw), str(out), str(tris)],
        check=True,
    )
    print(f"DONE: {out} — import via Studio's 3D Importer (Home -> Import 3D)")


if __name__ == "__main__":
    main()

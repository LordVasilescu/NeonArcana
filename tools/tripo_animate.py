# Auto-rig + animate a previously generated Tripo model via the API.
#   python tools/tripo_animate.py <original_task_id> <name> [preset]
#   preset: walk (default), run, idle, climb, jump, slash, shoot, hurt, fall, turn
# Flow: prerig check -> rig -> retarget with preset animation -> download FBX.

import json
import os
import pathlib
import sys
import time
import urllib.request

ROOT = pathlib.Path(__file__).resolve().parent.parent
API = "https://api.tripo3d.ai/v2/openapi"


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


def wait_for(task_id, key, label):
    for _ in range(120):
        time.sleep(4)
        data = api_call(f"/task/{task_id}", key=key)["data"]
        state = data.get("status")
        print(f"[{label}] {state} {data.get('progress', '')}%")
        if state == "success":
            return data
        if state in ("failed", "cancelled", "banned"):
            raise SystemExit(f"[{label}] task ended: {state}")
    raise SystemExit(f"[{label}] timed out")


def main():
    load_env()
    key = os.environ.get("TRIPO_API_KEY")
    if not key:
        sys.exit("TRIPO_API_KEY missing from .env")

    original = sys.argv[1]
    name = sys.argv[2]
    preset = sys.argv[3] if len(sys.argv) > 3 else "walk"

    print(f"[prerig] checking riggability of {original}")
    pre = api_call("/task", {"type": "animate_prerigcheck", "original_model_task_id": original}, key)
    pre_data = wait_for(pre["data"]["task_id"], key, "prerig")
    riggable = pre_data.get("output", {}).get("riggable")
    print(f"[prerig] riggable: {riggable}")
    if riggable is False:
        sys.exit("[prerig] model is not riggable — skip")

    print("[rig] rigging skeleton")
    rig = api_call("/task", {"type": "animate_rig", "original_model_task_id": original, "out_format": "glb"}, key)
    rig_id = rig["data"]["task_id"]
    wait_for(rig_id, key, "rig")

    print(f"[retarget] applying preset:{preset}")
    retarget = api_call(
        "/task",
        {"type": "animate_retarget", "original_model_task_id": rig_id, "animation": f"preset:{preset}", "out_format": "fbx"},
        key,
    )
    final = wait_for(retarget["data"]["task_id"], key, "retarget")
    url = final.get("output", {}).get("model")
    if not url:
        sys.exit("[retarget] no output model url")

    out = ROOT / "assets" / "animated" / f"{name}_{preset}.fbx"
    out.parent.mkdir(parents=True, exist_ok=True)
    urllib.request.urlretrieve(url, out)
    print(f"DONE: {out}")


if __name__ == "__main__":
    main()

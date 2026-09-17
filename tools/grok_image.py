# Text -> image via xAI Grok. For game icons, thumbnails, decals, UI art.
#   python tools/grok_image.py "cyberpunk wizard game icon, neon, bold" game_icon
# Requires XAI_API_KEY in environment or in .env at the project root.
# Output: assets/images/<name>.png (upload to Roblox via Creator Dashboard -> Decals)

import base64
import json
import os
import pathlib
import sys
import urllib.request

ROOT = pathlib.Path(__file__).resolve().parent.parent


def load_env():
    env_file = ROOT / ".env"
    if env_file.exists():
        for line in env_file.read_text().splitlines():
            line = line.strip()
            if line and not line.startswith("#") and "=" in line:
                key, value = line.split("=", 1)
                os.environ.setdefault(key.strip(), value.strip())


def main():
    load_env()
    key = os.environ.get("XAI_API_KEY")
    if not key:
        sys.exit("XAI_API_KEY not set. Put XAI_API_KEY=... in .env (get one at console.x.ai)")

    prompt, name = sys.argv[1], sys.argv[2]
    req = urllib.request.Request(
        "https://api.x.ai/v1/images/generations",
        data=json.dumps({"model": "grok-2-image", "prompt": prompt, "response_format": "b64_json"}).encode(),
        headers={"Authorization": f"Bearer {key}", "Content-Type": "application/json"},
    )
    print(f"[grok] generating: {prompt}")
    with urllib.request.urlopen(req) as response:
        data = json.load(response)

    out = ROOT / "assets" / "images" / f"{name}.png"
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_bytes(base64.b64decode(data["data"][0]["b64_json"]))
    print(f"DONE: {out}")


if __name__ == "__main__":
    main()

"""Translate generated frames to common roots; never resize individual poses."""
import json
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[1] / "assets/production/hero/v2"
for action in ("idle", "walk", "jump", "interact"):
    directory = ROOT / action
    meta = json.loads((directory / "pipeline-meta.json").read_text(encoding="utf-8"))
    frames = []
    shifts = []
    for label in meta["frame_labels"]:
        image = Image.open(directory / f"{label}.png").convert("RGBA")
        mask = image.getchannel("A").point(lambda alpha: 255 if alpha >= 32 else 0)
        bounds = mask.getbbox()
        top = mask.crop((0, bounds[1], 128, bounds[1] + max(8, round((bounds[3]-bounds[1])*.17)))).getbbox()
        dx = round(64 - (top[0] + top[2]) / 2)
        dy = 125 - bounds[3] if action != "jump" else 0
        if bounds[0]+dx < 1 or bounds[2]+dx > 127 or bounds[1]+dy < 1 or bounds[3]+dy > 127:
            raise ValueError(f"Unsafe root shift: {action}/{label}")
        aligned = Image.new("RGBA", (128, 128))
        aligned.paste(image, (dx, dy))
        aligned.save(directory / f"{label}.png")
        frames.append(aligned)
        shifts.append([dx, dy])
    sheet = Image.new("RGBA", (128 * meta["cols"], 128 * meta["rows"]))
    for index, image in enumerate(frames):
        sheet.paste(image, ((index % meta["cols"])*128, (index // meta["cols"])*128))
    sheet.save(directory / "sheet-transparent.png")
    frames[0].save(directory / "animation.gif", save_all=True, append_images=frames[1:],
                   duration=70 if action == "walk" else 100, loop=0, disposal=2)
    (directory / "root-alignment.json").write_text(json.dumps({
        "translation_only": True, "head_center_x": 64, "feet_y": 125 if action != "jump" else None,
        "frame_shifts": shifts, "source_scale_profile": "../character-scale-profile.json"
    }, indent=2), encoding="utf-8")
    print(action, len(frames), "root aligned, no pose rescaling")

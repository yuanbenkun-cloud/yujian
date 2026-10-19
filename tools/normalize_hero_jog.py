"""Root alignment for generated jogging frames, retaining short flight poses."""
import json
from pathlib import Path
from PIL import Image

root = Path(__file__).resolve().parents[1] / "assets/production/hero/v2/jog"
frames = []
for index in range(1, 13):
    path = root / f"jog-{index}.png"
    image = Image.open(path).convert("RGBA")
    mask = image.getchannel("A").point(lambda alpha: 255 if alpha >= 32 else 0)
    bounds = mask.getbbox()
    head = mask.crop((0, bounds[1], 128, bounds[1]+14)).getbbox()
    dx = round(64 - (head[0]+head[2])/2)
    flight = index in (4, 5, 9, 10)
    dy = (35 - bounds[1]) if flight else (125 - bounds[3])
    aligned = Image.new("RGBA", (128, 128))
    aligned.paste(image, (dx, dy))
    final = aligned.getbbox()
    assert final and final[0] > 0 and final[1] > 0 and final[2] < 128 and final[3] < 128
    aligned.save(path)
    frames.append(aligned)
sheet = Image.new("RGBA", (384, 512))
for index, image in enumerate(frames):
    sheet.paste(image, ((index % 3)*128, (index // 3)*128))
sheet.save(root / "sheet-transparent.png")
frames[0].save(root / "animation.gif", save_all=True, append_images=frames[1:], duration=65, loop=0, disposal=2)
(root / "root-alignment.json").write_text(json.dumps({"translation_only": True,
    "head_center_x": 64, "grounded_feet_y": 125, "flight_frames": [4,5,9,10],
    "no_per_frame_scaling": True}, indent=2), encoding="utf-8")
print("12 jogging frames aligned; four flight frames retained")

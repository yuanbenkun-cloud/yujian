"""Translate generated poses onto the accepted idle scale/root; never resize per frame."""
from __future__ import annotations

import json
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "art_source/hero-jog-v3-oct18/processed"
OUTPUT = ROOT / "assets/production/hero/v3/jog"


def mask(image: Image.Image) -> Image.Image:
    return image.getchannel("A").point(lambda alpha: 255 if alpha >= 32 else 0)


def despill(image: Image.Image) -> None:
    # Remove magenta chroma residue only; no costume colors meet this test.
    pixels = image.load()
    for y in range(image.height):
        for x in range(image.width):
            r, g, b, alpha = pixels[x, y]
            if alpha and r > g + 25 and b > g + 25:
                spill = min(r, b) - g
                alpha = round(alpha * max(0.0, 1.0 - spill / 100.0))
                pixels[x, y] = (min(r, g + 12), g, min(b, g + 8), alpha)


def main() -> None:
    idle = Image.open(ROOT / "assets/production/hero/v2/idle/idle-1.png").convert("RGBA")
    idle_bounds = mask(idle).getbbox()
    head = mask(idle).crop((0, idle_bounds[1], 128, idle_bounds[1] + 14)).getbbox()
    head_center = (head[0] + head[2]) / 2
    OUTPUT.mkdir(parents=True, exist_ok=True)
    frames = []
    bounds_list = []
    sheet = Image.new("RGBA", (512, 256))
    for index in range(1, 9):
        image = Image.open(SOURCE / f"jog-{index}.png").convert("RGBA")
        despill(image)
        visible = mask(image)
        bounds = visible.getbbox()
        head = visible.crop((0, bounds[1], 128, bounds[1] + 14)).getbbox()
        dx = round(head_center - (head[0] + head[2]) / 2)
        # A short jog has two tiny flight recoveries, not four long suspended poses.
        baseline = 124 if index in (4, 8) else 125
        dy = baseline - bounds[3]
        aligned = Image.new("RGBA", (128, 128))
        aligned.alpha_composite(image, (dx, dy))
        after = mask(aligned).getbbox()
        assert after and after[0] > 0 and after[1] > 0 and after[2] < 128 and after[3] <= 125
        assert after[2] - after[0] == bounds[2] - bounds[0]
        assert abs((after[3] - after[1]) - 88) <= 7
        aligned.save(OUTPUT / f"jog-{index}.png")
        sheet.alpha_composite(aligned, (((index - 1) % 4) * 128, ((index - 1) // 4) * 128))
        frames.append(aligned)
        bounds_list.append(after)
    sheet.save(OUTPUT / "sheet-transparent.png")
    frames[0].save(SOURCE.parent / "animation.gif", save_all=True, append_images=frames[1:],
                   duration=83, loop=0, disposal=2)
    report = {"frames": 8, "fps": 12, "translation_only": True,
              "idle_bbox": idle_bounds, "head_center_x": head_center,
              "grounded_feet_y": 125, "flight_feet_y": 124,
              "flight_frames": [4, 8], "bboxes": bounds_list,
              "no_per_frame_resizing": True}
    (SOURCE.parent / "integration-qc.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
    print(json.dumps(report))


if __name__ == "__main__":
    main()

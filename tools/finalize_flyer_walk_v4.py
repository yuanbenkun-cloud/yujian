"""Align the generated walk frames to the existing idle scale and shoe baseline.

No pose drawing or per-frame resizing: generated artwork remains the source.
"""
from __future__ import annotations

from pathlib import Path
import json

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "art_source/flyer-walk-v4-oct18/processed"
OUTPUT = ROOT / "assets/production/npc/cast_v3/flyer_lady/walk-v4"
IDLE = ROOT / "assets/production/npc/cast_v3/flyer_lady/idle-transparent.png"


def bbox(image: Image.Image) -> tuple[int, int, int, int]:
    result = image.getchannel("A").point(lambda alpha: 255 if alpha >= 31 else 0).getbbox()
    if result is None:
        raise ValueError("Empty frame")
    return result


def main() -> None:
    OUTPUT.mkdir(parents=True, exist_ok=True)
    idle_box = bbox(Image.open(IDLE).convert("RGBA"))
    baseline = idle_box[3]
    sheet = Image.new("RGBA", (512, 256))
    frames = []
    boxes = []
    for index in range(8):
        frame = Image.open(SOURCE / f"walk-{index + 1}.png").convert("RGBA")
        before = bbox(frame)
        offset = baseline - before[3]
        if before[1] + offset < 0 or before[3] + offset > 128:
            raise ValueError("Baseline adjustment would clip the sprite")
        aligned = Image.new("RGBA", (128, 128))
        aligned.alpha_composite(frame, (0, offset))
        bounds = bbox(aligned)
        assert bounds[3] == baseline
        assert abs((bounds[3] - bounds[1]) - (idle_box[3] - idle_box[1])) <= 5
        aligned.save(OUTPUT / f"walk-{index + 1}.png")
        sheet.alpha_composite(aligned, ((index % 4) * 128, (index // 4) * 128))
        frames.append(aligned)
        boxes.append(bounds)
    sheet.save(OUTPUT / "sheet-transparent.png")
    # GIF is developer preview only, not a game texture.
    frames[0].save(SOURCE.parent / "walk-v4-preview.gif", save_all=True,
                   append_images=frames[1:], duration=83, loop=0, disposal=2)
    report = {"source": "raw.png (built-in image generation)", "frames": 8,
              "columns": 4, "cell_size": 128, "fps": 12,
              "idle_bbox": idle_box, "shared_shoe_baseline": baseline,
              "walk_bboxes": boxes, "per_frame_rescale": False}
    (SOURCE.parent / "integration-qc.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
    print(json.dumps(report))


if __name__ == "__main__":
    main()

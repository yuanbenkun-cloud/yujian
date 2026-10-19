from __future__ import annotations

from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1] / "assets" / "production" / "backgrounds" / "06_future"
SIZE = (1280, 720)


def main() -> None:
    sky = Image.open(ROOT / "sky.png").convert("RGBA")
    far = Image.open(ROOT / "far.png").convert("RGBA")
    mid = Image.open(ROOT / "mid.png").convert("RGBA")
    ground = Image.open(ROOT / "ground.png").convert("RGBA")
    train = Image.open(ROOT / "monorail.png").convert("RGBA")
    train = train.resize((640, 160), Image.Resampling.LANCZOS)

    # The future tower is a purpose-built monorail station.  Repaint only the
    # tunnel-side tower over the moving train so the cars visibly enter the
    # portal instead of floating in front of the facade.
    occluder = Image.new("RGBA", SIZE, (0, 0, 0, 0))
    for box in ((940, 0, 1280, 720),):
        occluder.alpha_composite(mid.crop(box), (box[0], box[1]))
    occluder.save(ROOT / "monorail-occluder.png", optimize=True)

    preview = Image.alpha_composite(Image.alpha_composite(sky, far), mid)
    # The resized car body sits around y=46..114 in this canvas.  At y=175 it
    # rides inside the dedicated guideway, independent from the playfield.
    preview.alpha_composite(train, (360, 175))
    preview = Image.alpha_composite(preview, occluder)
    preview = Image.alpha_composite(preview, ground)
    preview.convert("RGB").save(ROOT / "runtime-preview.png", optimize=True)
    preview.convert("RGB").save(ROOT / "runtime-preview-v2.png", optimize=True)
    print("[PASS] future background runtime preview and monorail occluder generated")


if __name__ == "__main__":
    main()

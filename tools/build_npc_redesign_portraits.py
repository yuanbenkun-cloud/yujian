from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
SOURCE_ROOT = ROOT / "art_source" / "npc_redesign"
PORTRAIT_ROOT = ROOT / "assets" / "portraits"
KEYS = (
    "flyer_lady",
    "old_artisan",
    "aming",
    "old_shopkeeper",
    "fat_teahouse",
    "helper",
    "laozhou",
    "old_man",
)
CANVAS_SIZE = (384, 512)
SUBJECT_MAX_SIZE = (344, 476)


def build_portrait(key: str) -> None:
    source = SOURCE_ROOT / key / "processed" / "walk-1.png"
    image = Image.open(source).convert("RGBA")
    alpha = image.getchannel("A")
    bbox = alpha.getbbox()
    if bbox is None:
        raise RuntimeError(f"empty portrait source: {source}")
    subject = image.crop(bbox)
    scale = min(
        SUBJECT_MAX_SIZE[0] / subject.width,
        SUBJECT_MAX_SIZE[1] / subject.height,
    )
    resized = subject.resize(
        (max(1, round(subject.width * scale)), max(1, round(subject.height * scale))),
        Image.Resampling.NEAREST,
    )
    canvas = Image.new("RGBA", CANVAS_SIZE, (0, 0, 0, 0))
    x = (CANVAS_SIZE[0] - resized.width) // 2
    y = CANVAS_SIZE[1] - resized.height - 8
    canvas.alpha_composite(resized, (x, y))
    canvas.save(PORTRAIT_ROOT / f"{key}.png", optimize=True)


def main() -> None:
    for key in KEYS:
        build_portrait(key)
        print(f"[PASS] portrait {key}")


if __name__ == "__main__":
    main()

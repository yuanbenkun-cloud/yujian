from __future__ import annotations

from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1] / "assets" / "production" / "backgrounds"
TARGET_SIZE = (1280, 720)
MONORAIL_SIZE = (768, 192)


def resize_layer(source: Path, target: Path, alpha: bool) -> Image.Image:
    mode = "RGBA" if alpha else "RGB"
    with Image.open(source) as image:
        normalized = image.convert(mode).resize(TARGET_SIZE, Image.Resampling.LANCZOS)
    normalized.save(target, optimize=True)
    return normalized.convert("RGBA")


def normalize_cutout(source: Path, target: Path, canvas_size: tuple[int, int]) -> None:
    """Trim transparent generation padding, then fit on a stable centered runtime canvas."""
    with Image.open(source) as image:
        rgba = image.convert("RGBA")
        alpha = rgba.getchannel("A")
        bbox = alpha.point(lambda value: 255 if value >= 16 else 0).getbbox()
        if bbox is None:
            raise ValueError(f"No visible pixels in {source}")
        cropped = rgba.crop(bbox)
        max_width = canvas_size[0] - 32
        max_height = canvas_size[1] - 24
        scale = min(max_width / cropped.width, max_height / cropped.height)
        fitted = cropped.resize(
            (max(1, round(cropped.width * scale)), max(1, round(cropped.height * scale))),
            Image.Resampling.LANCZOS,
        )
        canvas = Image.new("RGBA", canvas_size, (0, 0, 0, 0))
        canvas.alpha_composite(
            fitted,
            ((canvas_size[0] - fitted.width) // 2, (canvas_size[1] - fitted.height) // 2),
        )
        canvas.save(target, optimize=True)


def main() -> None:
    for era in ("01", "02", "03", "04", "05", "06_future"):
        folder = ROOT / era
        sky = resize_layer(folder / "sky-raw.png", folder / "sky.png", False)
        far = resize_layer(folder / "far-raw.png", folder / "far.png", True)
        mid = resize_layer(folder / "mid-raw.png", folder / "mid.png", True)
        preview = Image.alpha_composite(Image.alpha_composite(sky, far), mid)
        preview.convert("RGB").save(folder / "layered-preview.png", optimize=True)
        ground_source = folder / "ground-raw.png"
        if ground_source.exists():
            resize_layer(ground_source, folder / "ground.png", True)
        monorail_source = folder / "monorail-raw.png"
        if monorail_source.exists():
            normalize_cutout(monorail_source, folder / "monorail.png", MONORAIL_SIZE)
        print(f"[PASS] {era}: {TARGET_SIZE[0]}x{TARGET_SIZE[1]}")


if __name__ == "__main__":
    main()

from __future__ import annotations

from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "art_source" / "npc_cast_v2"
OUTPUT = ROOT / "assets" / "production" / "npc" / "cast_v2"
CAST = (
    "flyer_lady",
    "old_artisan",
    "aming",
    "old_shopkeeper",
    "fat_teahouse",
    "helper",
    "laozhou",
    "old_man",
    "tourist",
    "vendor",
    "refugee",
)
SOURCE_CELL = (512, 512)
RUNTIME_CELL = (256, 256)


def alpha_bbox(image: Image.Image) -> tuple[int, int, int, int]:
    alpha = image.getchannel("A").point(lambda value: 255 if value >= 18 else 0)
    bbox = alpha.getbbox()
    if bbox is None:
        raise ValueError("generated frame has no visible pixels")
    return bbox


def extract_cells(source: Image.Image) -> list[Image.Image]:
    cells: list[Image.Image] = []
    for index in range(6):
        x = (index % 3) * SOURCE_CELL[0]
        y = (index // 3) * SOURCE_CELL[1]
        cells.append(source.crop((x, y, x + SOURCE_CELL[0], y + SOURCE_CELL[1])))
    return cells


def normalize_frames(cells: list[Image.Image]) -> list[Image.Image]:
    bounds = [alpha_bbox(cell) for cell in cells]
    max_width = max(right - left for left, _top, right, _bottom in bounds)
    max_height = max(bottom - top for _left, top, _right, bottom in bounds)
    scale = min(220.0 / max_width, 232.0 / max_height)
    normalized: list[Image.Image] = []
    for cell, bbox in zip(cells, bounds):
        subject = cell.crop(bbox)
        size = (max(1, round(subject.width * scale)), max(1, round(subject.height * scale)))
        subject = subject.resize(size, Image.Resampling.LANCZOS)
        canvas = Image.new("RGBA", RUNTIME_CELL, (0, 0, 0, 0))
        canvas.alpha_composite(subject, ((RUNTIME_CELL[0] - size[0]) // 2, 246 - size[1]))
        normalized.append(canvas)
    return normalized


def build_portrait(source_idle: Image.Image) -> Image.Image:
    bbox = alpha_bbox(source_idle)
    left, top, right, bottom = bbox
    subject_height = bottom - top
    # Dialogue art is always cut from the neutral first cell, never a locomotion frame.
    bust = source_idle.crop((left, top, right, top + round(subject_height * 0.68)))
    scale = min(460.0 / bust.width, 490.0 / bust.height)
    bust = bust.resize(
        (max(1, round(bust.width * scale)), max(1, round(bust.height * scale))),
        Image.Resampling.LANCZOS,
    )
    canvas = Image.new("RGBA", (512, 512), (0, 0, 0, 0))
    canvas.alpha_composite(bust, ((512 - bust.width) // 2, 512 - bust.height))
    return canvas


def process_character(character_id: str) -> None:
    source_path = SOURCE / f"{character_id}-raw.png"
    with Image.open(source_path) as image:
        source = image.convert("RGBA")
    if source.size != (1536, 1024):
        raise ValueError(f"{source_path} expected 1536x1024, got {source.size}")
    cells = extract_cells(source)
    frames = normalize_frames(cells)
    output_dir = OUTPUT / character_id
    output_dir.mkdir(parents=True, exist_ok=True)
    sheet = Image.new("RGBA", (768, 512), (0, 0, 0, 0))
    for index, frame in enumerate(frames):
        sheet.alpha_composite(frame, ((index % 3) * 256, (index // 3) * 256))
    sheet.save(output_dir / "sheet-transparent.png", optimize=True)
    frames[0].save(output_dir / "idle-transparent.png", optimize=True)
    build_portrait(cells[0]).save(output_dir / "portrait.png", optimize=True)
    print(f"[PASS] {character_id}")


def main() -> None:
    for character_id in CAST:
        process_character(character_id)


if __name__ == "__main__":
    main()

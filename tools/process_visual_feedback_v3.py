from pathlib import Path
import shutil
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
RAW = Path('C:/Users/Administrator/.codex/generated_images/01a089e5-7618-7173-ba4a-b8135a10f95d')
ARCHIVE = ROOT / 'art_source/visual_feedback_v3'
ARCHIVE.mkdir(parents=True, exist_ok=True)
(ARCHIVE / '.gdignore').touch()

PORTRAITS = [
    ('exec-9cd2db5d-4c19-4e2a-b392-4c8f5fc257d8.png', ['flyer_lady', 'old_artisan', 'aming', 'old_shopkeeper']),
    ('exec-745294fe-c985-4f63-9faa-f0b37597e779.png', ['fat_teahouse', 'helper', 'laozhou', 'old_man']),
    ('exec-146f9013-ea22-4817-aecc-76d55639d1ee.png', ['tourist', 'vendor', 'refugee']),
]

def content(image, threshold=32):
    mask = image.getchannel('A').point(lambda v: 255 if v >= threshold else 0)
    bounds = mask.getbbox()
    if bounds is None:
        raise ValueError('Empty image cell')
    return image.crop(bounds)

def fit(image, size, margin, nearest=False):
    width, height = size
    ratio = min((width - margin * 2) / image.width, (height - margin * 2) / image.height)
    image = image.resize((round(image.width * ratio), round(image.height * ratio)),
                         Image.Resampling.NEAREST if nearest else Image.Resampling.LANCZOS)
    canvas = Image.new('RGBA', size)
    canvas.paste(image, ((width - image.width) // 2, height - margin - image.height))
    return canvas

for filename, keys in PORTRAITS:
    source = Image.open(RAW / filename).convert('RGBA')
    shutil.copy2(RAW / filename, ARCHIVE / filename)
    for index, key in enumerate(keys):
        column, row = index % 2, index // 2
        cell = source.crop((column * source.width // 2, row * source.height // 2,
                            (column + 1) * source.width // 2, (row + 1) * source.height // 2))
        path = ROOT / f'assets/production/npc/cast_v3/{key}/portrait.png'
        shutil.copy2(path, ARCHIVE / f'{key}-previous-portrait.png')
        fit(content(cell), (384, 512), 12).save(path)
        print('portrait', key)

filename = 'exec-5c891622-15a3-4957-9fd8-fba20433bcc5.png'
source = Image.open(RAW / filename).convert('RGBA')
shutil.copy2(RAW / filename, ARCHIVE / filename)
frames = []
for index in range(6):
    column, row = index % 3, index // 3
    cell = source.crop((column * source.width // 3, row * source.height // 2,
                        (column + 1) * source.width // 3, (row + 1) * source.height // 2))
    cell = content(cell, 100)
    if row == 1:
        cell = cell.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
    frames.append(cell)
outdir = ROOT / 'assets/production/npc/water_carrier'
outdir.mkdir(parents=True, exist_ok=True)
sheet = Image.new('RGBA', (384, 256))
for index, cell in enumerate(frames):
    # Same visible person height as hero; the suspended buckets remain above the feet.
    height = 88
    width = round(cell.width * height / cell.height)
    cell = cell.resize((width, height), Image.Resampling.NEAREST)
    alpha = cell.getchannel('A').point(lambda v: 255 if v >= 100 else 0)
    cell.putalpha(alpha)
    frame = Image.new('RGBA', (128, 128))
    frame.paste(cell, ((128 - width) // 2, 112 - height))
    frame.save(outdir / f'walk-{index + 1}.png')
    sheet.paste(frame, ((index % 3) * 128, (index // 3) * 128))
sheet.save(outdir / 'walk-sheet.png')

filename = 'exec-64d30fae-839f-40ca-883d-a7b1ed65287b.png'
shutil.copy2(RAW / filename, ARCHIVE / filename)
lantern = fit(content(Image.open(RAW / filename).convert('RGBA'), 100), (48, 64), 2, True)
path = ROOT / 'assets/production/props/gameplay/carried-lantern-v3.png'
lantern.save(path)
print('water carrier six frames and lantern ready')

from pathlib import Path
from PIL import Image

root = Path(__file__).resolve().parents[1]
source = Path("C:/Users/Administrator/.codex/generated_images/01a089e5-7618-7173-ba4a-b8135a10f95d/exec-d681d871-2aff-4b4e-b99d-840b4fc7c59e.png")
image = Image.open(source).convert("RGBA")
image.resize((1280, 720), Image.Resampling.NEAREST).save(root / "assets/production/backgrounds/06_future/city-backdrop-v6.png")
print("Saved 1280x720 scenery-only replacement; original preserved")

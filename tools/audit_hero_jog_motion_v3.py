"""Measure frame placement and scale before deciding how to repair locomotion."""
from pathlib import Path
import json
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]

for action, count in [("jog", 12), ("idle", 6)]:
    report = []
    for index in range(1, count + 1):
        image = Image.open(ROOT / f"assets/production/hero/v2/{action}/{action}-{index}.png").convert("RGBA")
        bounds = image.getchannel("A").point(lambda value: 255 if value >= 32 else 0).getbbox()
        report.append({"frame": index, "bbox": bounds, "height": bounds[3] - bounds[1], "ground_gap": 125 - bounds[3]})
    print(action + ": " + json.dumps(report))

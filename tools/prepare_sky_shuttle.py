"""Mechanical alpha cleanup/crop and deterministic sky-shuttle flyby sound."""
from pathlib import Path
import wave
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
folder = ROOT / 'assets/production/future/sky-shuttle-v1'
image = Image.open(folder / 'single-1.png').convert('RGBA')
pixels = np.array(image)
r, g, b = [pixels[:, :, n].astype(int) for n in range(3)]
# Remove chroma-key fringe, preserving blue thrusters and amber windows.
pixels[:, :, 3][(r > g * 1.3 + 20) & (b > g * 1.3 + 20)] = 0
image = Image.fromarray(pixels)
image = image.crop(image.getbbox())
canvas = Image.new('RGBA', (image.width + 8, image.height + 8))
canvas.paste(image, (4, 4))
canvas.save(folder / 'shuttle.png')
rate, duration = 22050, 6.0
t = np.arange(int(rate * duration)) / rate
rng = np.random.default_rng(6026)
noise = rng.normal(0, 1, len(t))
noise = np.convolve(noise, np.ones(16) / 16, mode='same')
envelope = np.sin(np.pi * t / duration) ** 1.8
phase = 2 * np.pi * (125 * t - 4 * t * t)
signal = envelope * (0.22 * np.sin(phase) + 0.08 * np.sin(phase * 2.02) + noise * 0.26)
pan = np.linspace(0.1, 0.9, len(t))
stereo = np.stack([signal * np.sqrt(1 - pan), signal * np.sqrt(pan)], axis=1)
path = ROOT / 'assets/audio/future/第6关-飞船掠空.wav'
with wave.open(str(path), 'wb') as sound:
    sound.setnchannels(2)
    sound.setsampwidth(2)
    sound.setframerate(rate)
    sound.writeframes((stereo * 32767).astype('<i2').tobytes())
print(f'Sprite: {canvas.size}; audio: {path}')

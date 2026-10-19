"""Original procedural score and rail pass-by; no reused discarded audio."""
from pathlib import Path
import wave
import numpy as np

OUT = Path(__file__).resolve().parents[1] / 'assets/audio/future'
OUT.mkdir(parents=True, exist_ok=True)
RATE = 22050

def save(name, samples):
    samples = np.clip(samples, -0.8, 0.8)
    data = (samples * 32767).astype('<i2')
    with wave.open(str(OUT / name), 'wb') as file:
        file.setnchannels(2 if samples.ndim == 2 else 1)
        file.setsampwidth(2)
        file.setframerate(RATE)
        file.writeframes(data.tobytes())
    print(name, 'peak', round(float(np.max(np.abs(samples))), 3))

duration = 32
t = np.arange(RATE * duration) / RATE
score = np.zeros_like(t)
chords = [[146.83, 220, 293.66, 349.23], [130.81, 196, 261.63, 329.63],
          [110, 164.81, 220, 293.66], [130.81, 196, 246.94, 329.63]]
for index, chord in enumerate(chords):
    local = t - index * 8
    active = (local >= 0) & (local < 8)
    envelope = np.sin(np.pi * np.clip(local / 8, 0, 1)) ** 0.7
    for freq in chord:
        score += active * envelope * (0.035 * np.sin(2 * np.pi * freq * t)
                                      + 0.009 * np.sin(2 * np.pi * freq * 2 * t))
for beat in np.arange(0, duration, 0.5):
    local = t - beat
    mask = (local >= 0) & (local < 0.35)
    note = [440, 587.33, 659.25, 523.25][int(beat * 2) % 4]
    score += mask * 0.025 * np.exp(-np.maximum(local, 0) * 10) * np.sin(2 * np.pi * note * t)
stereo = np.column_stack([score, np.roll(score, int(RATE * 0.007))])
save('第6关-城市脉冲.wav', stereo)

t = np.arange(RATE * 6) / RATE
envelope = np.sin(np.pi * t / 6) ** 2
rail = envelope * (0.08 * np.sin(2 * np.pi * (70 * t - 2 * t * t))
                   + 0.026 * np.sin(2 * np.pi * 145 * t)
                   + 0.012 * np.sin(2 * np.pi * 620 * t))
pan = np.clip(t / 6, 0, 1)
save('第6关-轻轨穿楼.wav', np.column_stack([rail * (1 - 0.6 * pan), rail * (0.4 + 0.6 * pan)]))

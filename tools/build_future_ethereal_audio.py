"""Compose an original seamless ambient-electronic score; no external recordings.

72 seconds / 80 BPM: slowly crossfading add9/maj7 pads, sparse glass bells,
quiet data pulses, and circular stereo delay. Old city-pulse audio is untouched.
"""
from __future__ import annotations

from pathlib import Path
import json
import wave

import numpy as np

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "assets/audio/future/第6关-星河回响.wav"
RATE = 32000
DURATION = 72
COUNT = RATE * DURATION


def hz(note: int) -> float:
    return 440.0 * 2.0 ** ((note - 69) / 12.0)


def add_loop(track: np.ndarray, signal: np.ndarray, onset: float, pan: float) -> None:
    start = round(onset * RATE) % COUNT
    stereo = signal[:, None] * np.array([np.cos(pan * np.pi / 2), np.sin(pan * np.pi / 2)])
    length = min(len(signal), COUNT - start)
    track[start:start + length] += stereo[:length]
    if length < len(signal):
        track[:len(signal) - length] += stereo[length:]


def main() -> None:
    track = np.zeros((COUNT, 2), dtype=np.float32)
    t = np.arange(COUNT, dtype=np.float64) / RATE
    # Dm(add9), Bbmaj7(add9), Fmaj9, C(add9). Circular smooth overlaps.
    chords = [(50, 57, 60, 64, 69), (46, 53, 57, 60, 65),
              (41, 53, 57, 60, 67), (48, 55, 60, 62, 67)]
    for chord_index, chord in enumerate(chords):
        center = chord_index * 18.0 + 9.0
        distance = (t - center + DURATION / 2) % DURATION - DURATION / 2
        envelope = np.where(np.abs(distance) < 18, 0.5 + 0.5 * np.cos(np.pi * distance / 18), 0)
        for voice, note in enumerate(chord):
            freq = round(hz(note) * DURATION) / DURATION
            shimmer = 1.0 + 0.05 * np.sin(2 * np.pi * (voice + 2) * t / DURATION)
            tone = (np.sin(2 * np.pi * freq * t + voice * 0.4)
                    + 0.15 * np.sin(2 * np.pi * freq * 2 * t)
                    + 0.045 * np.sin(2 * np.pi * freq * 3 * t))
            amplitude = 0.014 if voice < 2 else 0.010
            pan = 0.2 + 0.6 * ((voice + chord_index) % 5) / 4
            track[:, 0] += (amplitude * tone * envelope * shimmer * np.cos(pan * np.pi / 2)).astype(np.float32)
            track[:, 1] += (amplitude * tone * envelope * shimmer * np.sin(pan * np.pi / 2)).astype(np.float32)

    # Bell melody deliberately leaves whole bars empty; rounded attack, no harsh transient.
    melody = [(74, 81, 76, 72), (77, 81, 72, 74),
              (76, 79, 81, 72), (74, 79, 76, 72)]
    local = np.arange(8 * RATE, dtype=np.float64) / RATE
    envelope = (1 - np.exp(-local / 0.055)) * np.exp(-local / 1.8)
    envelope *= np.minimum(1, (8 - local) / 0.5)
    for section, notes in enumerate(melody):
        for index, note in enumerate(notes):
            freq = hz(note)
            bell = (np.sin(2 * np.pi * freq * local)
                    + 0.19 * np.sin(2 * np.pi * freq * 2.01 * local) * np.exp(-local / 0.7)
                    + 0.07 * np.sin(2 * np.pi * freq * 3.98 * local) * np.exp(-local / 0.4))
            add_loop(track, bell * envelope * 0.032, section * 18 + [1.5, 6, 10.5, 15][index], 0.27 if index % 2 == 0 else 0.73)

    # Soft two-beat electronic pulse, not a percussion track.
    pulse_time = np.arange(int(0.55 * RATE)) / RATE
    pulse_env = (1 - np.exp(-pulse_time / 0.018)) * np.exp(-pulse_time / 0.11)
    pulse_env *= np.minimum(1, (0.55 - pulse_time) / 0.08)
    for index, onset in enumerate(np.arange(0, DURATION, 1.5)):
        chord = chords[int(onset // 18) % 4]
        freq = hz(chord[2] + (12 if index % 4 == 3 else 0))
        pulse = np.sin(2 * np.pi * freq * pulse_time) * pulse_env * 0.011
        add_loop(track, pulse, float(onset), 0.42 if index % 2 == 0 else 0.58)

    # Circular stereo delays retain their tails across the end/start seam.
    dry = track.copy()
    for delay, gain in [(0.375, 0.20), (0.75, 0.15), (1.125, 0.11), (1.875, 0.075), (3.0, 0.045)]:
        track += np.roll(dry[:, ::-1], round(delay * RATE), axis=0) * gain
    track -= track.mean(axis=0)
    rms = float(np.sqrt(np.mean(track.astype(np.float64) ** 2)))
    gain = min(0.065 / max(rms, 1e-9), 0.55 / max(float(np.abs(track).max()), 1e-9))
    track *= gain
    peak = float(np.abs(track).max())
    seam = float(np.max(np.abs(track[0] - track[-1])))
    assert peak <= 0.551 and seam < 0.02
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(OUTPUT), "wb") as audio:
        audio.setnchannels(2)
        audio.setsampwidth(2)
        audio.setframerate(RATE)
        audio.writeframes(np.round(track * 32767).astype("<i2").tobytes())
    report = {"title": "星河回响", "duration_seconds": DURATION, "bpm": 80,
              "sample_rate": RATE, "channels": 2, "peak": peak,
              "rms": float(np.sqrt(np.mean(track.astype(np.float64) ** 2))),
              "loop_boundary_delta": seam,
              "source": "Original deterministic synthesis; no third-party audio or voice samples",
              "generator": "tools/build_future_ethereal_audio.py"}
    report_path = ROOT / "art_source/future-ethereal-oct18/audio-qc.json"
    report_path.parent.mkdir(parents=True, exist_ok=True)
    report_path.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps(report, ensure_ascii=True))


if __name__ == "__main__":
    main()

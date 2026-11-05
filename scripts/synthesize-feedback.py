"""Reproduce SommoMemory's original, sample-free PCM feedback sprite."""
from pathlib import Path
import math, random, struct, wave

RATE = 22050
samples = [0.0] * int(RATE * 3.8)
rng = random.Random(20261105)

def tone(start, length, frequency, gain, end_frequency=None):
    for i in range(round(length * RATE)):
        t = i / RATE
        envelope = min(1, t / 0.003) * min(1, (length - t) / 0.018)
        phase = frequency * t
        if end_frequency is not None:
            phase += (end_frequency - frequency) * t * t / (2 * length)
        value = math.sin(2 * math.pi * phase)
        samples[round(start * RATE) + i] += gain * envelope * value

# A short card-like tick, a bright pair confirmation, a soft descending mistake,
# and a neutral turn chime. No recordings, musical quotations or external data.
tone(0.04, 0.055, 1050, 0.20, 660)
for i in range(round(0.035 * RATE)):
    samples[round(0.04 * RATE) + i] += rng.uniform(-1, 1) * 0.035 * (1 - i / (0.035 * RATE))
tone(1.10, 0.075, 659.25, 0.19)
tone(1.16, 0.075, 783.99, 0.17)
tone(1.22, 0.08, 1046.50, 0.15)
tone(2.35, 0.08, 293.66, 0.15, 246.94)
tone(2.43, 0.08, 220, 0.13, 196)
tone(3.55, 0.11, 523.25, 0.16)
tone(3.55, 0.085, 1046.5, 0.035)

path = Path(__file__).resolve().parents[1] / 'app/assets/audio/game_feedback.wav'
with wave.open(str(path), 'wb') as out:
    out.setnchannels(1)
    out.setsampwidth(2)
    out.setframerate(RATE)
    out.writeframes(b''.join(struct.pack('<h', round(max(-1, min(1, v)) * 32767)) for v in samples))
print(f'Wrote {path.name}: 3800 ms, mono PCM16, {RATE} Hz')

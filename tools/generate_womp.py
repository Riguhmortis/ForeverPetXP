"""Rebuild the original two-note sad-brass cue (Python stdlib + FFmpeg).

No sampled audio or melody recording is used. The generated OGG is distributed
under this project's MIT license along with this reproducible source.
"""
from array import array
from math import exp, pi, sin, tanh
from pathlib import Path
import subprocess
import tempfile
import wave


def main():
    rate = 44100
    samples = [0.0] * int(1.85 * rate)
    # Two voiced brass notes with a closing "wah" envelope and a final droop.
    for start, duration, pitch, fall in [(0.03, 0.57, 146.83, 0.13), (0.69, 0.93, 130.81, 0.33)]:
        phase = 0.0
        for i in range(int(duration * rate)):
            t = i / rate
            u = t / duration
            frequency = pitch * (1 - fall * u ** 1.7) * (1 + 0.003 * sin(2 * pi * 5.1 * t))
            phase += 2 * pi * frequency / rate
            cutoff = 390 + 1300 * sin(pi * u) ** 0.75
            envelope = min(1, t / 0.035) * min(1, (duration - t) / 0.12)
            envelope *= 0.82 + 0.18 * sin(pi * u)
            tone = 0.0
            for harmonic in range(1, 19):
                amplitude = harmonic ** -0.83 * exp(-(harmonic * frequency / cutoff) ** 2)
                tone += amplitude * sin(harmonic * phase)
            samples[int(start * rate) + i] += envelope * tanh(1.6 * tone)
    dry = samples[:]
    for delay, gain in [(0.031, 0.09), (0.067, 0.05), (0.113, 0.025)]:
        offset = int(delay * rate)
        for i in range(offset, len(samples)):
            samples[i] += gain * dry[i - offset]
    mean = sum(samples) / len(samples)
    samples = [value - mean for value in samples]
    peak = max(abs(value) for value in samples)
    pcm = array("h", (round(value / peak * 0.65 * 32767) for value in samples))
    import sys
    if sys.byteorder != "little":
        pcm.byteswap()
    destination = Path(__file__).resolve().parents[1] / "Sounds" / "womp-womp.ogg"
    destination.parent.mkdir(exist_ok=True)
    with tempfile.TemporaryDirectory() as temporary:
        wav = Path(temporary) / "womp.wav"
        with wave.open(str(wav), "wb") as output:
            output.setnchannels(1)
            output.setsampwidth(2)
            output.setframerate(rate)
            output.writeframes(pcm.tobytes())
        subprocess.run(["ffmpeg", "-hide_banner", "-loglevel", "error", "-y", "-i", str(wav),
                        "-c:a", "libvorbis", "-q:a", "4", "-metadata", "title=Forever Pet XP - Womp Womp",
                        str(destination)], check=True)
    print(destination)


if __name__ == "__main__":
    main()

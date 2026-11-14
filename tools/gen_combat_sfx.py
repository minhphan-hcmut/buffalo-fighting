"""Sinh bốn lớp âm thanh PCM 44,1 kHz mono 16-bit; chỉ cần numpy."""

from pathlib import Path
import wave

import numpy as np

RATE = 44100
SEED = 261114
OUTPUT = Path(__file__).resolve().parents[1] / "assets/audio"


def noise(rng, count, low, high):
    spectrum = np.fft.rfft(rng.standard_normal(count))
    hz = np.fft.rfftfreq(count, 1 / RATE)
    # Soft filter edges avoid ringing from a rectangular FFT mask.
    spectrum *= (1 - np.exp(-(hz / low) ** 4)) * np.exp(-(hz / high) ** 4)
    result = np.fft.irfft(spectrum, n=count)
    return result / max(np.std(result), 1e-12)


def thump(t, rng):
    phase = 2 * np.pi * (45 * t + 45 * 0.055 * (1 - np.exp(-t / 0.055)))
    # A 90 -> 45 Hz sine alone vanishes on laptop speakers. The second harmonic and soft
    # saturation add 90-270 Hz overtones, so small speakers still hear the "thịch".
    body = np.sin(phase) + 0.35 * np.sin(2 * phase)
    body = np.tanh(2.2 * body) / np.tanh(2.2)
    return (body * np.exp(-t / 0.065)
            + 0.16 * noise(rng, len(t), 160, 1700) * np.exp(-t / 0.012))


def generate():
    rng = np.random.default_rng(SEED)
    sounds = {}
    t = np.arange(round(0.20 * RATE)) / RATE
    carrier = np.sin(2 * np.pi * (1700 * t - 3000 * t * t))
    sounds["sfx_horn_whoosh"] = (noise(rng, len(t), 180, 2600) * 0.65
                                  + noise(rng, len(t), 80, 650) * carrier * 0.35
                                  ) * (1 - np.exp(-t / 0.013)) * (1 - t / 0.20) ** 2
    t = np.arange(round(0.25 * RATE)) / RATE
    sounds["sfx_impact_thump"] = thump(t, rng)
    # Parry: a dry wooden "cốc" like a village mõ (slit drum), not a metal bell. Wood
    # blocks have widely spaced partials (about 1 : 2.7 : 4.9) that die out fast.
    t = np.arange(round(0.35 * RATE)) / RATE
    sounds["sfx_parry_ring"] = sum(
        gain * np.sin(2 * np.pi * hz * t) * np.exp(-t / decay)
        for hz, gain, decay in [(760, 1, 0.07), (2050, 0.35, 0.03),
                                (3720, 0.12, 0.016)]
    ) + 0.5 * noise(rng, len(t), 900, 5000) * np.exp(-t / 0.004)
    t = np.arange(round(0.24 * RATE)) / RATE
    sounds["sfx_dash_burst"] = (noise(rng, len(t), 55, 750) * np.exp(-t / 0.043)
                                 + 0.45 * thump(t, rng))
    for name, samples in sounds.items():
        # Two millisecond fades suppress discontinuities without losing the attack.
        fade = round(0.002 * RATE)
        samples[:fade] *= np.linspace(0, 1, fade)
        samples[-fade:] *= np.linspace(1, 0, fade)
        samples -= np.mean(samples)
        samples *= 10 ** (-1.5 / 20) / np.max(np.abs(samples))
        pcm = np.rint(samples * 32767).astype("<i2")
        assert np.isfinite(samples).all() and np.max(np.abs(pcm.astype(float))) < 29205
        with wave.open(str(OUTPUT / (name + ".wav")), "wb") as output:
            output.setparams((1, 2, RATE, 0, "NONE", "not compressed"))
            output.writeframes(pcm.tobytes())
        print(name)


if __name__ == "__main__":
    generate()

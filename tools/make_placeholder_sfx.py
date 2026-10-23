"""Generates the placeholder combat sounds in godot/assets/sfx/.

They're synthesised from noise and sine waves, so they're original to this repo
(no license to track). Replace any of them with a real recording of the same
file name and the game picks it up; delete this script once they're all replaced.

    python3 tools/make_placeholder_sfx.py        (needs numpy)
"""
import os
import wave

import numpy as np

RATE = 44100
OUT = os.path.join(os.path.dirname(__file__), "..", "godot", "assets", "sfx")
rng = np.random.default_rng(7)   # fixed seed: same files every run


def seconds(length):
    return np.arange(int(RATE * length)) / RATE


def lowpass(signal, cutoff, poles=4):
    """Low-pass made of `poles` one-pole stages (6 dB per octave each).
    `cutoff` may be a number or an array (a sweep)."""
    cutoff = np.broadcast_to(np.asarray(cutoff, dtype=float), signal.shape)
    alpha = 1.0 - np.exp(-2.0 * np.pi * cutoff / RATE)
    out = signal
    for _ in range(poles):
        stage = np.empty_like(out)
        y = 0.0
        for i, x in enumerate(out):
            y += alpha[i] * (x - y)
            stage[i] = y
        out = stage
    return out


def highpass(signal, cutoff, poles=2):
    for _ in range(poles):
        signal = signal - lowpass(signal, cutoff, 1)
    return signal


def envelope(t, attack, decay):
    """Rises over `attack` seconds, then falls off exponentially."""
    rise = np.clip(t / max(attack, 1e-4), 0.0, 1.0)
    fall = np.exp(-np.maximum(t - attack, 0.0) / decay)
    return rise * fall


def save(name, signal, peak=0.8):
    signal = signal / (np.max(np.abs(signal)) + 1e-9) * peak
    fade = min(len(signal), int(RATE * 0.01))
    signal[-fade:] *= np.linspace(1.0, 0.0, fade)   # no click at the end
    data = (signal * 32767).astype(np.int16)
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(RATE)
        f.writeframes(data.tobytes())
    print("wrote", name)


def whoosh(length, low, high, peak_at):
    """Air past a blade: band of noise that sweeps up then down."""
    t = seconds(length)
    shape = np.sin(np.pi * np.clip(t / length, 0, 1)) ** 2
    sweep = low + (high - low) * np.exp(-((t - peak_at) / (length * 0.25)) ** 2)
    noise = rng.standard_normal(len(t))
    band = highpass(lowpass(noise, sweep), low * 0.5)
    return band * shape


def ring(t, partials, decay):
    """Metal: inharmonic partials, the high ones dying first."""
    out = np.zeros_like(t)
    for freq, amp in partials:
        out += amp * np.sin(2 * np.pi * freq * t) * np.exp(-t / (decay * 600.0 / freq))
    return out


def main():
    os.makedirs(OUT, exist_ok=True)

    save("swing_light", whoosh(0.22, 400.0, 2600.0, 0.09), 0.5)
    save("swing_heavy", whoosh(0.38, 250.0, 1600.0, 0.18), 0.6)
    save("dodge", whoosh(0.25, 200.0, 900.0, 0.08), 0.35)

    # Flesh hit: a low thump that drops in pitch, plus a short slap of noise.
    t = seconds(0.25)
    thump = np.sin(2 * np.pi * (230 * t - 200 * t ** 2)) * envelope(t, 0.002, 0.06)
    slap = lowpass(rng.standard_normal(len(t)), 2500.0) * envelope(t, 0.001, 0.025)
    save("hit_flesh", thump + 1.6 * slap, 0.9)

    # Heavier hit: lower, longer.
    t = seconds(0.4)
    thump = np.sin(2 * np.pi * (170 * t - 130 * t ** 2)) * envelope(t, 0.003, 0.11)
    slap = lowpass(rng.standard_normal(len(t)), 1800.0) * envelope(t, 0.001, 0.04)
    save("hit_heavy", thump + 1.8 * slap, 0.95)

    # Block: a dull clang (steel on steel/teeth), short.
    t = seconds(0.45)
    clang = ring(t, [(410, 1.0), (1030, 0.6), (1870, 0.35), (2950, 0.25)], 0.25)
    click = highpass(rng.standard_normal(len(t)), 3000.0) * envelope(t, 0.0005, 0.008)
    save("block", clang * envelope(t, 0.001, 0.12) + 0.5 * click, 0.8)

    # Parry: brighter and longer ring, so it's clearly different from a block.
    t = seconds(0.9)
    bright = ring(t, [(880, 1.0), (2230, 0.7), (3410, 0.5), (5120, 0.3)], 0.6)
    click = highpass(rng.standard_normal(len(t)), 4000.0) * envelope(t, 0.0005, 0.01)
    save("parry", bright * envelope(t, 0.001, 0.35) + 0.6 * click, 0.85)

    # Wolf growl (the bite telegraph): rough low noise with a fast tremble.
    t = seconds(0.5)
    rumble = lowpass(rng.standard_normal(len(t)), 700.0)
    tremble = 0.55 + 0.45 * np.sin(2 * np.pi * 28 * t)
    phase = (110 + 30 * t) * t
    voice = lowpass(2.0 * (phase % 1.0) - 1.0, 1200.0)   # buzzy sawtooth throat
    save("wolf_growl", (rumble * 4.0 + voice) * tremble * envelope(t, 0.08, 0.5), 0.7)

    # Wolf bite: a snap.
    t = seconds(0.12)
    snap = highpass(rng.standard_normal(len(t)), 1500.0) * envelope(t, 0.0005, 0.015)
    knock = np.sin(2 * np.pi * 300 * t) * envelope(t, 0.001, 0.03)
    save("wolf_bite", snap + knock, 0.8)

    # Bow release: the string's twang (a decaying pluck with a little buzz) and a whip of air.
    t = seconds(0.4)
    pluck = sum(np.sin(2 * np.pi * f * t) * a for f, a in [(196, 1.0), (392, 0.5), (590, 0.25)])
    twang = pluck * envelope(t, 0.001, 0.08)
    air = highpass(rng.standard_normal(len(t)), 1500.0) * envelope(t, 0.002, 0.03)
    save("bow_release", twang + 0.5 * air, 0.7)

    # Arrow hitting wood or earth: a short knock.
    t = seconds(0.15)
    knock = np.sin(2 * np.pi * (520 * t - 900 * t ** 2)) * envelope(t, 0.0005, 0.025)
    save("arrow_thud", knock + 0.4 * lowpass(rng.standard_normal(len(t)), 3000.0) * envelope(t, 0.0005, 0.01), 0.7)

    # Out of stamina / guard broken: a dull low thud.
    t = seconds(0.3)
    save("guard_break", np.sin(2 * np.pi * (120 * t - 60 * t ** 2)) * envelope(t, 0.002, 0.09)
         + 1.5 * lowpass(rng.standard_normal(len(t)), 900.0) * envelope(t, 0.001, 0.06), 0.9)


if __name__ == "__main__":
    main()

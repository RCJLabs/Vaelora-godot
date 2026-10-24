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


def save(name, signal, peak=0.8, loop=False, rate=RATE):
    signal = signal / (np.max(np.abs(signal)) + 1e-9) * peak
    if not loop:   # loops must not fade: their end runs straight into their start
        fade = min(len(signal), int(rate * 0.01))
        signal[-fade:] *= np.linspace(1.0, 0.0, fade)   # no click at the end
    data = (signal * 32767).astype(np.int16)
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(rate)
        f.writeframes(data.tobytes())
    print("wrote", name)


def band(signal, low, high, rate=RATE):
    """Band-pass by FFT, with soft edges. Filtering in the frequency domain treats the
    signal as repeating, so filtered noise loops without a seam."""
    spectrum = np.fft.rfft(signal)
    freqs = np.fft.rfftfreq(len(signal), 1.0 / rate)
    gain = 1.0 / (1.0 + (low / np.maximum(freqs, 1e-3)) ** 4) / (1.0 + (freqs / high) ** 4)
    return np.fft.irfft(spectrum * gain, len(signal))


def chirp(t0, length, f_start, f_end, rate):
    """One short pitch sweep (a bird call syllable), as (start sample, samples)."""
    t = np.arange(int(rate * length)) / rate
    freq = f_start + (f_end - f_start) * t / length
    phase = np.cumsum(freq) / rate
    shape = np.sin(np.pi * t / length) ** 2
    return int(t0 * rate), np.sin(2 * np.pi * phase + 0.6 * np.sin(2 * np.pi * 38 * t)) * shape


def add_wrapped(signal, start, piece):
    """Adds `piece` at `start`, wrapping past the end (so loops stay seamless)."""
    idx = (start + np.arange(len(piece))) % len(signal)
    np.add.at(signal, idx, piece)


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

    # Spell cast: a rising shimmer (a quick upward sweep of filtered noise plus a soft tone).
    t = seconds(0.35)
    shimmer = highpass(lowpass(rng.standard_normal(len(t)), 900 + 5000 * t / 0.35), 400.0) * envelope(t, 0.03, 0.12)
    tone = np.sin(2 * np.pi * (440 + 500 * t) * t) * envelope(t, 0.01, 0.1) * 0.6
    save("spell_cast", shimmer + tone, 0.6)

    # Spell impact: a soft boom with a crackle on top.
    t = seconds(0.6)
    boom = np.sin(2 * np.pi * (160 * t - 110 * t ** 2)) * envelope(t, 0.003, 0.14)
    crackle = highpass(rng.standard_normal(len(t)), 2000.0) * envelope(t, 0.002, 0.08) * (rng.random(len(t)) > 0.7)
    save("spell_impact", boom + 0.8 * lowpass(rng.standard_normal(len(t)), 1200.0) * envelope(t, 0.002, 0.1) + 0.5 * crackle, 0.85)

    # Ward hit: a glassy chime, softer than steel.
    t = seconds(0.6)
    save("ward_hit", ring(t, [(660, 1.0), (1320, 0.4), (1980, 0.25), (2970, 0.15)], 0.5) * envelope(t, 0.002, 0.2), 0.7)

    # Wisp charging: a rising, wavering hum (the telegraph to listen for).
    t = seconds(0.9)
    pitch = 220 + 380 * (t / 0.9) ** 1.5
    phase = np.cumsum(pitch) / RATE
    hum = (np.sin(2 * np.pi * phase) + 0.4 * np.sin(4 * np.pi * phase)) * (0.6 + 0.4 * np.sin(2 * np.pi * 7 * t))
    save("wisp_charge", hum * np.clip(t / 0.6, 0, 1) * np.exp(-np.maximum(t - 0.8, 0) / 0.05), 0.5)

    # Wisp blink: a quick airy "fwip", high to low.
    t = seconds(0.3)
    sweep = lowpass(rng.standard_normal(len(t)), 6000 * np.exp(-t / 0.08) + 300)
    save("wisp_blink", highpass(sweep, 500.0) * envelope(t, 0.005, 0.07), 0.6)

    # Out of stamina / guard broken: a dull low thud.
    t = seconds(0.3)
    save("guard_break", np.sin(2 * np.pi * (120 * t - 60 * t ** 2)) * envelope(t, 0.002, 0.09)
         + 1.5 * lowpass(rng.standard_normal(len(t)), 900.0) * envelope(t, 0.001, 0.06), 0.9)


    footsteps()
    ambience()
    dungeon()
    story()   # last: each section draws from the shared rng, so new ones go at the end


def footsteps():
    """Three takes per surface; the game picks one at random each step."""
    for take in range(1, 4):
        # Soft ground (grass, dirt): a low thud and a crunch of grit.
        t = seconds(0.2)
        thud = np.sin(2 * np.pi * (95 + 10 * take) * t) * envelope(t, 0.004, 0.03)
        grit = lowpass(rng.standard_normal(len(t)) * (rng.random(len(t)) > 0.55), 1400.0 + 300 * take, 2)
        save("footstep_soft_%d" % take, thud + 2.2 * grit * envelope(t, 0.006, 0.045), 0.45)

        # Stone: a hard heel click and a short scuff.
        t = seconds(0.16)
        click = highpass(rng.standard_normal(len(t)), 2200.0) * envelope(t, 0.0005, 0.007)
        scuff = highpass(lowpass(rng.standard_normal(len(t)), 3200.0), 700.0) * envelope(t, 0.008, 0.03)
        knock = np.sin(2 * np.pi * (180 + 15 * take) * t) * envelope(t, 0.001, 0.015)
        save("footstep_stone_%d" % take, click + 0.7 * scuff + 0.5 * knock, 0.5)

        # Wood: a hollow knock (a few resonances of the board) and a creak of noise.
        t = seconds(0.22)
        hollow = ring(t, [(150 + 12 * take, 1.0), (340 + 20 * take, 0.6), (720, 0.25)], 0.06)
        tap = lowpass(rng.standard_normal(len(t)), 2500.0) * envelope(t, 0.001, 0.012)
        save("footstep_wood_%d" % take, hollow * envelope(t, 0.002, 0.05) + 0.8 * tap, 0.5)


def ambience():
    """Seamless loops at 22 kHz (background beds don't need more)."""
    rate = 22050
    length = 12.0
    n = int(rate * length)
    t = np.arange(n) / rate

    def gusts(*periods):
        # Slow swells whose periods divide the loop length, so they line up at the seam.
        out = np.ones(n) * 0.6
        for cycles, depth in periods:
            out += depth * np.sin(2 * np.pi * cycles * t / length + rng.random() * 6.28)
        return np.clip(out, 0.1, None)

    # Day: wind through grass plus scattered bird calls.
    wind = band(rng.standard_normal(n), 120.0, 900.0, rate) * gusts((1, 0.3), (3, 0.15), (7, 0.08))
    day = wind / np.max(np.abs(wind))
    for call in range(9):
        start = rng.random() * length
        base = 2600 + rng.random() * 1600
        for syllable in range(2 + int(rng.random() * 4)):
            s0, piece = chirp(start + syllable * 0.13, 0.07 + rng.random() * 0.05, base, base * (1.25 + rng.random() * 0.3), rate)
            add_wrapped(day, s0, piece * (0.12 + rng.random() * 0.1))
    save("ambience_day", day, 0.5, loop=True, rate=rate)

    # Night: lighter wind and two crickets chirping at different rates.
    wind = band(rng.standard_normal(n), 90.0, 600.0, rate) * gusts((1, 0.25), (2, 0.15), (5, 0.1))
    night = wind / np.max(np.abs(wind)) * 0.7
    for freq, every, level in [(4400, 0.62, 0.07), (5100, 0.81, 0.045)]:
        pulse = np.sin(2 * np.pi * freq * t)
        for k in range(int(length / every)):
            for p in range(3):   # each chirp is 3 quick pulses
                s0 = int((k * every + p * 0.035 + rng.random() * 0.01) * rate)
                width = int(0.022 * rate)
                shape = np.sin(np.pi * np.arange(width) / width) ** 2
                add_wrapped(night, s0, pulse[s0 % n: s0 % n + width][:width] * shape[:len(pulse[s0 % n: s0 % n + width])] * level)
    save("ambience_night", night, 0.45, loop=True, rate=rate)

    # Cellar: a low room hum and the odd drip.
    room = band(rng.standard_normal(n), 40.0, 220.0, rate)
    room = room / np.max(np.abs(room)) * 0.5
    for drip in range(4):
        start = rng.random() * length
        dt = np.arange(int(rate * 0.25)) / rate
        plink = np.sin(2 * np.pi * (900 + 900 * dt / 0.25) * dt) * envelope(dt, 0.001, 0.03)
        for echo, gain in [(0.0, 0.5), (0.09, 0.2), (0.19, 0.08)]:   # a little echo off the walls
            add_wrapped(room, int((start + echo) * rate), plink * gain)
    save("ambience_cellar", room, 0.35, loop=True, rate=rate)

    # Campfire: a soft roar with crackles and the occasional pop.
    length = 6.0
    n = int(rate * length)
    roar = band(rng.standard_normal(n), 60.0, 400.0, rate)
    fire = roar / np.max(np.abs(roar)) * 0.35
    for crackle in range(int(length * 14)):
        size = rng.random() ** 2
        width = int(rate * (0.002 + 0.006 * size))
        burst = rng.standard_normal(width) * np.exp(-np.arange(width) / (width * 0.3))
        add_wrapped(fire, int(rng.random() * n), burst * (0.15 + 0.6 * size))
    fire = fire - band(fire, 1.0, 120.0, rate) * 0.5   # take the boom out of the crackles
    save("campfire_crackle", fire, 0.5, loop=True, rate=rate)


def dungeon():
    """Traps, levers, gates and the stone guardian."""
    # Pressure plate: a stony click.
    t = seconds(0.12)
    save("trap_click", highpass(rng.standard_normal(len(t)), 1800.0) * envelope(t, 0.0005, 0.01)
         + np.sin(2 * np.pi * 900 * t) * envelope(t, 0.0005, 0.02), 0.6)

    # Darts leaving the wall: a quick hiss.
    t = seconds(0.25)
    save("dart_fire", highpass(lowpass(rng.standard_normal(len(t)), 7000.0), 2500.0) * envelope(t, 0.003, 0.05), 0.5)

    # Lever: a wooden clack with a short metal scrape.
    t = seconds(0.35)
    clack = ring(t, [(260, 1.0), (590, 0.5)], 0.05) * envelope(t, 0.001, 0.04)
    scrape = highpass(lowpass(rng.standard_normal(len(t)), 4000.0), 1200.0) * envelope(t, 0.02, 0.08) * 0.4
    save("lever", clack + scrape, 0.6)

    # Gate: a long grinding rumble.
    t = seconds(1.6)
    grind = lowpass(rng.standard_normal(len(t)), 260.0) * (0.7 + 0.3 * np.sin(2 * np.pi * 11 * t))
    chain = highpass(rng.standard_normal(len(t)), 2500.0) * (rng.random(len(t)) > 0.97) * 0.6
    save("gate_rumble", (grind * 3.0 + chain) * np.clip(t / 0.15, 0, 1) * np.clip((1.6 - t) / 0.3, 0, 1), 0.7)

    # Guardian waking: a deep groan of stone.
    t = seconds(1.4)
    phase = np.cumsum(55 + 25 * np.sin(2 * np.pi * 0.7 * t)) / RATE
    groan = lowpass(2.0 * (phase % 1.0) - 1.0, 400.0)
    save("guardian_wake", (groan + lowpass(rng.standard_normal(len(t)), 300.0) * 2.0) * envelope(t, 0.3, 0.6), 0.8)

    # Guardian winding up: grinding stone rising.
    t = seconds(0.9)
    save("guardian_windup", lowpass(rng.standard_normal(len(t)), 300 + 900 * t / 0.9) * np.clip(t / 0.7, 0, 1) ** 2
         * np.exp(-np.maximum(t - 0.8, 0) / 0.05), 0.6)

    # Slam: a huge thump with rubble.
    t = seconds(1.0)
    boom = np.sin(2 * np.pi * (70 * t - 40 * t ** 2)) * envelope(t, 0.004, 0.25)
    rubble = lowpass(rng.standard_normal(len(t)) * (rng.random(len(t)) > 0.8), 1800.0) * envelope(t, 0.01, 0.3)
    save("guardian_slam", boom * 1.5 + rubble * 2.0, 0.95)

    # Crumbling: a long fall of rubble.
    t = seconds(2.2)
    clatter = lowpass(rng.standard_normal(len(t)) * (rng.random(len(t)) > 0.9), 2200.0) * envelope(t, 0.05, 0.8)
    thumps = sum(np.sin(2 * np.pi * 80 * np.maximum(t - d, 0)) * envelope(np.maximum(t - d, 0), 0.003, 0.08) * (t > d)
                 for d in [0.05, 0.4, 0.75, 1.1])
    save("guardian_crumble", clatter * 2.5 + thumps, 0.85)


def story():
    """The main questline's moments: wisps, the shrine, The First, the cards."""
    # Wisp drained into the line: a pitch falling away and thinning out.
    t = seconds(1.6)
    phase = np.cumsum(880 * np.exp(-t / 0.6) + 90) / RATE
    tone = np.sin(2 * np.pi * phase) + 0.3 * np.sin(6 * np.pi * phase)
    air = highpass(rng.standard_normal(len(t)), 3000.0) * 0.15
    save("wisp_drain", (tone + air) * envelope(t, 0.05, 0.6) * (0.8 + 0.2 * np.sin(2 * np.pi * 9 * t)), 0.45)

    # Caged wisp freed: a bright rising arpeggio, like ward_hit but going up.
    t = seconds(1.4)
    out = np.zeros_like(t)
    for i, f in enumerate([660, 880, 1100, 1320]):
        d = i * 0.12
        u = np.maximum(t - d, 0)
        out += ring(u, [(f, 1.0), (f * 2.01, 0.3)], 0.8) * envelope(u, 0.002, 0.4) * (t > d)
    save("wisp_freed", out, 0.6)

    # Taking its light: an inward swell (rising, then cut off) under a low throb.
    t = seconds(1.2)
    swell = lowpass(rng.standard_normal(len(t)), 300 + 2500 * (t / 1.2) ** 2) * (t / 1.2) ** 2
    throb = np.sin(2 * np.pi * 55 * t) * (t / 1.2) * (0.6 + 0.4 * np.sin(2 * np.pi * 5 * t))
    save("wisp_taken", (swell * 2.0 + throb) * np.exp(-np.maximum(t - 1.1, 0) / 0.02), 0.65)

    # Shrine: one soft bell (rekindled, a blessing, the end of a vigil).
    t = seconds(2.5)
    save("shrine_chime", ring(t, [(523, 1.0), (1047, 0.35), (1410, 0.2), (2093, 0.12)], 1.6) * envelope(t, 0.004, 0.9), 0.55)

    # Corruption rising: two close low tones beating against each other, swelling.
    t = seconds(1.8)
    beat = np.sin(2 * np.pi * 98 * t) + np.sin(2 * np.pi * 103.5 * t) + 0.5 * np.sin(2 * np.pi * 147 * t)
    hiss = lowpass(rng.standard_normal(len(t)), 600.0) * 0.6
    save("corruption_rise", (beat + hiss) * envelope(t, 0.6, 0.5), 0.6)

    # The First leaking a ring of light: a hollow boom with a glassy shimmer on top.
    t = seconds(1.3)
    boom = np.sin(2 * np.pi * (90 * t - 50 * t ** 2)) * envelope(t, 0.005, 0.3)
    glass = ring(t, [(1240, 0.5), (1873, 0.4), (2610, 0.3)], 0.9) * envelope(t, 0.02, 0.5)
    save("first_leak", boom * 1.4 + glass, 0.8)

    # The ritual starting: a low choir-like drone that rises in.
    t = seconds(3.0)
    drone = sum(np.sin(2 * np.pi * f * t + 0.3 * np.sin(2 * np.pi * 0.5 * t)) * a for f, a in [(73, 1.0), (110, 0.6), (146, 0.4), (220, 0.2)])
    breath = lowpass(rng.standard_normal(len(t)), 500.0) * 0.8
    save("ritual_drone", (drone + breath) * envelope(t, 1.2, 1.2), 0.6)

    # Story cards (the opening and the ending): a soft low chord.
    t = seconds(3.5)
    chord = sum(ring(t, [(f, 1.0), (f * 2.0, 0.25)], 2.5) for f in [110, 165, 220, 277])
    save("story_card", chord * envelope(t, 0.3, 1.4), 0.5)

    # A pack breaking: a couple of yelps, high and falling.
    t = seconds(0.9)
    out = np.zeros_like(t)
    for d, f in [(0.0, 900), (0.35, 780)]:
        u = np.maximum(t - d, 0)
        phase = np.cumsum((f * np.exp(-u / 0.12) + 350) * (t > d)) / RATE
        out += lowpass(2.0 * (phase % 1.0) - 1.0, 2500.0) * envelope(u, 0.005, 0.08) * (t > d)
    save("wolf_yelp", out, 0.6)


if __name__ == "__main__":
    main()

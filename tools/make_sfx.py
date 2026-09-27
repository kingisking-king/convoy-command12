#!/usr/bin/env python3
"""Generate small original sound effects for Convoy Command."""

import math
import os
import random
import struct
import wave

ROOT = os.path.join(os.path.dirname(__file__), "..", "assets", "sfx")
RATE = 22050


def write_wav(name, samples, rate=RATE):
    os.makedirs(ROOT, exist_ok=True)
    path = os.path.join(ROOT, name + ".wav")
    peak = max(1e-6, max(abs(s) for s in samples))
    gain = 0.42 / peak
    with wave.open(path, "w") as wf:
        wf.setnchannels(1)
        wf.setsampwidth(2)
        wf.setframerate(rate)
        frames = bytearray()
        for s in samples:
            v = max(-1.0, min(1.0, s * gain))
            frames += struct.pack("<h", int(v * 32767))
        wf.writeframes(frames)
    print("wrote", path, len(samples))


def env(i, n, attack, release):
    a = min(1.0, i / max(1, attack))
    r = min(1.0, (n - 1 - i) / max(1, release))
    return a * r


def noise(n, rng):
    return [rng.uniform(-1, 1) for _ in range(n)]


def seamless(samples, fade=500):
    fade = min(fade, len(samples) // 4)
    out = samples[:-fade]
    for i in range(fade):
        w = i / fade
        out[i] = out[i] * w + samples[-fade + i] * (1 - w)
    return out


def tone(freq, dur, vol=1.0, wave_kind="sine"):
    n = int(RATE * dur)
    out = []
    for i in range(n):
        t = i / RATE
        if wave_kind == "sine":
            s = math.sin(2 * math.pi * freq * t)
        else:
            s = 2 * abs(2 * ((t * freq) % 1) - 1) - 1
        out.append(s * vol * env(i, n, int(RATE * 0.01), int(RATE * 0.05)))
    return out


def mix(a, b, gain_b=1.0):
    n = max(len(a), len(b))
    out = [0.0] * n
    for i in range(n):
        if i < len(a):
            out[i] += a[i]
        if i < len(b):
            out[i] += b[i] * gain_b
    return out


def main():
    rng = random.Random(7)
    write_wav("ui_click", tone(880, 0.045, 0.8))
    write_wav("ui_place", mix(tone(140, 0.09, 0.9, "tri"), tone(220, 0.07, 0.4)))

    n = int(RATE * 0.09)
    burst = noise(n, rng)
    light = [burst[i] * math.exp(-i / (RATE * 0.018)) for i in range(n)]
    write_wav("gun_light", light)

    n = int(RATE * 0.06)
    tick = noise(n, rng)
    aa = [tick[i] * math.exp(-i / (RATE * 0.01)) * (0.6 + 0.4 * math.sin(2 * math.pi * 1800 * i / RATE)) for i in range(n)]
    write_wav("gun_aa", aa)

    n = int(RATE * 0.22)
    heavy_n = noise(n, rng)
    heavy = []
    for i in range(n):
        t = i / RATE
        heavy.append(heavy_n[i] * math.exp(-i / (RATE * 0.05)) * 0.8 + math.sin(2 * math.pi * 70 * t) * math.exp(-i / (RATE * 0.06)))
    write_wav("gun_heavy", heavy)

    n = int(RATE * 0.55)
    boom_n = noise(n, rng)
    boom = []
    for i in range(n):
        t = i / RATE
        boom.append(boom_n[i] * math.exp(-i / (RATE * 0.12)) + math.sin(2 * math.pi * (50 - 30 * t) * t) * math.exp(-i / (RATE * 0.18)))
    write_wav("explosion", boom)

    n = int(RATE * 0.12)
    death_n = noise(n, rng)
    write_wav("death", [death_n[i] * math.exp(-i / (RATE * 0.03)) for i in range(n)])

    amb = mix(tone(740, 0.12), tone(980, 0.12))
    write_wav("ambush", amb + [0.0] * int(RATE * 0.04) + mix(tone(740, 0.14), tone(980, 0.14)))

    win = []
    for f, d in ((523, 0.12), (659, 0.12), (784, 0.12), (1046, 0.28)):
        win += tone(f, d, 0.8)
    write_wav("win", win)
    lose = []
    for f, d in ((392, 0.16), (311, 0.16), (247, 0.36)):
        lose += tone(f, d, 0.8)
    write_wav("lose", lose)

    repair = tone(660, 0.07) + tone(880, 0.07) + tone(1175, 0.12)
    write_wav("repair", repair)

    n = int(RATE * 0.45)
    hiss = noise(n, rng)
    write_wav("smoke", [hiss[i] * math.sin(math.pi * i / n) * 0.7 for i in range(n)])

    n = int(RATE * 0.7)
    whistle = []
    for i in range(n):
        t = i / RATE
        f = 980 - 620 * (t / 0.7)
        whistle.append(math.sin(2 * math.pi * f * t) * env(i, n, int(RATE * 0.02), int(RATE * 0.08)))
    write_wav("whistle", whistle)

    n = int(RATE * 1.2)
    heli = []
    raw = noise(n, rng)
    for i in range(n):
        t = i / RATE
        chop = 0.45 + 0.55 * abs(math.sin(2 * math.pi * 16 * t))
        heli.append(raw[i] * chop * 0.55 + math.sin(2 * math.pi * 90 * t) * 0.15)
    write_wav("heli", seamless(heli, 800))

    n = int(RATE * 1.2)
    eng = []
    raw = noise(n, rng)
    acc = 0.0
    for i in range(n):
        acc = acc * 0.92 + raw[i] * 0.08
        t = i / RATE
        eng.append(acc * 1.4 + math.sin(2 * math.pi * 48 * t) * 0.25 + math.sin(2 * math.pi * 96 * t) * 0.08)
    write_wav("engine", seamless(eng, 800))

    n = int(RATE * 12)
    menu = []
    for i in range(n):
        t = i / RATE
        lfo = 0.65 + 0.35 * math.sin(2 * math.pi * t / 6.0)
        s = 0.22 * math.sin(2 * math.pi * 110 * t)
        s += 0.16 * math.sin(2 * math.pi * 164.81 * t)
        s += 0.07 * math.sin(2 * math.pi * 220 * t)
        s += 0.05 * math.sin(2 * math.pi * 329.63 * t) * (0.5 + 0.5 * math.sin(2 * math.pi * 0.2 * t))
        menu.append(s * lfo)
    write_wav("music_menu", seamless(menu, 1200))

    n = int(RATE * 8)
    drive = []
    raw = noise(n, rng)
    for i in range(n):
        t = i / RATE
        pulse = 1.0 if (t % 0.5) < 0.06 else 0.35
        s = 0.2 * math.sin(2 * math.pi * 82.41 * t)
        s += 0.12 * math.sin(2 * math.pi * 123.47 * t)
        s += 0.06 * math.sin(2 * math.pi * 196 * t) * (0.5 + 0.5 * math.sin(2 * math.pi * 0.5 * t))
        s += raw[i] * 0.04 * pulse
        s *= 0.55 + 0.45 * math.sin(2 * math.pi * t / 4.0) ** 2
        drive.append(s)
    write_wav("music_drive", seamless(drive, 1000))


if __name__ == "__main__":
    main()

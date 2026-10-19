"""Genera la música y los efectos de sonido del combate (WAV, 22050 Hz, mono).

Uso:  python tools/generar_audio.py      (requiere numpy)
Los archivos se guardan en assets/sounds/ con el prefijo "bt_".
"""
import os
import wave

import numpy as np

SR = 22050
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "sounds")
rng = np.random.default_rng(7)


def t_arr(dur):
    return np.arange(int(SR * dur)) / SR


def env(n, a=0.005, r=0.05, curve=1.0):
    """Envolvente: ataque corto y caída exponencial."""
    e = np.ones(n)
    na = max(1, int(SR * a))
    e[:na] = np.linspace(0, 1, na)
    nr = max(1, min(n, int(SR * r)))
    e[-nr:] *= np.linspace(1, 0, nr) ** curve
    return e


def square(freq, dur, duty=0.5):
    t = t_arr(dur)
    ph = (t * freq) % 1.0
    return np.where(ph < duty, 1.0, -1.0)


def tri(freq, dur):
    t = t_arr(dur)
    return 2 * np.abs(2 * ((t * freq) % 1.0) - 1) - 1


def sine(freq, dur):
    return np.sin(2 * np.pi * freq * t_arr(dur))


def sweep(f0, f1, dur, wave_fn="sine"):
    t = t_arr(dur)
    f = np.linspace(f0, f1, len(t))
    ph = np.cumsum(f) / SR
    if wave_fn == "square":
        return np.where((ph % 1.0) < 0.5, 1.0, -1.0)
    return np.sin(2 * np.pi * ph)


def noise(dur):
    return rng.uniform(-1, 1, int(SR * dur))


def lowpass(x, k):
    if k <= 1:
        return x
    return np.convolve(x, np.ones(k) / k, mode="same")


def midi(n):
    return 440.0 * 2 ** ((n - 69) / 12)


def norm(x, peak=0.85):
    m = np.max(np.abs(x)) or 1.0
    return x / m * peak


def save(name, x):
    x = np.clip(x, -1, 1)
    data = (x * 32767).astype(np.int16)
    path = os.path.join(OUT, name)
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())
    print(f"{name}: {len(x) / SR:.2f}s, {os.path.getsize(path) // 1024} KB")


def mix_at(buf, x, start):
    i = int(start * SR)
    j = min(len(buf), i + len(x))
    if i < len(buf):
        buf[i:j] += x[: j - i]


# ---------------------------------------------------------------- efectos
def fx_move():  # silbido del ataque
    n = noise(0.35)
    x = lowpass(n, 6) * np.linspace(0.2, 1, len(n)) * env(len(n), 0.02, 0.15)
    return norm(x, 0.7)


def fx_cast():  # lanzar un movimiento de estado
    parts = [sine(midi(m), 0.09) * env(int(SR * 0.09), 0.005, 0.04) for m in (72, 76, 79, 84)]
    return norm(np.concatenate(parts), 0.6)


def fx_hit(power=1.0, crit=False):
    d = 0.28 if power <= 1 else 0.4
    n = noise(d)
    thud = sweep(160 * power, 50, d)
    x = (lowpass(n, 3) * 0.7 + thud) * env(int(SR * d), 0.002, d * 0.9, 2)
    if power > 1:
        x += square(880, d, 0.25) * env(int(SR * d), 0.002, d * 0.5, 2) * 0.25
    if crit:
        ping = sine(1760, 0.3) * env(int(SR * 0.3), 0.002, 0.28, 2)
        x = np.concatenate([x, np.zeros(0)])
        x[: len(ping)] += ping[: len(x)] * 0.4
    return norm(x, 0.9 if power > 1 else 0.7)


def fx_hit_weak():
    d = 0.2
    x = (lowpass(noise(d), 8) * 0.6 + sweep(110, 60, d) * 0.6) * env(int(SR * d), 0.003, 0.18, 2)
    return norm(x, 0.5)


def fx_miss():
    return norm(sweep(700, 250, 0.3) * env(int(SR * 0.3), 0.01, 0.2), 0.45)


def fx_paralysis():  # chispazos eléctricos
    d = 0.6
    n = int(SR * d)
    f = np.repeat(rng.uniform(300, 2500, n // 400 + 1), 400)[:n]
    ph = np.cumsum(f) / SR
    x = np.where((ph % 1.0) < 0.5, 1.0, -1.0) * (rng.uniform(0, 1, n) > 0.25)
    x = x * env(n, 0.005, 0.25) * 0.6 + noise(d) * 0.15 * env(n, 0.005, 0.3)
    return norm(x, 0.7)


def fx_burn():  # fuego crepitando
    d = 0.7
    n = int(SR * d)
    base = lowpass(noise(d), 5) * np.linspace(1, 0.3, n)
    pops = np.zeros(n)
    for p in rng.integers(0, n - 800, 14):
        pops[p : p + 600] += noise(600 / SR) * np.linspace(1, 0, 600) * rng.uniform(0.4, 1)
    x = (base * 0.6 + pops) * env(n, 0.02, 0.3)
    return norm(x, 0.7)


def fx_poison():  # burbujas
    parts = []
    for _ in range(6):
        f0 = rng.uniform(250, 500)
        parts.append(sweep(f0, f0 * 2.2, 0.09) * env(int(SR * 0.09), 0.005, 0.05))
        parts.append(np.zeros(int(SR * 0.03)))
    return norm(np.concatenate(parts), 0.6)


def fx_sleep():  # nana descendente
    notes = (76, 74, 71, 67)
    parts = [(sine(midi(m), 0.22) + 0.3 * sine(midi(m) * 2, 0.22)) * env(int(SR * 0.22), 0.03, 0.15) for m in notes]
    return norm(np.concatenate(parts), 0.55)


def fx_freeze():  # cristales de hielo
    out = np.zeros(int(SR * 0.8))
    for k, m in enumerate((96, 91, 100, 88, 103)):
        f = midi(m)
        t = t_arr(0.35)
        x = np.sin(2 * np.pi * f * t + 3 * np.sin(2 * np.pi * f * 1.5 * t)) * env(len(t), 0.002, 0.33, 2)
        mix_at(out, x * 0.5, k * 0.09)
    return norm(out, 0.6)


def fx_confusion():  # sonido ondulante
    d = 0.8
    t = t_arr(d)
    f = 440 + 120 * np.sin(2 * np.pi * 7 * t)
    x = np.sin(2 * np.pi * np.cumsum(f) / SR) * env(len(t), 0.02, 0.3)
    return norm(x, 0.55)


def fx_faint():
    d = 0.9
    x = sweep(520, 70, d, "square") * 0.5 * env(int(SR * d), 0.01, 0.4)
    return norm(x, 0.55)


def fx_send():  # sale el Pokémon de la Poké Ball
    d = 0.35
    x = sweep(300, 1200, d) * env(int(SR * d), 0.005, 0.15)
    pop = lowpass(noise(0.05), 4) * np.linspace(1, 0, int(SR * 0.05))
    x[: len(pop)] += pop * 0.8
    return norm(x, 0.6)


def fx_heal():
    parts = [sine(midi(m), 0.12) * env(int(SR * 0.12), 0.005, 0.08) for m in (72, 76, 79)]
    return norm(np.concatenate(parts), 0.5)


def jingle(notes, step=0.16, wave_fn=square):
    total = sum(d for _, d in notes) * step + 0.4
    buf = np.zeros(int(SR * total))
    pos = 0.0
    for m, d in notes:
        dur = d * step
        if m is not None:
            x = wave_fn(midi(m), dur) * env(int(SR * dur), 0.005, min(0.1, dur * 0.8), 1)
            mix_at(buf, x * 0.5, pos)
            mix_at(buf, tri(midi(m - 12), dur) * env(int(SR * dur), 0.005, 0.05) * 0.4, pos)
        pos += dur
    return norm(buf, 0.7)


def fx_win():
    n = [(72, 1), (72, 1), (72, 1), (72, 3), (68, 3), (70, 3), (72, 1), (None, 1), (70, 1), (72, 6)]
    return jingle(n)


def fx_lose():
    n = [(69, 3), (68, 3), (67, 3), (64, 8)]
    return jingle(n, 0.2, lambda f, d: square(f, d, 0.25))


# ---------------------------------------------------------------- música
def music():
    bpm = 150
    step = 60 / bpm / 4  # semicorchea
    chords = {
        "Am": (45, (0, 3, 7)),
        "F": (41, (0, 4, 7)),
        "C": (48, (0, 4, 7)),
        "G": (43, (0, 4, 7)),
        "E": (40, (0, 4, 7)),
    }
    prog_a = ["Am", "F", "C", "G", "Am", "F", "G", "G"]
    prog_b = ["F", "G", "Am", "Am", "F", "G", "E", "E"]
    templates = [
        [2, 3, 2, 1, 2, 1, 0, 1],
        [0, 1, 2, 3, 2, 1, 2, 0],
        [3, 2, 1, 2, 3, 3, 2, 1],
        [2, 2, 3, 2, 1, 1, 0, 0],
    ]
    bars = prog_a + prog_b
    total = len(bars) * 16 * step
    buf = np.zeros(int(SR * total))

    for b, name in enumerate(bars):
        root, iv = chords[name]
        tones = [root + 24 + i for i in iv] + [root + 36]
        t0 = b * 16 * step
        # bajo (corcheas)
        pat = [0, 0, 7, 0, 0, 0, 7, 12]
        for k, off in enumerate(pat):
            d = 2 * step
            x = tri(midi(root + off), d) * env(int(SR * d), 0.004, 0.06)
            mix_at(buf, x * 0.55, t0 + k * d)
        # arpegio rápido
        for k in range(16):
            n = root + 24 + iv[[0, 1, 2, 1][k % 4]]
            x = square(midi(n), step, 0.125) * env(int(SR * step), 0.003, 0.04)
            mix_at(buf, x * 0.07, t0 + k * step)
        # melodía
        tpl = templates[(b * 3 + (b // 4)) % 4]
        shift = 12 if b >= 8 else 0
        for k, idx in enumerate(tpl):
            if b % 4 == 3 and k == 7:
                continue
            d = 2 * step
            x = square(midi(tones[idx] + shift - (12 if b < 8 else 0)), d, 0.25) * env(int(SR * d), 0.004, 0.07)
            mix_at(buf, x * 0.20, t0 + k * d)
        # batería
        for beat in range(4):
            tb = t0 + beat * 4 * step
            if beat in (0, 2):
                kick = sweep(150, 45, 0.14) * env(int(SR * 0.14), 0.001, 0.13, 2)
                mix_at(buf, kick * 0.8, tb)
            else:
                sn = lowpass(noise(0.12), 2) * env(int(SR * 0.12), 0.001, 0.11, 2)
                mix_at(buf, sn * 0.45, tb)
        for k in range(8):
            hat = (noise(0.03) - lowpass(noise(0.03), 4)) * env(int(SR * 0.03), 0.001, 0.025)
            mix_at(buf, hat * 0.22, t0 + k * 2 * step)

    return norm(buf, 0.8)


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    save("bt_move.wav", fx_move())
    save("bt_cast.wav", fx_cast())
    save("bt_hit.wav", fx_hit())
    save("bt_hit_super.wav", fx_hit(1.6))
    save("bt_hit_weak.wav", fx_hit_weak())
    save("bt_crit.wav", fx_hit(1.6, True))
    save("bt_miss.wav", fx_miss())
    save("bt_paralysis.wav", fx_paralysis())
    save("bt_burn.wav", fx_burn())
    save("bt_poison.wav", fx_poison())
    save("bt_sleep.wav", fx_sleep())
    save("bt_freeze.wav", fx_freeze())
    save("bt_confusion.wav", fx_confusion())
    save("bt_faint.wav", fx_faint())
    save("bt_send.wav", fx_send())
    save("bt_heal.wav", fx_heal())
    save("bt_win.wav", fx_win())
    save("bt_lose.wav", fx_lose())
    save("bt_music.wav", music())

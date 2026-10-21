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


def fx_mega():  # megaevolución: barrido ascendente + destellos
    d = 1.1
    n = int(SR * d)
    x = np.zeros(n)
    for k, (f0, f1) in enumerate(((200, 1800), (300, 2400), (400, 3200))):
        x += sweep(f0, f1, d) * (0.35 - 0.08 * k)
    x *= np.linspace(0.2, 1, n) * env(n, 0.02, 0.35)
    for k, m in enumerate((84, 88, 91, 96)):
        t = t_arr(0.25)
        mix_at(x, np.sin(2 * np.pi * midi(m) * t) * env(len(t), 0.002, 0.22, 2) * 0.35, 0.55 + k * 0.1)
    return norm(x, 0.8)


def fx_attract():  # atracción: dos notas dulces con vibrato
    parts = []
    for m in (79, 83, 88):
        t = t_arr(0.2)
        f = midi(m) * (1 + 0.012 * np.sin(2 * np.pi * 9 * t))
        parts.append(np.sin(2 * np.pi * np.cumsum(f) / SR) * env(len(t), 0.01, 0.15))
    return norm(np.concatenate(parts), 0.55)


def fx_curse():  # maldición: rumor grave y disonante
    d = 0.95
    n = int(SR * d)
    x = square(midi(40), d, 0.5) * 0.4 + square(midi(40) * 1.06, d, 0.5) * 0.3
    x += lowpass(noise(d), 40) * 1.5
    x *= env(n, 0.05, 0.5) * (0.7 + 0.3 * np.sin(2 * np.pi * 5 * t_arr(d)))
    return norm(x, 0.7)


def fx_drain():  # drenadoras: sorbos
    parts = []
    for i in range(4):
        f0 = 500 - i * 60
        parts.append(sweep(f0, f0 * 0.5, 0.11) * env(int(SR * 0.11), 0.005, 0.07))
        parts.append(sweep(f0 * 0.5, f0 * 0.9, 0.08) * env(int(SR * 0.08), 0.005, 0.05))
    return norm(np.concatenate(parts), 0.55)


def fx_trap():  # restricción: apretar
    d = 0.55
    n = int(SR * d)
    x = lowpass(noise(d), 4) * np.linspace(1, 0.2, n) * 0.6
    x += sweep(900, 150, d, "square") * 0.25
    return norm(x * env(n, 0.01, 0.2), 0.65)


def fx_statup():
    parts = [square(midi(m), 0.08, 0.25) * env(int(SR * 0.08), 0.004, 0.05) for m in (67, 71, 74, 79)]
    return norm(np.concatenate(parts), 0.5)


def fx_statdown():
    parts = [square(midi(m), 0.08, 0.5) * env(int(SR * 0.08), 0.004, 0.05) for m in (79, 74, 70, 65)]
    return norm(np.concatenate(parts), 0.5)


# ---------------------------------------------------------------- música
# Tema de combate ORIGINAL (no es una copia de ninguna melodía existente):
# rock/chiptune rápido en mi menor, 168 BPM, con intro, estrofa, estribillo
# armonizado, puente y estribillo final. 32 compases (~46 s) en bucle.
def music():
    bpm = 168
    step = 60 / bpm / 4  # semicorchea
    SPB = 16  # pasos por compás
    chords = {  # raíz grave (MIDI) e intervalos
        "Em": (40, (0, 3, 7)),
        "C": (36, (0, 4, 7)),
        "D": (38, (0, 4, 7)),
        "B": (35, (0, 4, 7, 10)),
        "Am": (33, (0, 3, 7)),
    }
    sections = [
        ("intro", ["Em", "Em", "Em", "B"]),
        ("verse", ["Em", "Em", "C", "D", "Em", "Em", "C", "B"]),
        ("chorus", ["C", "D", "Em", "Em", "C", "D", "B", "B"]),
        ("bridge", ["Am", "Am", "B", "B"]),
        ("final", ["C", "D", "Em", "Em", "C", "D", "B", "Em"]),
    ]
    # Ritmos de la melodía: (paso, desplazamiento por tonos del acorde, duración)
    # El índice indica la nota del acorde (0,1,2 y 3 = raíz una octava arriba).
    motifs = [
        [(0, 3, 2), (2, 3, 1), (3, 2, 1), (4, 3, 2), (6, 4, 2), (8, 3, 2), (10, 2, 2), (12, 1, 2), (14, 2, 2)],
        [(0, 2, 2), (2, 3, 2), (4, 4, 4), (8, 3, 2), (10, 2, 2), (12, 1, 4)],
        [(0, 4, 2), (2, 4, 1), (3, 3, 1), (4, 4, 2), (6, 5, 2), (8, 4, 4), (12, 3, 2), (14, 2, 2)],
        [(0, 1, 1), (1, 2, 1), (2, 3, 2), (4, 2, 1), (5, 3, 1), (6, 4, 2), (8, 5, 3), (11, 4, 1), (12, 3, 4)],
    ]
    total_bars = sum(len(p) for _, p in sections)
    buf = np.zeros(int(SR * total_bars * SPB * step))

    def tones_for(name, octave_shift):
        root, iv = chords[name]
        base = root + 36 + octave_shift  # registro de la melodía
        t = [base + i for i in iv]
        return t + [t[0] + 12, t[1] + 12, t[2] + 12]

    def below(note, name):
        root, iv = chords[name]
        cands = [root + 12 * o + i for o in range(3, 6) for i in iv]
        c = [x for x in cands if x <= note - 3]
        return max(c) if c else note - 5

    def vib(freq, dur, depth=0.006, rate=6.0, duty=0.25):
        t = t_arr(dur)
        f = freq * (1 + depth * np.sin(2 * np.pi * rate * t) * np.minimum(1, t / 0.12))
        ph = np.cumsum(f) / SR
        return np.where((ph % 1.0) < duty, 1.0, -1.0)

    def drum_kick(t0, vol=0.8):
        k = sweep(160, 42, 0.15) * env(int(SR * 0.15), 0.001, 0.14, 2)
        mix_at(buf, k * vol, t0)

    def drum_snare(t0, vol=0.45):
        sn = (lowpass(noise(0.14), 2) * 0.8 + sweep(220, 160, 0.14) * 0.3) * env(int(SR * 0.14), 0.001, 0.13, 2)
        mix_at(buf, sn * vol, t0)

    def drum_hat(t0, vol=0.2, open_=False):
        d = 0.14 if open_ else 0.03
        h = (noise(d) - lowpass(noise(d), 4)) * env(int(SR * d), 0.001, d * 0.9)
        mix_at(buf, h * vol, t0)

    def drum_tom(t0, f0, vol=0.6):
        x = sweep(f0, f0 * 0.55, 0.16) * env(int(SR * 0.16), 0.002, 0.15, 2)
        mix_at(buf, x * vol, t0)

    def crash(t0, vol=0.35):
        d = 0.9
        c = (noise(d) - lowpass(noise(d), 6)) * env(int(SR * d), 0.002, 0.85, 2)
        mix_at(buf, c * vol, t0)

    bar_idx = 0
    for sec, prog in sections:
        for bi, name in enumerate(prog):
            t0 = bar_idx * SPB * step
            root, iv = chords[name]
            loud = sec in ("chorus", "final")

            # --- bajo galopante (pulso estrecho)
            pat = [0, 0, 12, 0, 0, 0, 12, 0, 0, 0, 12, 0, 7, 0, 12, 10 if name == "B" else 7]
            if sec == "intro":
                pat = [0, None, 0, None, 12, None, 0, None, 0, None, 0, None, 7, None, 12, None]
            if sec == "bridge":
                pat = [0, None, None, 0, None, None, 0, None, 7, None, None, 7, None, None, 12, None]
            for k, off in enumerate(pat):
                if off is None:
                    continue
                x = square(midi(root + 12 + off), step * 0.9, 0.35) * env(int(SR * step * 0.9), 0.002, 0.03)
                mix_at(buf, x * 0.40, t0 + k * step)

            # --- arpegio
            arp_vol = 0.10 if sec == "bridge" else (0.06 if sec != "intro" else 0.0)
            if arp_vol:
                for k in range(16):
                    n = root + 36 + iv[[0, 1, 2, 1, 0, 2, 1, 2][k % 8] % len(iv)]
                    x = square(midi(n), step, 0.125) * env(int(SR * step), 0.002, 0.04)
                    mix_at(buf, x * arp_vol, t0 + k * step)

            # --- melodía y armonía
            if sec != "intro":
                tones = tones_for(name, 12 if sec == "final" else 0)
                motif = motifs[(bar_idx * 2 + bi) % 4] if sec != "bridge" else [(0, 4, 4), (4, 3, 4), (8, 5, 4), (12, 4, 4)]
                for step_i, idx, ln in motif:
                    if sec == "verse" and bi % 4 == 3 and step_i >= 12:
                        continue
                    note = tones[idx % len(tones)]
                    d = ln * step
                    x = vib(midi(note), d, duty=0.25) * env(int(SR * d), 0.004, min(0.08, d * 0.5))
                    mix_at(buf, x * (0.24 if loud else 0.20), t0 + step_i * step)
                    if loud or sec == "bridge":
                        h = tri(midi(below(note, name)), d) * env(int(SR * d), 0.004, min(0.08, d * 0.5))
                        mix_at(buf, h * 0.28, t0 + step_i * step)

            # --- batería
            kicks = {"intro": (0, 8), "verse": (0, 6, 8, 11), "chorus": (0, 3, 6, 8, 11, 14),
                     "bridge": (0, 8), "final": (0, 3, 6, 8, 11, 14)}[sec]
            snares = (4, 12) if sec != "bridge" else (8,)
            for k in kicks:
                drum_kick(t0 + k * step)
            for k in snares:
                drum_snare(t0 + k * step)
            for k in range(0, 16, 2):
                drum_hat(t0 + k * step, 0.22 if loud else 0.15, open_=(k == 14 and sec != "intro"))
            if bi == 0:
                crash(t0)
            # relleno en el último compás de cada grupo de 4
            if bi % 4 == 3:
                for k in range(8, 16):
                    drum_snare(t0 + k * step, 0.25 + 0.04 * (k - 8))
                for j, f in enumerate((220, 180, 150, 120)):
                    drum_tom(t0 + (12 + j) * step, f, 0.5)
            bar_idx += 1

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
    save("bt_mega.wav", fx_mega())
    save("bt_attract.wav", fx_attract())
    save("bt_curse.wav", fx_curse())
    save("bt_drain.wav", fx_drain())
    save("bt_trap.wav", fx_trap())
    save("bt_statup.wav", fx_statup())
    save("bt_statdown.wav", fx_statdown())
    save("bt_music.wav", music())

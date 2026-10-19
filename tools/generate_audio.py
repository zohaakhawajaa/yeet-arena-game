"""Generate every YEET ARENA sound effect and music loop as original WAV data.

Pure standard library (wave/math/random/struct) - no external audio assets.
All sounds are synthesized from oscillators and noise so the project ships
100% original audio.

Usage:
    python tools/generate_audio.py            # writes into game/assets/audio
    python tools/generate_audio.py --out DIR

Output: 22050 Hz, 16-bit mono WAV.
"""

from __future__ import annotations

import argparse
import math
import os
import random
import struct
import wave

RATE = 22050
TAU = math.pi * 2.0


# --------------------------------------------------------------------- buffer

def buf(dur: float) -> list[float]:
    return [0.0] * max(1, int(RATE * dur))


def place(dst: list[float], src: list[float], at: float = 0.0, gain: float = 1.0) -> None:
    start = int(RATE * at)
    if start < 0:
        start = 0
    need = start + len(src)
    if need > len(dst):
        dst.extend([0.0] * (need - len(dst)))
    for i, s in enumerate(src):
        dst[start + i] += s * gain


def normalize(data: list[float], peak: float = 0.88) -> list[float]:
    m = 0.0
    for s in data:
        a = abs(s)
        if a > m:
            m = a
    if m < 1e-9:
        return data
    k = peak / m
    return [s * k for s in data]


def softclip(data: list[float], drive: float = 1.4) -> list[float]:
    out = []
    for s in data:
        x = s * drive
        out.append(math.tanh(x) if abs(x) > 0.001 else x)
    return out


def fade(data: list[float], ms: float = 6.0) -> list[float]:
    n = int(RATE * ms / 1000.0)
    n = min(n, len(data) // 2) if len(data) > 1 else 0
    for i in range(n):
        k = i / n
        data[i] *= k
        data[len(data) - 1 - i] *= k
    return data


def lowpass(data: list[float], cutoff_hz: float) -> list[float]:
    dt = 1.0 / RATE
    rc = 1.0 / (TAU * cutoff_hz)
    a = dt / (rc + dt)
    out = [0.0] * len(data)
    y = 0.0
    for i, x in enumerate(data):
        y += a * (x - y)
        out[i] = y
    return out


def highpass(data: list[float], cutoff_hz: float) -> list[float]:
    lp = lowpass(data, cutoff_hz)
    return [x - y for x, y in zip(data, lp)]


def reverb(data: list[float], delays_ms=(37.0, 61.0, 97.0), decay: float = 0.34) -> list[float]:
    out = list(data)
    for d_ms in delays_ms:
        d = int(RATE * d_ms / 1000.0)
        g = decay
        i = d
        while i < len(out):
            out[i] += out[i - d] * g
            i += 1
        decay *= 0.7
    return out


# ---------------------------------------------------------------- oscillators

def shape(kind: str, phase: float) -> float:
    if kind == "sine":
        return math.sin(phase)
    if kind == "square":
        return 1.0 if math.sin(phase) >= 0.0 else -1.0
    if kind == "saw":
        return 2.0 * ((phase / TAU) % 1.0) - 1.0
    if kind == "tri":
        return 2.0 * abs(2.0 * ((phase / TAU) % 1.0) - 1.0) - 1.0
    raise ValueError(kind)


def freq_const(f: float):
    return lambda t: f


def freq_lin(f0: float, f1: float, dur: float):
    return lambda t: f0 + (f1 - f0) * min(1.0, t / dur)


def freq_exp(f0: float, f1: float, dur: float):
    f1 = max(1e-3, f1)
    return lambda t: f0 * (f1 / f0) ** min(1.0, t / dur)


def env_exp(decay: float, attack: float = 0.003):
    def fn(t: float) -> float:
        e = math.exp(-t / max(1e-4, decay))
        if t < attack:
            e *= t / attack
        return e
    return fn


def env_gate(attack: float, release: float, sustain: float = 1.0):
    def fn(t: float) -> float:
        if t < attack:
            return (t / attack) * sustain
        return sustain
    return fn


def env_adsr(a: float, d: float, s: float, r: float, dur: float):
    def fn(t: float) -> float:
        if t < a:
            return t / max(1e-4, a)
        if t < a + d:
            return 1.0 - (1.0 - s) * ((t - a) / max(1e-4, d))
        rem = dur - t
        if rem < r:
            return s * max(0.0, rem / max(1e-4, r))
        return s
    return fn


def tone(
    dur: float,
    freq,
    kind: str = "sine",
    amp: float = 0.5,
    env=None,
    vib: float = 0.0,
    vib_hz: float = 5.0,
    detune: float = 0.0,
) -> list[float]:
    if isinstance(freq, (int, float)):
        freq = freq_const(float(freq))
    if env is None:
        env = env_exp(dur * 0.5)
    n = int(dur * RATE)
    out = [0.0] * n
    ph = 0.0
    ph2 = 0.0
    for i in range(n):
        t = i / RATE
        f = freq(t)
        if vib:
            f *= 1.0 + vib * math.sin(TAU * vib_hz * t)
        ph += TAU * f / RATE
        s = shape(kind, ph)
        if detune:
            ph2 += TAU * f * (1.0 + detune) / RATE
            s = 0.5 * (s + shape(kind, ph2))
        out[i] = s * amp * env(t)
    return out


def noise(dur: float, amp: float = 0.4, env=None, seed: int = 1) -> list[float]:
    rng = random.Random(seed)
    if env is None:
        env = env_exp(dur * 0.4)
    n = int(dur * RATE)
    return [rng.uniform(-1.0, 1.0) * amp * env(i / RATE) for i in range(n)]


def click(dur: float = 0.012, amp: float = 0.5, seed: int = 7) -> list[float]:
    return noise(dur, amp, env_exp(dur * 0.35), seed=seed)


def hz(midi: float) -> float:
    return 440.0 * 2.0 ** ((midi - 69.0) / 12.0)


def write_wav(path: str, data: list[float]) -> int:
    data = fade(data, 5.0)
    frames = bytearray()
    for s in data:
        v = int(max(-1.0, min(1.0, s)) * 32000)
        frames += struct.pack("<h", v)
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(bytes(frames))
    return len(frames)


# ------------------------------------------------------------------- ui + sfx

def sfx_ui_hover() -> list[float]:
    out = tone(0.045, freq_const(1240), "sine", 0.5, env_exp(0.016))
    return out


def sfx_ui_click() -> list[float]:
    out = tone(0.07, freq_exp(1320, 900, 0.07), "square", 0.34, env_exp(0.022))
    place(out, tone(0.05, freq_const(1980), "sine", 0.18, env_exp(0.012)))
    return out


def sfx_ui_back() -> list[float]:
    out = tone(0.11, freq_exp(760, 330, 0.11), "tri", 0.42, env_exp(0.035))
    return out


def sfx_punch_light() -> list[float]:
    out = noise(0.1, 0.5, env_exp(0.026), seed=11)
    out = lowpass(out, 2600.0)
    place(out, tone(0.13, freq_exp(220, 130, 0.13), "sine", 0.55, env_exp(0.045)))
    place(out, click(0.01, 0.35, seed=3))
    return out


def sfx_punch_heavy() -> list[float]:
    out = noise(0.17, 0.55, env_exp(0.05), seed=21)
    out = lowpass(out, 1900.0)
    place(out, tone(0.26, freq_exp(150, 68, 0.26), "sine", 0.75, env_exp(0.09)))
    place(out, tone(0.09, freq_const(320), "square", 0.16, env_exp(0.03)))
    place(out, click(0.012, 0.4, seed=5))
    return softclip(out, 1.2)


def sfx_block() -> list[float]:
    out = noise(0.14, 0.4, env_exp(0.05), seed=31)
    out = lowpass(out, 1200.0)
    place(out, tone(0.2, freq_const(430), "tri", 0.3, env_exp(0.07)))
    place(out, tone(0.2, freq_const(646), "sine", 0.22, env_exp(0.07)))
    place(out, tone(0.14, freq_const(1290), "sine", 0.1, env_exp(0.04)))
    return out


def sfx_whiff() -> list[float]:
    body = noise(0.16, 0.5, env_adsr(0.03, 0.05, 0.5, 0.09, 0.16), seed=41)
    body = highpass(lowpass(body, 3200.0), 380.0)
    out = list(body)
    place(out, noise(0.16, 0.18, env_exp(0.06), seed=42))
    return out


def sfx_dash() -> list[float]:
    whoosh = noise(0.2, 0.5, env_adsr(0.02, 0.06, 0.55, 0.12, 0.2), seed=51)
    whoosh = lowpass(whoosh, 4200.0)
    out = highpass(whoosh, 500.0)
    place(out, tone(0.2, freq_exp(900, 240, 0.2), "tri", 0.12, env_exp(0.07)))
    return out


def sfx_jump() -> list[float]:
    out = tone(0.19, freq_exp(240, 560, 0.19), "sine", 0.5, env_adsr(0.006, 0.06, 0.6, 0.1, 0.19))
    place(out, tone(0.19, freq_exp(480, 1120, 0.19), "tri", 0.12, env_exp(0.07)))
    place(out, click(0.008, 0.22, seed=61))
    return out


def sfx_land() -> list[float]:
    out = tone(0.2, freq_exp(160, 60, 0.2), "sine", 0.7, env_exp(0.055))
    place(out, noise(0.12, 0.3, env_exp(0.03), seed=71))
    return out


def sfx_yeet_charge() -> list[float]:
    dur = 0.72
    out = tone(dur, freq_exp(120, 520, dur), "saw", 0.28, env_adsr(0.08, 0.2, 0.85, 0.15, dur))
    place(out, tone(dur, freq_exp(60, 260, dur), "square", 0.16, env_adsr(0.05, 0.2, 0.8, 0.15, dur)))
    trem = noise(dur, 0.09, env_adsr(0.2, 0.1, 0.7, 0.2, dur), seed=81)
    for i in range(len(trem)):
        trem[i] *= 0.5 + 0.5 * math.sin(TAU * 14.0 * (i / RATE))
    place(out, trem)
    place(out, noise(dur, 0.1, env_exp(0.6), seed=82))
    return softclip(out, 1.15)


def sfx_yeet_impact() -> list[float]:
    out = tone(0.55, freq_exp(90, 34, 0.55), "sine", 0.95, env_exp(0.16))
    place(out, tone(0.3, freq_exp(240, 70, 0.3), "square", 0.24, env_exp(0.08)))
    crash = noise(0.4, 0.6, env_exp(0.09), seed=91)
    crash = lowpass(crash, 3000.0)
    place(out, crash)
    place(out, click(0.02, 0.6, seed=92))
    place(out, tone(0.7, freq_const(140), "sine", 0.2, env_exp(0.3)))
    return softclip(reverb(out, decay=0.28), 1.25)


def sfx_ko_hit() -> list[float]:
    out = tone(0.7, freq_exp(120, 40, 0.7), "sine", 0.9, env_exp(0.22))
    place(out, noise(0.35, 0.55, env_exp(0.08), seed=101))
    place(out, tone(0.5, freq_exp(660, 180, 0.5), "tri", 0.22, env_exp(0.14)))
    out = reverb(out, delays_ms=(53.0, 89.0, 131.0), decay=0.4)
    return softclip(out, 1.3)


def sfx_combo_up() -> list[float]:
    out = buf(0.3)
    for i, m in enumerate([76, 81, 88]):
        place(out, tone(0.12, freq_const(hz(m)), "square", 0.24, env_exp(0.035)), at=i * 0.055)
        place(out, tone(0.12, freq_const(hz(m + 12)), "sine", 0.14, env_exp(0.03)), at=i * 0.055)
    return out


def sfx_count_beep() -> list[float]:
    out = tone(0.16, freq_const(660), "square", 0.32, env_adsr(0.004, 0.06, 0.5, 0.09, 0.16))
    place(out, tone(0.16, freq_const(1320), "sine", 0.12, env_exp(0.05)))
    return out


def sfx_go() -> list[float]:
    dur = 0.45
    out = tone(dur, freq_const(880), "square", 0.3, env_adsr(0.004, 0.1, 0.55, 0.2, dur))
    place(out, tone(dur, freq_const(1318), "square", 0.22, env_adsr(0.004, 0.1, 0.5, 0.2, dur)))
    place(out, tone(dur, freq_const(1760), "sine", 0.12, env_exp(0.18)))
    place(out, click(0.01, 0.3, seed=111))
    return out


def sfx_error() -> list[float]:
    out = tone(0.28, freq_exp(420, 250, 0.28), "square", 0.3, env_adsr(0.004, 0.05, 0.7, 0.08, 0.28))
    place(out, tone(0.28, freq_exp(210, 125, 0.28), "saw", 0.16, env_adsr(0.004, 0.05, 0.7, 0.08, 0.28)))
    for i in range(len(out)):
        out[i] *= 0.8 + 0.2 * math.sin(TAU * 32.0 * (i / RATE))
    return out


def sfx_arena_warning() -> list[float]:
    dur = 0.6
    out = buf(dur)
    for i in range(4):
        f = 520.0 if i % 2 == 0 else 720.0
        place(out, tone(0.13, freq_const(f), "square", 0.26, env_adsr(0.01, 0.04, 0.7, 0.05, 0.13)), at=i * 0.14)
    place(out, tone(dur, freq_const(260), "sine", 0.14, env_adsr(0.02, 0.1, 0.6, 0.2, dur)))
    return out


def sfx_hazard_warn() -> list[float]:
    out = buf(0.34)
    for i in range(3):
        place(out, tone(0.08, freq_const(1050 + i * 90), "sine", 0.3, env_exp(0.022)), at=i * 0.09)
    return out


def sfx_victory() -> list[float]:
    dur = 1.5
    out = buf(dur)
    melody = [(72, 0.0, 0.18), (76, 0.18, 0.18), (79, 0.36, 0.18), (84, 0.54, 0.62)]
    for m, t, d in melody:
        place(out, tone(d, freq_const(hz(m)), "square", 0.26, env_adsr(0.008, 0.08, 0.6, 0.12, d)), at=t)
        place(out, tone(d, freq_const(hz(m + 12)), "sine", 0.14, env_exp(d * 0.6)), at=t)
        place(out, tone(d, freq_const(hz(m - 12)), "tri", 0.12, env_exp(d * 0.5)), at=t)
    place(out, tone(0.9, freq_const(hz(48)), "sine", 0.22, env_adsr(0.01, 0.1, 0.5, 0.3, 0.9)), at=0.54)
    out = reverb(out, delays_ms=(43.0, 79.0), decay=0.3)
    return normalize(out, 0.85)


def sfx_defeat() -> list[float]:
    dur = 1.4
    out = buf(dur)
    melody = [(67, 0.0, 0.22), (64, 0.22, 0.22), (60, 0.44, 0.3), (55, 0.74, 0.6)]
    for m, t, d in melody:
        place(out, tone(d, freq_const(hz(m)), "tri", 0.3, env_adsr(0.02, 0.1, 0.55, 0.2, d)), at=t)
        place(out, tone(d, freq_const(hz(m - 12)), "sine", 0.18, env_exp(d * 0.7)), at=t)
    place(out, tone(1.2, freq_const(hz(43)), "sine", 0.16, env_adsr(0.05, 0.2, 0.5, 0.4, 1.2)), at=0.2)
    return normalize(reverb(out, delays_ms=(61.0, 101.0), decay=0.32), 0.85)


def sfx_submit_ok() -> list[float]:
    out = buf(0.34)
    place(out, tone(0.14, freq_const(hz(79)), "sine", 0.34, env_adsr(0.006, 0.05, 0.6, 0.07, 0.14)))
    place(out, tone(0.22, freq_const(hz(86)), "sine", 0.3, env_adsr(0.006, 0.06, 0.6, 0.1, 0.22)), at=0.13)
    place(out, tone(0.3, freq_const(hz(91)), "sine", 0.14, env_exp(0.16)), at=0.13)
    return out


def sfx_submit_err() -> list[float]:
    out = buf(0.36)
    place(out, tone(0.15, freq_exp(420, 360, 0.15), "square", 0.28, env_adsr(0.005, 0.05, 0.7, 0.06, 0.15)))
    place(out, tone(0.24, freq_exp(300, 210, 0.24), "square", 0.26, env_adsr(0.005, 0.06, 0.7, 0.1, 0.24)), at=0.14)
    return out


SFX = {
    "ui_hover": sfx_ui_hover,
    "ui_click": sfx_ui_click,
    "ui_back": sfx_ui_back,
    "punch_light": sfx_punch_light,
    "punch_heavy": sfx_punch_heavy,
    "block": sfx_block,
    "whiff": sfx_whiff,
    "dash": sfx_dash,
    "jump": sfx_jump,
    "land": sfx_land,
    "yeet_charge": sfx_yeet_charge,
    "yeet_impact": sfx_yeet_impact,
    "ko_hit": sfx_ko_hit,
    "combo_up": sfx_combo_up,
    "count_beep": sfx_count_beep,
    "go": sfx_go,
    "error": sfx_error,
    "arena_warning": sfx_arena_warning,
    "hazard_warn": sfx_hazard_warn,
    "victory": sfx_victory,
    "defeat": sfx_defeat,
    "submit_ok": sfx_submit_ok,
    "submit_err": sfx_submit_err,
}


# ------------------------------------------------------------------ music beds

def drum_kick(amp: float = 0.85) -> list[float]:
    out = tone(0.26, freq_exp(120, 46, 0.26), "sine", amp, env_exp(0.07))
    place(out, click(0.01, amp * 0.5, seed=201))
    return out


def drum_snare(amp: float = 0.5) -> list[float]:
    body = noise(0.16, amp, env_exp(0.05), seed=202)
    place(body, tone(0.1, freq_exp(260, 170, 0.1), "tri", amp * 0.5, env_exp(0.03)))
    return highpass(body, 700.0)


def drum_hat(amp: float = 0.3, dur: float = 0.05) -> list[float]:
    return highpass(noise(dur, amp, env_exp(0.016), seed=203), 6500.0)


def drum_clap(amp: float = 0.4) -> list[float]:
    out = buf(0.22)
    for i in range(3):
        place(out, highpass(noise(0.05, amp, env_exp(0.02), seed=210 + i), 900.0), at=i * 0.012)
    return out


def music_menu() -> list[float]:
    """~16s chill synth loop, 90 BPM, A minor."""
    bpm = 90.0
    beat = 60.0 / bpm
    bars = 6
    dur = beat * 4 * bars
    out = buf(dur)

    # chord progression: Am - F - C - G  (repeat)
    prog = [
        (57, [57, 60, 64]),   # Am
        (53, [53, 57, 60]),   # F
        (48, [48, 52, 55]),   # C
        (55, [55, 59, 62]),   # G
    ]

    for b in range(bars):
        root, chord = prog[b % len(prog)]
        t0 = b * 4 * beat
        # pad
        for m in chord:
            pad = tone(4 * beat, freq_const(hz(m)), "sine", 0.12,
                       env_adsr(0.35, 0.6, 0.7, 0.9, 4 * beat), detune=0.004)
            pad = lowpass(pad, 2400.0)
            place(out, pad, at=t0)
        # bass: 8ths on root with octave lift
        for i in range(8):
            m = root if i % 4 != 3 else root + 7
            place(out, tone(beat * 0.42, freq_const(hz(m - 12)), "tri", 0.3,
                            env_adsr(0.006, 0.08, 0.5, 0.1, beat * 0.42)), at=t0 + i * beat * 0.5)
        # arpeggio lead
        arp = [chord[0] + 12, chord[1] + 12, chord[2] + 12, chord[1] + 24]
        for i in range(8):
            m = arp[i % len(arp)]
            place(out, tone(beat * 0.4, freq_const(hz(m)), "square", 0.075,
                            env_exp(0.09), detune=0.006), at=t0 + i * beat * 0.5)
        # soft percussion
        place(out, drum_kick(0.5), at=t0)
        place(out, drum_kick(0.42), at=t0 + beat * 2)
        place(out, drum_hat(0.12), at=t0 + beat * 1)
        place(out, drum_hat(0.1), at=t0 + beat * 3)
        place(out, drum_hat(0.08), at=t0 + beat * 3.5)

    out = lowpass(out, 7000.0)
    out = softclip(out, 1.05)
    return normalize(out, 0.72)


def music_match() -> list[float]:
    """~16s aggressive combat loop, 128 BPM, E minor."""
    bpm = 128.0
    beat = 60.0 / bpm
    bars = 8
    dur = beat * 4 * bars
    out = buf(dur)
    step = beat * 0.25   # 16ths

    roots = [40, 40, 41, 40, 43, 43, 41, 38]        # E E F E G G F D
    riff = [64, 64, 67, 64, 70, 67, 64, 62]

    for b in range(bars):
        root = roots[b % len(roots)]
        t0 = b * 4 * beat

        # drums
        for i in range(4):
            place(out, drum_kick(0.8), at=t0 + i * beat)
        place(out, drum_snare(0.5), at=t0 + beat)
        place(out, drum_snare(0.5), at=t0 + beat * 3)
        place(out, drum_clap(0.35), at=t0 + beat * 3)
        for i in range(8):
            place(out, drum_hat(0.16 if i % 2 else 0.24), at=t0 + i * beat * 0.5)

        # bass: driving 8ths on root with occasional fifth
        for i in range(8):
            m = root - 12 if i % 8 != 6 else root - 5
            bass = tone(beat * 0.44, freq_const(hz(m)), "saw", 0.24,
                        env_adsr(0.004, 0.05, 0.75, 0.06, beat * 0.44))
            place(out, lowpass(bass, 900.0), at=t0 + i * beat * 0.5)

        # lead riff: 16ths, saw with detune, played twice per bar
        for rep in range(2):
            base = t0 + rep * beat * 2
            for i, m in enumerate(riff):
                lead = tone(step * 1.6, freq_const(hz(m + (12 if rep == 1 else 0))), "saw", 0.14,
                            env_adsr(0.004, 0.04, 0.6, 0.05, step * 1.6), detune=0.012)
                place(out, highpass(lead, 220.0), at=base + i * step)

        # stab chord on the last beat
        for m in [root, root + 3, root + 7]:
            stab = tone(beat * 0.3, freq_const(hz(m + 12)), "square", 0.09,
                        env_adsr(0.004, 0.05, 0.4, 0.08, beat * 0.3))
            place(out, stab, at=t0 + beat * 3)

    out = reverb(out, delays_ms=(29.0, 47.0), decay=0.2)
    out = softclip(out, 1.15)
    return normalize(out, 0.76)


MUSIC = {
    "music_menu": music_menu,
    "music_match": music_match,
}


# ------------------------------------------------------------------------ cli

def main() -> int:
    ap = argparse.ArgumentParser(description="Generate YEET ARENA audio.")
    ap.add_argument("--out", default=os.path.join("game", "assets", "audio"),
                    help="output directory (default: game/assets/audio)")
    ap.add_argument("--music", action="store_true", default=True,
                    help="include music loops")
    ap.add_argument("--no-music", dest="music", action="store_false")
    args = ap.parse_args()

    out_dir = os.path.abspath(args.out)
    os.makedirs(out_dir, exist_ok=True)

    total = 0
    count = 0
    for name, fn in SFX.items():
        data = softclip(fn(), 1.05) if name not in ("yeet_impact", "ko_hit") else fn()
        data = normalize(data, 0.85)
        path = os.path.join(out_dir, name + ".wav")
        total += write_wav(path, data)
        count += 1
        print(f"  sfx  {name:<16} {len(data) / RATE:5.2f}s")

    if args.music:
        for name, fn in MUSIC.items():
            data = fn()
            path = os.path.join(out_dir, name + ".wav")
            total += write_wav(path, data)
            count += 1
            print(f"  music {name:<15} {len(data) / RATE:5.2f}s")

    print(f"\n{count} files, {total / 1024.0 / 1024.0:.2f} MB written to {out_dir}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

"""Generates PixelPunch's sound effects and music loops as WAV files.

Everything is synthesised from scratch (no samples, no licences needed):
    python tools/generate_audio.py
Outputs to assets/audio/sfx, assets/audio/voice and assets/audio/music.
"""
import math
import os
import random
import struct
import wave

RATE = 22050
ROOT = os.path.join(os.path.dirname(__file__), "..", "assets", "audio")
rng = random.Random(7)


# --------------------------------------------------------------------------
# Primitives

def osc(kind, phase):
    p = phase % 1.0
    if kind == "sine":
        return math.sin(2 * math.pi * p)
    if kind == "square":
        return 1.0 if p < 0.5 else -1.0
    if kind == "pulse25":
        return 1.0 if p < 0.25 else -1.0
    if kind == "saw":
        return 2.0 * p - 1.0
    if kind == "tri":
        return 4.0 * abs(p - 0.5) - 1.0
    return rng.uniform(-1, 1)  # noise


def env(t, dur, attack=0.005, release=None, curve=2.0):
    """Attack then exponential-ish decay to zero at dur."""
    if t < attack:
        return t / attack
    rel = (t - attack) / max(1e-6, dur - attack)
    return max(0.0, 1.0 - rel) ** curve


def tone(dur, f0, f1=None, kind="sine", vol=0.6, attack=0.005, curve=2.0, vibrato=0.0):
    f1 = f0 if f1 is None else f1
    n = int(dur * RATE)
    out, phase = [], 0.0
    for i in range(n):
        t = i / RATE
        k = i / max(1, n - 1)
        f = f0 * (f1 / f0) ** k if f0 > 0 and f1 > 0 else f0 + (f1 - f0) * k
        if vibrato:
            f *= 1 + vibrato * math.sin(2 * math.pi * 6 * t)
        phase += f / RATE
        out.append(osc(kind, phase) * env(t, dur, attack, curve=curve) * vol)
    return out


def noise(dur, vol=0.5, lowpass=0.0, curve=2.0, attack=0.002):
    n = int(dur * RATE)
    out, last = [], 0.0
    for i in range(n):
        t = i / RATE
        s = rng.uniform(-1, 1)
        last = last * lowpass + s * (1 - lowpass)
        out.append(last * env(t, dur, attack, curve=curve) * vol)
    return out


def mix(*tracks):
    n = max(len(t) for t in tracks)
    return [sum(t[i] for t in tracks if i < len(t)) for i in range(n)]


def concat(*parts):
    out = []
    for p in parts:
        out.extend(p)
    return out


def silence(dur):
    return [0.0] * int(dur * RATE)


def delay(samples, dur):
    return silence(dur) + samples


def save(path, samples, normalize=0.9):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    peak = max(1e-6, max(abs(s) for s in samples))
    gain = normalize / peak if peak > normalize else 1.0
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(b"".join(
            struct.pack("<h", int(max(-1, min(1, s * gain)) * 32767)) for s in samples))


def note_freq(name):
    """'A4' style note names to Hz. 'R' = rest."""
    if name == "R":
        return 0.0
    names = {"C": -9, "C#": -8, "D": -7, "D#": -6, "E": -5, "F": -4, "F#": -3,
             "G": -2, "G#": -1, "A": 0, "A#": 1, "B": 2}
    pitch, octave = name[:-1], int(name[-1])
    return 440.0 * 2 ** ((names[pitch] + (octave - 4) * 12) / 12)


# --------------------------------------------------------------------------
# Sound effects

def sfx():
    d = os.path.join(ROOT, "sfx")
    save(f"{d}/button_tap.wav", tone(0.07, 900, 1300, "square", 0.35, curve=3))
    save(f"{d}/button_back.wav", tone(0.08, 900, 600, "square", 0.35, curve=3))
    save(f"{d}/menu_hover.wav", tone(0.04, 1500, 1500, "sine", 0.25, curve=3))
    save(f"{d}/punch_hit.wav", mix(
        noise(0.12, 0.8, lowpass=0.55, curve=3),
        tone(0.12, 180, 60, "sine", 0.9, curve=2.5)))
    save(f"{d}/punch_heavy.wav", mix(
        noise(0.25, 0.9, lowpass=0.75, curve=2.5),
        tone(0.28, 140, 40, "sine", 1.0, curve=2),
        tone(0.08, 400, 120, "square", 0.25, curve=3)))
    save(f"{d}/punch_miss.wav", noise(0.16, 0.45, lowpass=0.88, curve=1.5, attack=0.06))
    save(f"{d}/dodge_whoosh.wav", mix(
        noise(0.25, 0.5, lowpass=0.9, curve=1.2, attack=0.08),
        tone(0.25, 300, 900, "sine", 0.15, attack=0.08)))
    save(f"{d}/special_activate.wav", mix(
        tone(0.45, 220, 1760, "saw", 0.35, attack=0.01, curve=1.5),
        tone(0.45, 330, 2640, "square", 0.15, curve=1.5),
        delay(noise(0.3, 0.3, lowpass=0.6), 0.15)))
    save(f"{d}/damage_taken.wav", mix(
        tone(0.18, 300, 120, "square", 0.45, curve=2),
        noise(0.1, 0.4, lowpass=0.5)))
    save(f"{d}/knockout.wav", concat(
        mix(tone(0.35, 600, 80, "square", 0.5, curve=1.2), noise(0.3, 0.5, lowpass=0.8)),
        tone(0.25, 90, 50, "sine", 0.8)))
    save(f"{d}/health_low.wav", concat(
        tone(0.1, 880, 880, "square", 0.35), silence(0.08), tone(0.1, 880, 880, "square", 0.35)))
    save(f"{d}/villain_discover.wav", concat(
        tone(0.12, note_freq("E4"), kind="saw", vol=0.4, curve=1),
        tone(0.12, note_freq("D#4"), kind="saw", vol=0.4, curve=1),
        tone(0.45, note_freq("A#3"), kind="saw", vol=0.5, curve=1.2, vibrato=0.01)))
    fanfare = []
    for n, l in [("C5", .12), ("E5", .12), ("G5", .12), ("C6", .4), ("G5", .12), ("C6", .55)]:
        fanfare += mix(tone(l, note_freq(n), kind="square", vol=0.35, curve=0.8),
                       tone(l, note_freq(n) / 2, kind="tri", vol=0.3, curve=0.8))
    save(f"{d}/victory_fanfare.wav", fanfare)
    sting = []
    for n, l in [("G4", .25), ("F#4", .25), ("F4", .25), ("E4", .8)]:
        sting += tone(l, note_freq(n), kind="saw", vol=0.35, curve=0.7, vibrato=0.006)
    save(f"{d}/defeat_sting.wav", sting)
    save(f"{d}/level_up.wav", concat(*[
        tone(0.08, note_freq(n), kind="square", vol=0.35, curve=1)
        for n in ["C5", "E5", "G5", "C6", "E6", "G6"]]))
    save(f"{d}/countdown.wav", tone(0.15, 660, 660, "square", 0.4, curve=2))
    # Weapons / pickups for the 3D game and future 2D use.
    save(f"{d}/gun_shot.wav", mix(
        noise(0.22, 1.0, lowpass=0.35, curve=3.5),
        tone(0.15, 160, 50, "sine", 0.9, curve=2.5)))
    save(f"{d}/gun_reload.wav", concat(
        noise(0.04, 0.6, lowpass=0.2, curve=4), silence(0.18),
        noise(0.05, 0.7, lowpass=0.1, curve=4), silence(0.06),
        tone(0.05, 2000, 1500, "square", 0.2, curve=4)))
    save(f"{d}/item_pickup.wav", concat(
        tone(0.06, note_freq("A5"), kind="square", vol=0.3),
        tone(0.1, note_freq("E6"), kind="square", vol=0.3)))
    save(f"{d}/jump.wav", tone(0.16, 250, 600, "square", 0.3, curve=1.5))
    save(f"{d}/land.wav", mix(noise(0.08, 0.5, lowpass=0.8, curve=3), tone(0.08, 90, 50, "sine", 0.6)))
    save(f"{d}/footstep.wav", noise(0.05, 0.35, lowpass=0.85, curve=3))


# --------------------------------------------------------------------------
# Voice blips (Animal Crossing style gibberish for dialogue)

def voices():
    d = os.path.join(ROOT, "voice")
    params = {
        "balanced": (330, "square"), "tank": (140, "square"), "speedster": (620, "pulse25"),
        "heavyHitter": (110, "saw"), "trickster": (520, "tri"), "support": (440, "sine"),
        "villain": (180, "saw"), "narrator": (260, "tri"),
    }
    for name, (f, kind) in params.items():
        save(f"{d}/{name}.wav", tone(0.06, f, f * 1.15, kind, 0.35, attack=0.004, curve=1.5))


# --------------------------------------------------------------------------
# Music: simple 4-channel chiptune loops

def render_song(bpm, bars, lead, bass, chords, drums, lead_kind="square", swing=0.0):
    beat = 60.0 / bpm
    step = beat / 4  # 16th notes
    steps = bars * 16
    n = int(steps * step * RATE)
    out = [0.0] * n

    def place(start_step, samples):
        start = int(start_step * step * RATE)
        for i, s in enumerate(samples):
            if start + i < n:
                out[start + i] += s

    # lead: list of (note, steps)
    pos = 0
    while pos < steps:
        for note, length in lead:
            if pos >= steps:
                break
            f = note_freq(note)
            if f:
                place(pos, tone(length * step * 0.95, f, kind=lead_kind, vol=0.16, attack=0.01, curve=0.6))
            pos += length
    pos = 0
    while pos < steps:
        for note, length in bass:
            if pos >= steps:
                break
            f = note_freq(note)
            if f:
                place(pos, tone(length * step * 0.9, f, kind="tri", vol=0.3, attack=0.005, curve=0.4))
            pos += length
    # chords: one per bar, arpeggiated 16ths
    for bar in range(bars):
        chord = chords[bar % len(chords)]
        for s in range(16):
            f = note_freq(chord[s % len(chord)])
            place(bar * 16 + s, tone(step * 0.8, f, kind="pulse25", vol=0.06, curve=2))
    # drums: pattern string per bar, k=kick s=snare h=hat .=rest
    for bar in range(bars):
        for s, c in enumerate(drums):
            if c == "k":
                place(bar * 16 + s, tone(0.12, 150, 45, "sine", 0.5, curve=2))
            elif c == "s":
                place(bar * 16 + s, mix(noise(0.12, 0.3, lowpass=0.3, curve=2.5), tone(0.08, 220, 180, "tri", 0.15)))
            elif c == "h":
                place(bar * 16 + s, noise(0.03, 0.12, lowpass=0.0, curve=3))
    return out


def music():
    d = os.path.join(ROOT, "music")
    save(f"{d}/menu_theme.wav", render_song(
        112, 8,
        lead=[("E5", 2), ("G5", 2), ("A5", 4), ("G5", 2), ("E5", 2), ("D5", 4),
              ("C5", 2), ("D5", 2), ("E5", 4), ("R", 4), ("D5", 2), ("E5", 2), ("G5", 6), ("R", 2)],
        bass=[("A2", 4), ("A2", 4), ("F2", 4), ("F2", 4), ("C3", 4), ("C3", 4), ("G2", 4), ("G2", 4)],
        chords=[["A4", "C5", "E5"], ["F4", "A4", "C5"], ["C4", "E4", "G4"], ["G4", "B4", "D5"]],
        drums="k...h...s...h..h"), normalize=0.7)
    save(f"{d}/battle_theme_1.wav", render_song(
        150, 8,
        lead=[("E5", 1), ("R", 1), ("E5", 1), ("G5", 1), ("A5", 2), ("G5", 2), ("E5", 2), ("D5", 2), ("E5", 4),
              ("B4", 1), ("R", 1), ("B4", 1), ("D5", 1), ("E5", 2), ("D5", 2), ("B4", 2), ("A4", 2), ("B4", 4)],
        bass=[("E2", 2), ("E3", 2)] * 4 + [("C2", 2), ("C3", 2)] * 2 + [("D2", 2), ("D3", 2)] * 2,
        chords=[["E4", "G4", "B4"], ["E4", "G4", "B4"], ["C4", "E4", "G4"], ["D4", "F#4", "A4"]],
        drums="k.h.s.h.k.k.s.hh", lead_kind="pulse25"), normalize=0.7)
    save(f"{d}/battle_theme_2.wav", render_song(
        140, 8,
        lead=[("D5", 2), ("F5", 2), ("A5", 2), ("G5", 2), ("F5", 2), ("E5", 2), ("D5", 4),
              ("C5", 2), ("E5", 2), ("G5", 2), ("F5", 2), ("E5", 4), ("R", 4)],
        bass=[("D2", 2), ("D3", 2)] * 4 + [("A#1", 2), ("A#2", 2)] * 2 + [("C2", 2), ("C3", 2)] * 2,
        chords=[["D4", "F4", "A4"], ["A#3", "D4", "F4"], ["C4", "E4", "G4"], ["A3", "C#4", "E4"]],
        drums="k.h.s.h.kkh.s.h.", lead_kind="square"), normalize=0.7)
    save(f"{d}/exploration.wav", render_song(
        96, 8,
        lead=[("C5", 4), ("E5", 4), ("G5", 6), ("R", 2), ("F5", 4), ("E5", 4), ("D5", 8)],
        bass=[("C3", 8), ("A2", 8), ("F2", 8), ("G2", 8)],
        chords=[["C4", "E4", "G4"], ["A3", "C4", "E4"], ["F3", "A3", "C4"], ["G3", "B3", "D4"]],
        drums="k.......h.......", lead_kind="tri"), normalize=0.6)
    save(f"{d}/villain_lab.wav", render_song(
        100, 8,
        lead=[("A4", 2), ("C5", 2), ("D#5", 4), ("D5", 2), ("C5", 2), ("A4", 4),
              ("G#4", 4), ("A4", 4), ("R", 8)],
        bass=[("A2", 4), ("A2", 4), ("D#2", 4), ("D2", 4)],
        chords=[["A3", "C4", "E4"], ["D#4", "F#4", "A4"], ["D4", "F4", "A4"], ["E4", "G#4", "B4"]],
        drums="k...h.h.s...h...", lead_kind="saw"), normalize=0.6)
    save(f"{d}/victory_theme.wav", render_song(
        128, 4,
        lead=[("C5", 2), ("E5", 2), ("G5", 2), ("C6", 4), ("G5", 2), ("A5", 2), ("C6", 8), ("R", 8),
              ("F5", 2), ("A5", 2), ("C6", 4), ("B5", 4), ("C6", 12)],
        bass=[("C3", 4), ("G2", 4), ("A2", 4), ("F2", 4)],
        chords=[["C4", "E4", "G4"], ["F4", "A4", "C5"], ["G4", "B4", "D5"], ["C4", "E4", "G4"]],
        drums="k.h.s.h.k.h.s.h.", lead_kind="square"), normalize=0.7)


if __name__ == "__main__":
    sfx()
    voices()
    music()
    total = 0
    for dirpath, _, files in os.walk(ROOT):
        for f in files:
            total += os.path.getsize(os.path.join(dirpath, f))
    print(f"Generated audio into {os.path.abspath(ROOT)} ({total / 1e6:.1f} MB)")

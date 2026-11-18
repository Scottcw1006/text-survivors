#!/usr/bin/env python3
"""產生遊戲用的 8-bit 風格音樂與音效（純 Python，不需要額外套件）。

執行：python3 tools/gen_audio.py
輸出：audio/*.wav（22050 Hz、16-bit、單聲道）

全部都是用程式合成的（方波、三角波、雜訊），沒有用到任何外部素材，
想改旋律或音色就改這個檔案再執行一次。
"""
import math
import os
import random
import struct
import wave

RATE = 22050
OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "audio")


# ---------- 基本工具 ----------

def freq(note):
    """MIDI 音高 -> 頻率（69 = A4 = 440Hz）"""
    return 440.0 * 2 ** ((note - 69) / 12)


def n(name):
    """音名 -> MIDI，例如 'A4'、'C#5'"""
    names = {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}
    base = names[name[0]]
    i = 1
    if name[i] == "#":
        base += 1
        i += 1
    elif name[i] == "b":
        base -= 1
        i += 1
    return base + 12 * (int(name[i:]) + 1)


def square(phase, duty=0.5):
    return 1.0 if (phase % 1.0) < duty else -1.0


def triangle(phase):
    p = phase % 1.0
    return 4 * p - 1 if p < 0.5 else 3 - 4 * p


class Noise:
    """有「顆粒感」的雜訊：每隔幾個 sample 才換一個值，越低沉的雜訊換得越慢"""

    def __init__(self, seed=1):
        self.rng = random.Random(seed)
        self.v = 0.0
        self.c = 0

    def sample(self, hold=1):
        if self.c <= 0:
            self.v = self.rng.uniform(-1, 1)
            self.c = hold
        self.c -= 1
        return self.v


def env(t, length, attack=0.003, release=None):
    """簡單的音量包絡：快速起音，然後線性淡出到 length"""
    if t < attack:
        return t / attack
    if release is None:
        return max(0.0, 1.0 - (t - attack) / max(1e-6, length - attack))
    if t > length - release:
        return max(0.0, (length - t) / release)
    return 1.0


def mix_into(buf, start, samples, vol=1.0):
    for i, s in enumerate(samples):
        j = start + i
        if j >= len(buf):
            break
        buf[j] += s * vol


def save(name, buf, peak=0.9):
    os.makedirs(OUT, exist_ok=True)
    m = max(1e-6, max(abs(x) for x in buf))
    scale = peak / m if m > peak else 1.0
    path = os.path.join(OUT, name + ".wav")
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, x * scale)) * 32767)) for x in buf))
    print(f"{path}  {len(buf) / RATE:.2f}s")


# ---------- 音色 ----------

def tone(f0, length, kind="square", duty=0.5, f1=None, vib=0.0, attack=0.003, release=None):
    """一個音：f0 -> f1 滑音（f1=None 不滑）"""
    out = []
    phase = 0.0
    total = int(length * RATE)
    for i in range(total):
        t = i / RATE
        k = i / max(1, total - 1)
        f = f0 if f1 is None else f0 * (f1 / f0) ** k
        if vib:
            f *= 1 + vib * math.sin(t * 2 * math.pi * 6)
        phase += f / RATE
        if kind == "square":
            s = square(phase, duty)
        elif kind == "tri":
            s = triangle(phase)
        else:
            s = math.sin(phase * 2 * math.pi)
        out.append(s * env(t, length, attack, release))
    return out


def noise(length, hold=1, seed=1, decay=1.0, lowpass=1.0):
    """雜訊：hold 越大越低沉；lowpass 0~1，越小越悶"""
    nz = Noise(seed)
    out = []
    y = 0.0
    total = int(length * RATE)
    for i in range(total):
        t = i / RATE
        x = nz.sample(hold)
        y += (x - y) * lowpass
        out.append(y * env(t, length) ** decay)
    return out


def kick(length=0.18):
    return [s * 1.2 for s in tone(150, length, "sine", f1=40)]


def snare(length=0.12):
    return [a * 0.7 + b * 0.3 for a, b in zip(noise(length, 1, 7, 1.5), tone(220, length, "tri", f1=120))]


def hat(length=0.03):
    return noise(length, 1, 3, 2.0)


# ---------- 音樂 ----------

def song(bpm, bars, chords, lead_fn, bass_fn, drum_fn, seed):
    """chords：每兩小節一個和弦（MIDI 根音、是否小調），整首重複到 bars 小節"""
    beat = 60.0 / bpm
    eighth = beat / 2
    total = int(bars * 4 * beat * RATE)
    buf = [0.0] * total
    rng = random.Random(seed)
    for bar in range(bars):
        root, minor = chords[(bar // 2) % len(chords)]
        bar_start = bar * 4 * beat
        lead_fn(buf, bar, bar_start, eighth, root, minor, rng)
        bass_fn(buf, bar, bar_start, eighth, root)
        drum_fn(buf, bar, bar_start, eighth)
    return buf


def chord_tones(root, minor):
    third = 3 if minor else 4
    return [root, root + third, root + 7]


def make_main():
    """一般關卡：A 小調，140 BPM，Am - F - C - G"""
    chords = [(n("A3"), True), (n("F3"), False), (n("C4"), False), (n("G3"), False)]
    # 八小節的旋律動機（每拍一個 8 分音符位置：音程相對和弦根音，None = 休止）
    motifs = [
        [12, None, 15, 19, 17, 15, 12, None],
        [19, None, 17, 15, 12, None, 10, 12],
        [12, 12, 15, None, 19, 22, 19, 17],
        [15, None, 12, None, 10, 12, None, None],
    ]

    def lead(buf, bar, start, eighth, root, minor, rng):
        m = motifs[bar % len(motifs)]
        for i, iv in enumerate(m):
            if iv is None:
                continue
            note = root + iv
            if not minor and iv in (15, 3):   # 大調和弦把小三度改成大三度
                note += 1
            length = eighth * (2 if i + 1 < len(m) and m[i + 1] is None else 1)
            mix_into(buf, int((start + i * eighth) * RATE),
                     tone(freq(note + 12), length * 0.95, "square", 0.25, vib=0.004, release=0.03), 0.16)

    def bass(buf, bar, start, eighth, root):
        for i in range(8):
            note = root - 12 + (12 if i % 2 else 0)
            mix_into(buf, int((start + i * eighth) * RATE), tone(freq(note), eighth * 0.9, "tri", release=0.02), 0.32)

    def drums(buf, bar, start, eighth):
        for i in range(8):
            t = int((start + i * eighth) * RATE)
            if i in (0, 4):
                mix_into(buf, t, kick(), 0.45)
            if i in (2, 6):
                mix_into(buf, t, snare(), 0.22)
            mix_into(buf, t, hat(), 0.06)

    return song(140, 16, chords, lead, bass, drums, 11)


def make_final():
    """決戰：更快、更緊張，Am - Am - F - E，16 分音符琶音"""
    chords = [(n("A3"), True), (n("A3"), True), (n("F3"), False), (n("E3"), False)]

    def lead(buf, bar, start, eighth, root, minor, rng):
        tones = chord_tones(root, minor) + [root + 12]
        six = eighth / 2
        pattern = [0, 1, 2, 3, 2, 1, 2, 3] if bar % 2 == 0 else [3, 2, 1, 0, 1, 2, 3, 2]
        for i in range(16):
            note = tones[pattern[i % 8]] + 12
            mix_into(buf, int((start + i * six) * RATE), tone(freq(note), six * 0.8, "square", 0.125, release=0.01), 0.12)
        # 上面一條長音的主旋律
        top = [12, 15, 14, 11] if minor else [12, 16, 14, 11]
        for k, iv in enumerate(top):
            mix_into(buf, int((start + k * eighth * 2) * RATE),
                     tone(freq(root + iv + 12), eighth * 1.9, "square", 0.5, vib=0.006, release=0.05), 0.09)

    def bass(buf, bar, start, eighth, root):
        six = eighth / 2
        for i in range(16):
            note = root - 12 + (7 if i % 4 == 3 else 0)
            mix_into(buf, int((start + i * six) * RATE), tone(freq(note), six * 0.85, "tri", release=0.01), 0.34)

    def drums(buf, bar, start, eighth):
        for i in range(8):
            t = int((start + i * eighth) * RATE)
            if i % 2 == 0:
                mix_into(buf, t, kick(0.14), 0.5)
            if i in (2, 6):
                mix_into(buf, t, snare(), 0.26)
            mix_into(buf, t, hat(), 0.08)
            mix_into(buf, int(t + eighth / 2 * RATE), hat(0.02), 0.05)

    return song(168, 16, chords, lead, bass, drums, 23)


# ---------- 音效 ----------

def arpeggio(notes, step, kind="square", duty=0.5, tail=0.0):
    buf = [0.0] * int((len(notes) * step + tail + 0.05) * RATE)
    for i, note in enumerate(notes):
        length = step + (tail if i == len(notes) - 1 else 0)
        mix_into(buf, int(i * step * RATE), tone(freq(note), length, kind, duty, release=0.02), 0.6)
    return buf


def layer(*parts):
    length = max(len(p) for p, _ in parts)
    buf = [0.0] * length
    for p, v in parts:
        mix_into(buf, 0, p, v)
    return buf


SFX = {
    "shoot": lambda: tone(900, 0.06, "square", 0.25, f1=350),
    "slash": lambda: layer((noise(0.12, 1, 5, 1.2, 0.5), 0.8), (tone(700, 0.08, "square", 0.25, f1=1400), 0.25)),
    "wave": lambda: layer((tone(300, 0.12, "square", 0.25, f1=900), 0.5), (noise(0.12, 1, 9, 1.5, 0.4), 0.4)),
    "hit": lambda: layer((noise(0.04, 2, 2, 1.0), 0.7), (tone(220, 0.04, "square", 0.5, f1=140), 0.4)),
    "kill": lambda: layer((tone(600, 0.14, "square", 0.5, f1=90), 0.5), (noise(0.14, 2, 4, 1.5), 0.5)),
    "gold": lambda: arpeggio([n("E6"), n("B6")], 0.04),
    "level": lambda: arpeggio([n("C5"), n("E5"), n("G5"), n("C6"), n("E6")], 0.07, tail=0.15),
    "chest": lambda: arpeggio([n("G5"), n("B5"), n("D6"), n("G6"), n("B6"), n("D7")], 0.05, "square", 0.25, tail=0.2),
    "pick": lambda: arpeggio([n("C6"), n("G6")], 0.06, "square", 0.25),
    "hurt": lambda: layer((tone(260, 0.22, "square", 0.5, f1=90), 0.6), (noise(0.18, 3, 6, 1.2), 0.5)),
    "dash": lambda: noise(0.16, 1, 8, 0.8, 0.3),
    "jump": lambda: tone(200, 0.16, "square", 0.25, f1=700),
    "land": lambda: layer((tone(120, 0.3, "sine", f1=35), 1.0), (noise(0.25, 4, 10, 1.5, 0.5), 0.6)),
    "smite": lambda: layer((noise(1.0, 2, 12, 1.2, 0.6), 0.7), (tone(90, 1.0, "sine", f1=30), 0.8),
                           (arpeggio([n("A5"), n("E6"), n("A6")], 0.08, "square", 0.25, tail=0.5), 0.4)),
    "boss": lambda: layer(*[(([0.0] * int(i * 0.2 * RATE)) + tone(660 if i % 2 == 0 else 440, 0.18, "square", 0.5,
                                                                    release=0.02), 0.5) for i in range(4)]),
    "final": lambda: layer(*[(([0.0] * int(i * 0.25 * RATE)) + tone(freq(note), 0.4, "square", 0.5, vib=0.01,
                                                                     release=0.1), 0.5)
                             for i, note in enumerate([n("A4"), n("A4"), n("A4"), n("F4"), n("E4")])],
                           (tone(55, 1.4, "tri"), 0.5)),
    "block": lambda: layer((tone(1500, 0.1, "square", 0.5), 0.3), (tone(2250, 0.1, "square", 0.5), 0.25)),
    "explode": lambda: layer((noise(0.45, 3, 13, 1.5, 0.5), 0.9), (tone(100, 0.4, "sine", f1=30), 0.8)),
    "win": lambda: arpeggio([n("C5"), n("E5"), n("G5"), n("C6"), n("G5"), n("C6"), n("E6")], 0.12, "square", 0.25,
                            tail=0.6),
    "lose": lambda: arpeggio([n("E5"), n("C5"), n("A4"), n("E4"), n("A3")], 0.2, "tri", tail=0.6),
    "ui_move": lambda: tone(880, 0.03, "square", 0.25),
    "ui_ok": lambda: arpeggio([n("E5"), n("B5")], 0.05, "square", 0.25),
    "pause": lambda: arpeggio([n("B5"), n("E5")], 0.06, "square", 0.25),
}


if __name__ == "__main__":
    for name, fn in SFX.items():
        save("sfx_" + name, fn())
    save("music_main", make_main(), 0.8)
    save("music_final", make_final(), 0.8)

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
        elif kind == "pluck" or kind == "bell":
            # 撥弦／木琴感：正弦加一點泛音，音量指數衰減（乾淨、不刺耳）
            w = phase * 2 * math.pi
            if kind == "pluck":
                s = math.sin(w) + 0.25 * math.sin(2 * w) * math.exp(-t * 8) + 0.08 * math.sin(3 * w) * math.exp(-t * 14)
            else:
                s = math.sin(w) + 0.3 * math.sin(2.76 * w) * math.exp(-t * 6)
            decay = math.exp(-t / max(0.05, length * 0.35))
            s *= decay * min(1.0, t / 0.004) * min(1.0, (length - t) / 0.01)
            out.append(s * 0.8)
            continue
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
# 風格：Lo-fi，悠閒、乾淨。七和弦鋪底＋撥弦低音＋搖擺的輕鼓＋鐘聲主旋律。


def pad(notes, length, vol=1.0):
    """和弦鋪底：幾個正弦音慢慢淡入淡出，稍微錯開音高讓聲音比較寬"""
    total = int(length * RATE)
    out = [0.0] * total
    for k, note in enumerate(notes):
        for det in (-0.0015, 0.0015):
            f = freq(note) * (1 + det)
            ph = k * 0.37
            for i in range(total):
                t = i / RATE
                a = min(1.0, t / 0.35) * min(1.0, (length - t) / 0.45)
                ph += f / RATE
                out[i] += math.sin(ph * 2 * math.pi) * a * vol / (len(notes) * 2)
    return out


def soft_kick(length=0.22):
    return [s * 0.9 for s in tone(95, length, "sine", f1=45)]


def echo(buf, delay, feedback=0.3, mix=0.35):
    """回音：讓撥弦旋律有空間感"""
    d = int(delay * RATE)
    out = buf[:]
    for i in range(d, len(out)):
        out[i] += out[i - d] * feedback
    return [a * (1 - mix) + b * mix for a, b in zip(buf, out)]


def mix_wrap(buf, start, samples, vol=1.0):
    """跟 mix_into 一樣，但超出結尾的部分繞回開頭（循環播放時接縫才不會斷掉）"""
    total = len(buf)
    for i, x in enumerate(samples):
        buf[(start + i) % total] += x * vol


def brush(length=0.18):
    """刷子小鼓：很悶的雜訊"""
    return noise(length, 1, 21, 2.0, 0.12)


def lofi(bpm, chords, melody, busy=False):
    """Lo-fi：七和弦鋪底、撥弦低音、搖擺節奏的輕鼓、鐘聲主旋律加回音。
    chords：每小節一個和弦（MIDI 音高列表，第一個是低音）
    melody：每小節一串 (音名, 第幾拍開始, 長幾拍)
    busy：決戰用，鼓和低音比較密"""
    beat = 60 / bpm
    swing = beat * 0.62   # 搖擺：第二個 8 分音符晚一點
    bars = 16
    total = int(bars * 4 * beat * RATE)
    buf = [0.0] * total
    lead = [0.0] * total

    def at(t):
        return int(t * RATE)

    for bar in range(bars):
        ch = chords[bar % len(chords)]
        s0 = bar * 4 * beat
        mix_wrap(buf, at(s0), pad([k + 12 for k in ch], 4 * beat), 0.3)
        low = ch[0] - 12
        if busy:
            # 低音：每拍都有，第四拍後半帶一個五度
            for b in range(4):
                mix_wrap(buf, at(s0 + b * beat), tone(freq(low), beat * 0.9, "pluck"), 0.42)
            mix_wrap(buf, at(s0 + 3 * beat + swing), tone(freq(low + 7), beat * 0.5, "pluck"), 0.3)
        else:
            mix_wrap(buf, at(s0), tone(freq(low), beat * 1.5, "pluck"), 0.5)
            mix_wrap(buf, at(s0 + 2.5 * beat), tone(freq(low + 7), beat, "pluck"), 0.35)
        # 鼓：大鼓、刷子小鼓 2、4，很輕的沙鈴
        for b in ((0, 1, 2) if busy else (0, 2)):
            mix_wrap(buf, at(s0 + b * beat), soft_kick(), 0.4 if b != 1 else 0.25)
        mix_wrap(buf, at(s0 + 2 * beat + swing), soft_kick(), 0.2)
        for b in (1, 3):
            mix_wrap(buf, at(s0 + b * beat), brush(), 0.2 if busy else 0.18)
        for b in range(4):
            offs = (0, swing / 2, swing, swing + (beat - swing) / 2) if busy else (0, swing)
            for off in offs:
                mix_wrap(buf, at(s0 + b * beat + off), noise(0.03, 1, 5, 2.0, 0.35), 0.035)
        for name, start, length in melody[bar % len(melody)]:
            mix_wrap(lead, at(s0 + start * beat), tone(freq(n(name)), beat * (length + 0.5), "bell"), 0.22)
    lead = echo(lead, beat * 0.75, 0.3, 0.3)
    return [a + b for a, b in zip(buf, lead)]


def make_main():
    """一般關卡：Lo-fi，Dm7 - G7 - Cmaj7 - Am7，78 BPM"""
    chords = [[n("D3"), n("F3"), n("A3"), n("C4")], [n("G2"), n("F3"), n("B3"), n("D4")],
              [n("C3"), n("E3"), n("G3"), n("B3")], [n("A2"), n("G3"), n("C4"), n("E4")]]
    melody = [
        [("A4", 0, 1.5), ("C5", 1.5, 1), ("D5", 2.5, 1.5)],
        [("F5", 0, 2), ("E5", 2, 1), ("D5", 3, 1)],
        [("E5", 0, 1), ("G5", 1, 1), ("B4", 2, 2)],
        [("C5", 0, 1.5), ("A4", 2, 2)],
        [("D5", 0, 1), ("F5", 1, 1), ("A5", 2, 1), ("G5", 3, 1)],
        [("F5", 0, 3)],
        [("E5", 0, 1), ("D5", 1, 1), ("C5", 2, 1), ("B4", 3, 1)],
        [("A4", 0, 3)],
    ]
    return lofi(78, chords, melody)


def make_final():
    """決戰：一樣是 Lo-fi，但改成小調、快一點、鼓和低音比較密：Am7 - Fmaj7 - Dm7 - E7"""
    chords = [[n("A2"), n("G3"), n("C4"), n("E4")], [n("F2"), n("E3"), n("A3"), n("C4")],
              [n("D3"), n("F3"), n("A3"), n("C4")], [n("E2"), n("D3"), n("G#3"), n("B3")]]
    melody = [
        [("E5", 0, 1), ("A5", 1, 1), ("G5", 2, 1), ("E5", 3, 1)],
        [("C5", 0, 1.5), ("E5", 1.5, 0.5), ("F5", 2, 2)],
        [("D5", 0, 1), ("F5", 1, 1), ("A5", 2, 1.5), ("C6", 3.5, 0.5)],
        [("B5", 0, 1.5), ("G#5", 1.5, 0.5), ("E5", 2, 2)],
        [("A5", 0, 0.5), ("G5", 0.5, 0.5), ("E5", 1, 1), ("C5", 2, 1), ("E5", 3, 1)],
        [("F5", 0, 1), ("E5", 1, 1), ("C5", 2, 2)],
        [("D5", 0, 1), ("E5", 1, 1), ("F5", 2, 1), ("A5", 3, 1)],
        [("G#5", 0, 2), ("B5", 2, 2)],
    ]
    return lofi(92, chords, melody, busy=True)


# ---------- 音效 ----------

def arpeggio(notes, step, kind="bell", duty=0.5, tail=0.0):
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


SFX = {   # 音色以正弦、撥弦、鐘聲為主，比較乾淨，跟 Lo-fi 音樂搭
    "shoot": lambda: tone(880, 0.07, "pluck", f1=620),
    "slash": lambda: layer((noise(0.13, 1, 5, 1.6, 0.18), 0.8), (tone(520, 0.1, "sine", f1=260), 0.3)),
    "wave": lambda: layer((tone(330, 0.16, "sine", f1=660), 0.5), (noise(0.14, 1, 9, 1.8, 0.15), 0.5)),
    "hit": lambda: layer((tone(260, 0.05, "sine", f1=160), 0.7), (noise(0.04, 1, 2, 2.0, 0.2), 0.4)),
    "kill": lambda: layer((tone(520, 0.14, "pluck", f1=260), 0.6), (noise(0.1, 1, 4, 2.0, 0.15), 0.4)),
    "gold": lambda: arpeggio([n("E6"), n("B6")], 0.045),
    "level": lambda: arpeggio([n("C5"), n("E5"), n("G5"), n("C6"), n("E6")], 0.08, tail=0.4),
    "chest": lambda: arpeggio([n("G5"), n("B5"), n("D6"), n("G6"), n("B6"), n("D7")], 0.06, tail=0.4),
    "pick": lambda: arpeggio([n("C6"), n("G6")], 0.06),
    "hurt": lambda: layer((tone(240, 0.24, "sine", f1=110), 0.8), (noise(0.16, 2, 6, 1.5, 0.15), 0.5)),
    "dash": lambda: noise(0.18, 1, 8, 1.0, 0.12),
    "jump": lambda: tone(260, 0.18, "sine", f1=620),
    "land": lambda: layer((tone(110, 0.32, "sine", f1=40), 1.0), (noise(0.25, 2, 10, 1.8, 0.1), 0.6)),
    "smite": lambda: layer((noise(1.0, 1, 12, 1.4, 0.12), 0.6), (tone(80, 1.0, "sine", f1=35), 0.8),
                           (arpeggio([n("A5"), n("E6"), n("A6")], 0.09, tail=0.7), 0.5)),
    "boss": lambda: layer(*[(([0.0] * int(i * 0.22 * RATE)) + tone(freq(note), 0.3, "bell"), 0.6)
                            for i, note in enumerate([n("E5"), n("C5"), n("E5"), n("C5")])],
                          (tone(65, 1.0, "sine"), 0.4)),
    "final": lambda: layer(*[(([0.0] * int(i * 0.28 * RATE)) + tone(freq(note), 0.6, "bell"), 0.6)
                             for i, note in enumerate([n("A4"), n("C5"), n("E5"), n("G#5"), n("A5")])],
                           (tone(55, 1.6, "sine"), 0.5)),
    "block": lambda: layer((tone(1500, 0.2, "bell"), 0.4), (tone(2250, 0.2, "bell"), 0.25)),
    "explode": lambda: layer((noise(0.5, 2, 13, 1.6, 0.1), 0.9), (tone(90, 0.45, "sine", f1=35), 0.9)),
    "win": lambda: arpeggio([n("C5"), n("E5"), n("G5"), n("C6"), n("G5"), n("C6"), n("E6")], 0.13, tail=0.9),
    "lose": lambda: arpeggio([n("E5"), n("C5"), n("A4"), n("E4"), n("A3")], 0.22, "pluck", tail=0.9),
    "ui_move": lambda: tone(880, 0.06, "pluck"),
    "ui_ok": lambda: arpeggio([n("E5"), n("B5")], 0.06),
    "pause": lambda: arpeggio([n("B5"), n("E5")], 0.07),
}


if __name__ == "__main__":
    for name, fn in SFX.items():
        save("sfx_" + name, fn())
    save("music_main", make_main(), 0.8)
    save("music_final", make_final(), 0.8)

#!/usr/bin/env python3
"""地獄難度的背景音樂候選，輸出到 music_preview/ 試聽。

執行：python3 tools/hell_options.py
選好之後把那首搬進 gen_audio.py（make_hell）。
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gen_audio as g  # noqa: E402
import final_options as fo  # noqa: E402

g.OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "music_preview")
RATE = g.RATE
n = g.n
freq = g.freq


def at(t):
    return int(t * RATE)


def blank(sec):
    return [0.0] * int(sec * RATE)


def drone(note, length, vol=1.0):
    """低沉的嗡嗡聲：兩個稍微走音的正弦，慢慢起伏"""
    out = []
    f1, f2 = freq(note), freq(note) * 1.004
    for i in range(int(length * RATE)):
        t = i / RATE
        a = min(1.0, t / 0.6) * min(1.0, (length - t) / 0.6) * (0.8 + 0.2 * math.sin(t * 1.3))
        out.append((math.sin(2 * math.pi * f1 * t) + math.sin(2 * math.pi * f2 * t)) * 0.5 * a * vol)
    return out


def toll(note, length=2.5):
    """喪鐘：低音鐘，泛音不和諧，拖很長"""
    return g.partials([freq(note), freq(note) * 2.4, freq(note) * 3.9, freq(note) * 5.4], length, 0.9,
                      [1.0, 0.5, 0.3, 0.15])


def tom(f0=90.0, length=0.35):
    """太鼓：低音正弦往下掉，加一點悶的雜訊"""
    return g.layer((g.tone(f0, length, "sine", f1=f0 * 0.55), 1.0), (g.noise(length * 0.4, 2, 33, 2.0, 0.08), 0.3))


# ---------- H1 暗黑 Lo-fi（之前決戰候選 F2：低沉低音、重鼓、和弦一拍一拍抽） ----------
def h1():
    return fo.f2()


# ---------- H2 地獄低吟（66 BPM，低音嗡嗡聲、喪鐘、慢而重的鼓、半音下行的旋律） ----------
def h2():
    bpm = 66
    beat = 60 / bpm
    bars = 12
    buf = blank(bars * 4 * beat)
    lead = blank(bars * 4 * beat)
    roots = [n("D2"), n("D2"), n("C#2"), n("C2")]
    mel = [  # 很少的音，半音往下滑
        [("D5", 0, 2), ("C#5", 2, 2)],
        [("C5", 0, 3)],
        [("A#4", 0, 2), ("A4", 2, 2)],
        [("G#4", 0, 4)],
    ]
    for bar in range(bars):
        s = bar * 4 * beat
        r = roots[bar % 4]
        g.mix_wrap(buf, at(s), drone(r, 4 * beat), 0.35)
        g.mix_wrap(buf, at(s), g.pad([r + 12, r + 15, r + 18], 4 * beat), 0.2)   # 減和弦，很不安
        g.mix_wrap(buf, at(s), tom(70.0, 0.5), 0.6)
        g.mix_wrap(buf, at(s + 2.5 * beat), tom(60.0, 0.5), 0.45)
        if bar % 2 == 0:
            g.mix_wrap(buf, at(s), toll(r + 24), 0.22)
        if bar >= 2:
            for name, st, ln in mel[bar % 4]:
                g.mix_wrap(lead, at(s + st * beat), g.tone(freq(n(name)), beat * (ln + 0.5), "bell"), 0.2)
    lead = g.echo(lead, beat * 0.75, 0.4, 0.4)
    return [a + b for a, b in zip(buf, lead)]


# ---------- H3 鬼祭太鼓（104 BPM，東方小調五聲音階的笛子、太鼓節奏） ----------
def h3():
    bpm = 104
    beat = 60 / bpm
    eighth = beat / 2
    bars = 16
    buf = blank(bars * 4 * beat)
    lead = blank(bars * 4 * beat)
    # 太鼓節奏（8 分音符格子，1 = 打）
    drum = [1, 0, 0, 1, 1, 0, 1, 0]
    # E 小調五聲：E G A B D
    mel = [
        [("E5", 0, 1.5), ("G5", 1.5, 0.5), ("A5", 2, 2)],
        [("B5", 0, 1), ("A5", 1, 1), ("G5", 2, 1), ("E5", 3, 1)],
        [("D5", 0, 1.5), ("E5", 1.5, 0.5), ("G5", 2, 2)],
        [("E5", 0, 3)],
    ]
    for bar in range(bars):
        s = bar * 4 * beat
        g.mix_wrap(buf, at(s), drone(n("E2"), 4 * beat), 0.28)
        for i, hit in enumerate(drum):
            if hit:
                big = i in (0, 4)
                g.mix_wrap(buf, at(s + i * eighth), tom(95.0 if big else 140.0, 0.3), 0.6 if big else 0.35)
        # 撥弦（像三味線）：E、B 交替
        for i in range(8):
            note = n("E4") if i % 2 == 0 else n("B3")
            g.mix_wrap(buf, at(s + i * eighth), g.tone(freq(note), eighth * 1.5, "pluck"), 0.12)
        if bar >= 4:
            for name, st, ln in mel[bar % 4]:
                g.mix_wrap(lead, at(s + st * beat), fo.g.tone(freq(n(name)), beat * ln, "sine", vib=0.008, attack=0.04,
                                                             release=min(0.2, beat * ln * 0.4)), 0.22)
    lead = g.echo(lead, beat * 0.75, 0.3, 0.3)
    return [a + b for a, b in zip(buf, lead)]


# ---------- H4 心跳（90 BPM，心跳般的雙重低鼓、三全音低音、詭異的高音鐘） ----------
def h4():
    bpm = 90
    beat = 60 / bpm
    bars = 16
    buf = blank(bars * 4 * beat)
    lead = blank(bars * 4 * beat)
    for bar in range(bars):
        s = bar * 4 * beat
        # 心跳：咚-咚 ……咚-咚
        for b in (0, 2):
            g.mix_wrap(buf, at(s + b * beat), tom(60.0, 0.25), 0.7)
            g.mix_wrap(buf, at(s + b * beat + beat * 0.28), tom(52.0, 0.25), 0.5)
        root = n("A1") if bar % 4 < 2 else n("D#2")   # A 和 D#：三全音，最不安的音程
        g.mix_wrap(buf, at(s), g.tone(freq(root), beat * 3.5, "tri", attack=0.05, release=0.4), 0.35)
        g.mix_wrap(buf, at(s), g.pad([root + 24, root + 27, root + 30], 4 * beat), 0.14)
        # 高音鐘：偶爾敲一下，走音一點點
        if bar >= 2:
            notes = [n("A5"), n("D#6"), n("C6"), n("F#5")]
            g.mix_wrap(lead, at(s + 1.5 * beat), g.tone(freq(notes[bar % 4]) * 1.01, beat * 2, "bell"), 0.16)
            if bar % 2:
                g.mix_wrap(lead, at(s + 3.25 * beat), g.tone(freq(notes[(bar + 1) % 4]), beat, "bell"), 0.12)
    lead = g.echo(lead, beat * 0.5, 0.45, 0.45)
    return [a + b for a, b in zip(buf, lead)]


if __name__ == "__main__" and len(sys.argv) == 1:
    for name, fn in [("H1_暗黑Lofi", h1), ("H2_地獄低吟", h2), ("H3_鬼祭太鼓", h3), ("H4_心跳", h4)]:
        g.save("地獄_" + name, fn(), 0.8, rms=0.13)


# ---------- H2 的變化版：比較輕、比較快 ----------
def h2_var(bpm, drone_vol, tom_vol, toll_on, brush=False, arp=False, busy_mel=False):
    beat = 60 / bpm
    eighth = beat / 2
    bars = 16
    buf = blank(bars * 4 * beat)
    lead = blank(bars * 4 * beat)
    roots = [n("D2"), n("D2"), n("C#2"), n("C2")]
    mel = [
        [("D5", 0, 2), ("C#5", 2, 2)],
        [("C5", 0, 3)],
        [("A#4", 0, 2), ("A4", 2, 2)],
        [("G#4", 0, 4)],
    ]
    mel_busy = [
        [("D5", 0, 1), ("F5", 1, 1), ("D5", 2, 1), ("C#5", 3, 1)],
        [("C5", 0, 1.5), ("D5", 1.5, 0.5), ("C5", 2, 2)],
        [("A#4", 0, 1), ("C5", 1, 1), ("A#4", 2, 1), ("A4", 3, 1)],
        [("G#4", 0, 2), ("A4", 2, 2)],
    ]
    for bar in range(bars):
        s = bar * 4 * beat
        r = roots[bar % 4]
        g.mix_wrap(buf, at(s), drone(r, 4 * beat), drone_vol)
        g.mix_wrap(buf, at(s), g.pad([r + 12, r + 15, r + 18], 4 * beat), 0.2)
        g.mix_wrap(buf, at(s), tom(70.0, 0.4), tom_vol)
        g.mix_wrap(buf, at(s + 2.5 * beat), tom(62.0, 0.4), tom_vol * 0.75)
        if brush:
            for b in (1, 3):
                g.mix_wrap(buf, at(s + b * beat), fo.g.noise(0.16, 1, 21, 2.0, 0.12), 0.16)
            for b in range(8):
                g.mix_wrap(buf, at(s + b * eighth), g.noise(0.03, 1, 5, 2.0, 0.35), 0.03)
        if arp:
            tones = [r + 24, r + 27, r + 30, r + 27]
            for i in range(8):
                g.mix_wrap(buf, at(s + i * eighth), g.tone(freq(tones[i % 4]), eighth * 2, "pluck"), 0.08)
        if toll_on and bar % 4 == 0:
            g.mix_wrap(buf, at(s), toll(r + 24), 0.15)
        if bar >= 2:
            for name, st, ln in (mel_busy if busy_mel else mel)[bar % 4]:
                g.mix_wrap(lead, at(s + st * beat), g.tone(freq(n(name)), beat * (ln + 0.5), "bell"), 0.2)
    lead = g.echo(lead, beat * 0.75, 0.35, 0.35)
    return [a + b for a, b in zip(buf, lead)]


def v1():   # 76 BPM，嗡嗡聲和鼓都輕一點，喪鐘少一點
    return h2_var(76, 0.2, 0.42, True)


def v2():   # 80 BPM，加上輕輕的刷子鼓和沙鈴（往 Lo-fi 靠一點）
    return h2_var(80, 0.18, 0.38, True, brush=True)


def v3():   # 80 BPM，加一點撥弦分解和弦，比較有流動感，不要喪鐘
    return h2_var(80, 0.15, 0.4, False, arp=True)


def v4():   # 86 BPM，旋律變比較密，刷子鼓
    return h2_var(86, 0.16, 0.38, True, brush=True, busy_mel=True)


if __name__ == "__main__" and len(sys.argv) > 1 and sys.argv[1] == "var":
    for name, fn in [("V1_76輕", v1), ("V2_80刷子鼓", v2), ("V3_80撥弦", v3), ("V4_86旋律密", v4)]:
        g.save("地獄低吟_" + name, fn(), 0.8, rms=0.12)

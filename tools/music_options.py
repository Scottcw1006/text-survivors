#!/usr/bin/env python3
"""產生幾首候選背景音樂讓人試聽，輸出到 music_preview/。

執行：python3 tools/music_options.py
選好之後，把那首的寫法搬進 gen_audio.py 的 make_main / make_final。
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gen_audio as g  # noqa: E402

g.OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "music_preview")
RATE = g.RATE
n = g.n
freq = g.freq


def blank(seconds):
    return [0.0] * int(seconds * RATE)


def at(t):
    return int(t * RATE)


def brush(length=0.18):
    """刷子小鼓：很悶的雜訊，輕輕的"""
    return g.noise(length, 1, 21, 2.0, 0.12)


def flute(note, length):
    return g.tone(freq(note), length, "sine", vib=0.007, attack=0.06, release=min(0.25, length * 0.4))


# ---------- A：悠閒撥弦（C 大調，92 BPM） ----------
def option_a():
    return g.make_main()


# ---------- B：鋼琴圓舞曲（F 大調，3/4 拍，84 BPM，沒有鼓） ----------
def option_b():
    bpm = 84
    beat = 60 / bpm
    chords = [[n("F3"), n("A3"), n("C4")], [n("D3"), n("F3"), n("A3")],
              [n("Bb2"), n("D3"), n("F3")], [n("C3"), n("E3"), n("G3")]]
    # 每小節三拍，每拍一個音（None = 延長上一個音）
    melody = [
        ["A5", None, "C6"], ["F5", None, None], ["D5", "F5", "A5"], ["G5", None, None],
        ["F5", "G5", "A5"], ["D5", None, None], ["E5", "G5", "C6"], ["C6", None, None],
    ]
    bars = 16
    buf = blank(bars * 3 * beat)
    for bar in range(bars):
        ch = chords[(bar // 2) % len(chords)]
        s = bar * 3 * beat
        # 左手：第一拍低音，二三拍和弦
        g.mix_wrap(buf, at(s), g.tone(freq(ch[0] - 12), beat * 2.5, "pluck"), 0.45)
        for b in (1, 2):
            for k in ch[1:]:
                g.mix_wrap(buf, at(s + b * beat), g.tone(freq(k), beat * 1.2, "pluck"), 0.14)
        line = melody[bar % len(melody)]
        for i, name in enumerate(line):
            if name is None:
                continue
            length = 1
            while i + length < 3 and line[i + length] is None:
                length += 1
            g.mix_wrap(buf, at(s + i * beat), g.tone(freq(n(name)), beat * (length + 0.8), "bell"), 0.28)
    return g.echo(buf, beat * 0.75, 0.25, 0.25)


# ---------- C：Lo-fi（Dm7 - G7 - Cmaj7 - Am7，78 BPM，搖擺節奏，輕鼓） ----------
def option_c():
    bpm = 78
    beat = 60 / bpm
    swing = beat * 0.62   # 搖擺：第二個 8 分音符晚一點
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
    bars = 16
    buf = blank(bars * 4 * beat)
    lead = blank(bars * 4 * beat)
    for bar in range(bars):
        ch = chords[bar % len(chords)]
        s = bar * 4 * beat
        g.mix_wrap(buf, at(s), g.pad([k + 12 for k in ch], 4 * beat), 0.3)
        # 低音：一拍、三拍半
        g.mix_wrap(buf, at(s), g.tone(freq(ch[0] - 12), beat * 1.5, "pluck"), 0.5)
        g.mix_wrap(buf, at(s + 2.5 * beat), g.tone(freq(ch[0] - 12 + 7), beat, "pluck"), 0.35)
        # 鼓：大鼓 1、3（和第 3 拍的搖擺後半）、刷子小鼓 2、4、很輕的沙鈴
        for b in (0, 2):
            g.mix_wrap(buf, at(s + b * beat), g.soft_kick(), 0.4)
        g.mix_wrap(buf, at(s + 2 * beat + swing), g.soft_kick(), 0.2)
        for b in (1, 3):
            g.mix_wrap(buf, at(s + b * beat), brush(), 0.18)
        for b in range(4):
            for off in (0, swing):
                g.mix_wrap(buf, at(s + b * beat + off), g.noise(0.03, 1, 5, 2.0, 0.35), 0.035)
        for name, start, length in melody[bar % len(melody)]:
            g.mix_wrap(lead, at(s + start * beat), g.tone(freq(n(name)), beat * (length + 0.5), "bell"), 0.22)
    lead = g.echo(lead, beat * 0.75, 0.3, 0.3)
    return [a + b for a, b in zip(buf, lead)]


# ---------- D：東方五聲（D 宮調五聲音階，88 BPM，笛子＋撥弦，沒有鼓） ----------
def option_d():
    bpm = 88
    beat = 60 / bpm
    eighth = beat / 2
    # D 五聲：D E F# A B
    bass = [n("D3"), n("D3"), n("B2"), n("A2"), n("G2"), n("A2"), n("D3"), n("A2")]
    flute_line = [
        [("A5", 0, 2), ("B5", 2, 1), ("A5", 3, 1)],
        [("F#5", 0, 3)],
        [("E5", 0, 1), ("F#5", 1, 1), ("A5", 2, 2)],
        [("B5", 0, 3)],
        [("D6", 0, 2), ("B5", 2, 1), ("A5", 3, 1)],
        [("F#5", 0, 1.5), ("E5", 1.5, 1.5)],
        [("D5", 0, 1), ("E5", 1, 1), ("F#5", 2, 1), ("E5", 3, 1)],
        [("D5", 0, 3)],
    ]
    pent = [n("D4"), n("E4"), n("F#4"), n("A4"), n("B4"), n("D5")]
    bars = 16
    buf = blank(bars * 4 * beat)
    lead = blank(bars * 4 * beat)
    for bar in range(bars):
        s = bar * 4 * beat
        root = bass[bar % len(bass)]
        g.mix_wrap(buf, at(s), g.tone(freq(root - 12), beat * 3, "pluck"), 0.45)
        g.mix_wrap(buf, at(s), g.pad([root + 12, root + 19], 4 * beat), 0.15)
        # 撥弦（像古箏）：在五聲音階上上下下
        idx = [0, 2, 4, 5, 4, 2, 3, 1] if bar % 2 == 0 else [1, 3, 5, 4, 2, 4, 3, 2]
        for i, k in enumerate(idx):
            g.mix_wrap(buf, at(s + i * eighth), g.tone(freq(pent[k]), eighth * 3, "pluck"), 0.13)
        for name, start, length in flute_line[bar % len(flute_line)]:
            g.mix_wrap(lead, at(s + start * beat), flute(n(name), beat * length), 0.22)
    lead = g.echo(lead, beat * 0.75, 0.3, 0.3)
    return [a + b for a, b in zip(buf, lead)]


if __name__ == "__main__":
    for name, fn in [("A_悠閒撥弦", option_a), ("B_鋼琴圓舞曲", option_b),
                     ("C_Lofi", option_c), ("D_東方五聲", option_d)]:
        g.save("option_" + name, fn(), 0.8)

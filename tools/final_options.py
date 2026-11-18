#!/usr/bin/env python3
"""決戰音樂候選（以 Lo-fi 為基底），輸出到 music_preview/。

執行：python3 tools/final_options.py
選好之後把那首搬進 gen_audio.py 的 make_final。
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gen_audio as g  # noqa: E402

g.OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "music_preview")
RATE = g.RATE
n = g.n
freq = g.freq


def at(t):
    return int(t * RATE)


def blank(sec):
    return [0.0] * int(sec * RATE)


def snare_soft(length=0.2):
    """比刷子實一點的小鼓（還是悶悶的）"""
    return g.layer((g.noise(length, 1, 31, 1.8, 0.25), 0.8), (g.tone(190, 0.08, "sine", f1=150), 0.4))


def sub(note, length):
    """很低的正弦低音，有點「嗡」的壓迫感"""
    return g.tone(freq(note), length, "sine", attack=0.01, release=0.08)


def shaker(vol_seed=5):
    return g.noise(0.03, 1, vol_seed, 2.0, 0.35)


# ---------- F1：小調 Lo-fi（現在遊戲裡的版本，92 BPM） ----------
def f1():
    return g.make_final()


# ---------- F2：暗黑 Lo-fi 嘻哈（82 BPM，重鼓、低沉低音、和弦一拍一拍「抽」） ----------
def f2():
    bpm = 82
    beat = 60 / bpm
    swing = beat * 0.6
    chords = [[n("C3"), n("Eb3"), n("G3"), n("Bb3"), n("D4")],      # Cm9
              [n("Ab2"), n("C3"), n("Eb3"), n("G3")],                # Abmaj7
              [n("F2"), n("Ab3"), n("C4"), n("Eb4")],                # Fm7
              [n("G2"), n("F3"), n("B3"), n("D4")]]                  # G7
    mel = [
        [("G5", 0, 1.5), ("Eb5", 2, 1), ("D5", 3, 1)],
        [("C5", 0, 3)],
        [("Ab5", 0, 1), ("G5", 1, 1), ("Eb5", 2, 2)],
        [("D5", 0, 1.5), ("B4", 2, 2)],
    ]
    bars = 16
    buf = blank(bars * 4 * beat)
    lead = blank(bars * 4 * beat)
    for bar in range(bars):
        ch = chords[bar % 4]
        s = bar * 4 * beat
        # 和弦每拍重新彈一次，拍子中間被「壓」下去（像 sidechain）
        for b in range(4):
            g.mix_wrap(buf, at(s + b * beat), g.pad([k + 12 for k in ch[1:]], beat * 0.95), 0.32)
        g.mix_wrap(buf, at(s), sub(ch[0] - 12, beat * 1.6), 0.55)
        g.mix_wrap(buf, at(s + 2.5 * beat), sub(ch[0] - 12, beat * 1.2), 0.45)
        for t in (0, 1.5 * beat, 2.5 * beat):
            g.mix_wrap(buf, at(s + t), g.soft_kick(0.3), 0.55)
        for b in (1, 3):
            g.mix_wrap(buf, at(s + b * beat), snare_soft(), 0.3)
        for b in range(4):
            for off in (0, swing):
                g.mix_wrap(buf, at(s + b * beat + off), shaker(), 0.04)
        for name, st, ln in mel[bar % 4]:
            g.mix_wrap(lead, at(s + st * beat), g.tone(freq(n(name)), beat * (ln + 0.6), "bell"), 0.22)
    lead = g.echo(lead, beat * 0.75, 0.35, 0.35)
    return [a + b for a, b in zip(buf, lead)]


# ---------- F3：爵士追逐（112 BPM，走路低音、搖擺的碎拍、小調 ii-V） ----------
def f3():
    bpm = 112
    beat = 60 / bpm
    swing = beat * 0.64
    chords = [[n("B2"), n("D3"), n("F3"), n("A3")],    # Bm7b5
              [n("E2"), n("D3"), n("G#3"), n("C4")],   # E7b9 感
              [n("A2"), n("C3"), n("E3"), n("G3")],    # Am7
              [n("A2"), n("C3"), n("E3"), n("G3")]]
    walk = [  # 每小節 4 個走路低音
        ["B1", "D2", "F2", "A2"], ["E2", "G#2", "B2", "D3"],
        ["A1", "C2", "E2", "G2"], ["A2", "G2", "E2", "C2"],
    ]
    mel = [
        [("D5", 0, 0.5), ("F5", 0.5, 0.5), ("A5", 1, 1), ("G#5", 2, 0.5), ("F5", 2.5, 1.5)],
        [("E5", 0, 1), ("D5", 1, 0.5), ("C5", 1.5, 0.5), ("B4", 2, 2)],
        [("C5", 0, 0.5), ("E5", 0.5, 0.5), ("A5", 1, 1.5), ("G5", 2.5, 0.5), ("E5", 3, 1)],
        [("A4", 0, 3)],
    ]
    bars = 16
    buf = blank(bars * 4 * beat)
    lead = blank(bars * 4 * beat)
    for bar in range(bars):
        ch = chords[bar % 4]
        s = bar * 4 * beat
        # 和弦在第 2 拍後半「切」進來（爵士的切分）
        g.mix_wrap(buf, at(s + beat + swing), g.pad([k + 12 for k in ch], beat * 1.2), 0.3)
        g.mix_wrap(buf, at(s + 3 * beat + swing), g.pad([k + 12 for k in ch], beat * 0.8), 0.22)
        for b, name in enumerate(walk[bar % 4]):
            g.mix_wrap(buf, at(s + b * beat), g.tone(freq(n(name)), beat * 0.95, "pluck"), 0.5)
        # 鼓：碎拍（ride 鈸感用短的高頻雜訊）、輕大鼓、刷子
        for b in range(4):
            g.mix_wrap(buf, at(s + b * beat), g.noise(0.08, 1, 41, 2.5, 0.6), 0.05)
            if b in (1, 3):
                g.mix_wrap(buf, at(s + b * beat + swing), g.noise(0.05, 1, 43, 2.5, 0.6), 0.035)
        g.mix_wrap(buf, at(s), g.soft_kick(), 0.35)
        g.mix_wrap(buf, at(s + 2 * beat + swing), g.soft_kick(), 0.25)
        for b in (1, 3):
            g.mix_wrap(buf, at(s + b * beat), g.noise(0.16, 1, 21, 2.0, 0.12), 0.22)
        for name, st, ln in mel[bar % 4]:
            st2 = int(st) * beat + (swing if st % 1 else 0)
            g.mix_wrap(lead, at(s + st2), g.tone(freq(n(name)), beat * (ln + 0.4), "bell"), 0.2)
    lead = g.echo(lead, beat * 0.5, 0.25, 0.25)
    return [a + b for a, b in zip(buf, lead)]


# ---------- F4：倒數緊張（100 BPM，滴答的撥弦 16 分音符、四拍大鼓、弗里吉亞調式） ----------
def f4():
    bpm = 100
    beat = 60 / bpm
    six = beat / 4
    # A 弗里吉亞（A Bb C D E F G）：Am - Bb - Gm - Am
    chords = [[n("A2"), n("C3"), n("E3"), n("G3")], [n("Bb2"), n("D3"), n("F3"), n("A3")],
              [n("G2"), n("Bb2"), n("D3"), n("F3")], [n("A2"), n("C3"), n("E3"), n("G3")]]
    tick = [0, 2, 1, 3, 2, 1, 3, 2]   # 16 分音符的撥弦順序（和弦音）
    mel = [
        [("E5", 0, 2), ("F5", 2, 2)],
        [("D5", 0, 2), ("F5", 2, 1), ("A5", 3, 1)],
        [("G5", 0, 2), ("F5", 2, 1), ("D5", 3, 1)],
        [("E5", 0, 4)],
    ]
    bars = 16
    buf = blank(bars * 4 * beat)
    lead = blank(bars * 4 * beat)
    for bar in range(bars):
        ch = chords[bar % 4]
        s = bar * 4 * beat
        g.mix_wrap(buf, at(s), g.pad([k + 12 for k in ch], 4 * beat), 0.24)
        for i in range(16):
            k = ch[tick[i % 8]] + 24
            vol = 0.1 if i % 4 == 0 else 0.06
            g.mix_wrap(buf, at(s + i * six), g.tone(freq(k), six * 2, "pluck"), vol)
        for b in range(4):
            g.mix_wrap(buf, at(s + b * beat), g.soft_kick(), 0.4)
            g.mix_wrap(buf, at(s + b * beat + beat / 2), shaker(7), 0.05)
        for b in (1, 3):
            g.mix_wrap(buf, at(s + b * beat), g.noise(0.16, 1, 21, 2.0, 0.12), 0.2)
        g.mix_wrap(buf, at(s), sub(ch[0] - 12, beat * 2), 0.5)
        g.mix_wrap(buf, at(s + 2 * beat), sub(ch[0] - 12, beat * 2), 0.4)
        if bar >= 4:   # 前四小節只有滴答聲，之後旋律才進來（越來越緊張）
            for name, st, ln in mel[bar % 4]:
                g.mix_wrap(lead, at(s + st * beat), g.tone(freq(n(name)), beat * (ln + 0.5), "bell"), 0.22)
    lead = g.echo(lead, beat * 0.75, 0.3, 0.3)
    return [a + b for a, b in zip(buf, lead)]


if __name__ == "__main__":
    for name, fn in [("F1_小調Lofi", f1), ("F2_暗黑Lofi嘻哈", f2), ("F3_爵士追逐", f3), ("F4_倒數緊張", f4)]:
        g.save("決戰_" + name, fn(), 0.8)

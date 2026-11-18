#!/usr/bin/env python3
"""音效候選：選單音效（更亮）、刀的揮砍（金屬感），輸出到 music_preview/ 試聽。

執行：python3 tools/sfx_options.py
選好之後把那個寫法搬進 gen_audio.py 的 SFX。
"""
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gen_audio as g  # noqa: E402

g.OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "music_preview")
RATE = g.RATE
n = g.n
freq = g.freq


def at(t):
    return int(t * RATE)


def partials(fs, length, decay, amps=None):
    """幾個不成倍數的泛音疊在一起 = 金屬聲；decay 越小消失越快"""
    amps = amps or [1.0] * len(fs)
    out = []
    for i in range(int(length * RATE)):
        t = i / RATE
        s = sum(a * math.sin(2 * math.pi * f * t) * math.exp(-t / (decay * (1 + 0.3 * k)))
                for k, (f, a) in enumerate(zip(fs, amps)))
        out.append(s * min(1.0, t / 0.001) / len(fs))
    return out


def hp_noise(length, seed, sweep_from=0.6, sweep_to=0.15, decay=1.5):
    """高頻的「唰」：雜訊減掉它的低頻部分，濾波器從亮掃到暗"""
    rng = random.Random(seed)
    out = []
    lp = 0.0
    total = int(length * RATE)
    for i in range(total):
        k = i / total
        x = rng.uniform(-1, 1)
        a = sweep_from + (sweep_to - sweep_from) * k
        lp += (x - lp) * a
        out.append((x - lp) * (1 - k) ** decay)
    return out


def sequence(sounds, gap):
    """把幾個聲音隔一段時間排在一起（試聽用）"""
    buf = [0.0] * at(gap * len(sounds) + 0.6)
    for i, s in enumerate(sounds):
        g.mix_into(buf, at(i * gap), s)
    return buf


# ---------- 選單音效（移動 ×3、確定 ×1） ----------

def ui_bell():        # U1 清脆鈴：高音鐘聲
    move = g.tone(freq(n("E7")), 0.12, "bell")
    ok = g.arpeggio([n("B6"), n("E7")], 0.05)
    return move, ok


def ui_xylo():        # U2 木琴：高音撥弦＋八度
    move = g.layer((g.tone(freq(n("C7")), 0.08, "pluck"), 0.8), (g.tone(freq(n("C8")), 0.05, "pluck"), 0.3))
    ok = g.arpeggio([n("G6"), n("C7"), n("G7")], 0.035, "pluck")
    return move, ok


def ui_glass():       # U3 玻璃叮：很高的正弦，帶一點閃爍
    move = partials([2093, 4186, 6280], 0.1, 0.03, [1.0, 0.5, 0.2])
    ok = g.layer((partials([1568, 3136], 0.18, 0.05), 0.8),
                 ([0.0] * at(0.05) + partials([2349, 4698], 0.18, 0.05), 0.8))
    return move, ok


def ui_chip():        # U4 8-bit 亮：很短的方波，最「嗶」
    move = g.tone(1760, 0.035, "square", 0.25, release=0.01)
    ok = g.layer((g.tone(1320, 0.05, "square", 0.25, release=0.01), 0.6),
                 ([0.0] * at(0.05) + g.tone(1976, 0.07, "square", 0.25, release=0.02), 0.6))
    return [x * 0.5 for x in move], [x * 0.5 for x in ok]


# ---------- 刀的揮砍（金屬感） ----------

def slash_ring():     # S1 劍鳴：唰一聲之後留一點「嗡～」的金屬餘音
    swish = hp_noise(0.12, 5, 0.7, 0.2)
    ring = partials([1870, 2960, 4410, 5830], 0.35, 0.09, [1.0, 0.7, 0.5, 0.3])
    return g.layer((swish, 0.7), (ring, 0.6))


def slash_scrape():   # S2 刀刃摩擦：亮的唰聲往下掃，像刀鋒劃過
    swish = hp_noise(0.16, 9, 0.9, 0.3, 1.0)
    edge = g.tone(3200, 0.12, "sine", f1=1800)
    return g.layer((swish, 0.9), (edge, 0.15))


def slash_clang():    # S3 鏘：短促有力的金屬撞擊聲
    hit = partials([1250, 2130, 3370, 4850, 6020], 0.18, 0.04, [1.0, 0.8, 0.6, 0.4, 0.3])
    swish = hp_noise(0.06, 3, 0.8, 0.4)
    return g.layer((hit, 1.0), (swish, 0.5))


def slash_light():    # S4 輕斬＋叮：柔和的唰，尾巴一個小小的高音叮
    swish = hp_noise(0.12, 7, 0.4, 0.12)
    ting = [0.0] * at(0.04) + partials([3520, 5280], 0.15, 0.04)
    return g.layer((swish, 0.8), (ting, 0.35))


if __name__ == "__main__":
    for name, fn in [("U1_清脆鈴", ui_bell), ("U2_木琴", ui_xylo), ("U3_玻璃叮", ui_glass), ("U4_8bit亮", ui_chip)]:
        move, ok = fn()
        g.save("選單_" + name, sequence([move, move, move, ok], 0.3), 0.8)
    for name, fn in [("S1_劍鳴", slash_ring), ("S2_刀刃摩擦", slash_scrape), ("S3_鏘", slash_clang), ("S4_輕斬叮", slash_light)]:
        s = fn()
        g.save("揮砍_" + name, sequence([s, s, s], 0.6), 0.8)

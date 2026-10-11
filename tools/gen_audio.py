# -*- coding: utf-8 -*-
"""P7 程序化音频生成：用纯 Python 合成 BGM/音效 WAV（零版权风险、可复现）。
运行：python tools/gen_audio.py   （输出到 assets/audio/）
P7f 重制版：
- BGM 改为「科幻 + 欢快」风格，16 秒 A+B 两段结构，降低重复感：
  菜单=C大调空灵闪光 / 战斗=Em-C-G-D 明亮推进 / Boss=Dm-Bb-F-C 英气压迫（协和，不阴森）
- 音效更清脆：高通噪声+高频滑音（打击短促明亮、暴击金属"锵"）
22050Hz 16bit 单声道。"""
import math
import os
import random
import struct
import wave

SR = 22050
BGM_SECS = 16.0
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "audio")


def write_wav(name, samples):
    path = os.path.join(OUT, name + ".wav")
    peak = max(1e-9, max(abs(s) for s in samples))
    data = b"".join(struct.pack("<h", int(max(-1.0, min(1.0, s / peak * 0.85)) * 32767)) for s in samples)
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data)
    print("  wrote %s (%.1fs)" % (name, len(samples) / float(SR)))


def n(midi):
    """MIDI 音号 -> 频率"""
    return 440.0 * 2 ** ((midi - 69) / 12.0)


def env(i, nn, a=0.01, r=0.05):
    t = i / float(SR)
    dur = nn / float(SR)
    if t < a:
        return t / a
    if t > dur - r:
        return max(0.0, (dur - t) / r)
    return 1.0


def tone(freq, dur, kind="sine", vol=1.0, vibrato=0.0, attack=0.01, release=0.05):
    nn = int(dur * SR)
    out = []
    for i in range(nn):
        t = i / float(SR)
        f = freq * (1.0 + vibrato * math.sin(2 * math.pi * 5.5 * t))
        ph = 2 * math.pi * f * t
        if kind == "sine":
            v = math.sin(ph)
        elif kind == "tri":
            v = 2 / math.pi * math.asin(math.sin(ph))
        elif kind == "square":
            v = 0.55 if math.sin(ph) > 0 else -0.55
        elif kind == "saw":
            v = 2 * (f * t - math.floor(0.5 + f * t))
        else:
            v = 0.0
        tt = i / float(SR)
        dur2 = nn / float(SR)
        if tt < attack:
            e = tt / attack
        elif tt > dur2 - release:
            e = max(0.0, (dur2 - tt) / release)
        else:
            e = 1.0
        out.append(v * vol * e)
    return out


def sweep(f0, f1, dur, vol=1.0):
    """频率下滑音（鼓/“嗖”声）"""
    nn = int(dur * SR)
    out = []
    phase = 0.0
    for i in range(nn):
        frac = i / float(nn)
        f = f0 + (f1 - f0) * frac
        phase += 2 * math.pi * f / SR
        e = math.exp(-4.0 * frac)
        out.append(math.sin(phase) * vol * e)
    return out


def noise(dur, vol=1.0, decay=8.0, bright=0):
    """白噪声；bright>=1 时做差分高通，声音更‘沙/脆’而不闷"""
    nn = int(dur * SR)
    rnd = random.Random(42)
    x = [(rnd.random() * 2 - 1) * vol for _ in range(nn)]
    for _ in range(bright):
        y = list(x)
        for i in range(nn - 1, 0, -1):
            y[i] = (x[i] - x[i - 1]) * 0.8
        x = y
    return [x[i] * math.exp(-decay * i / float(SR)) for i in range(nn)]


class Timeline:
    """时间轴缓冲：把若干段样本叠加到指定起点"""

    def __init__(self, secs):
        self.buf = [0.0] * int(secs * SR)

    def add(self, start, samples, gain=1.0):
        s0 = int(start * SR)
        for i, v in enumerate(samples):
            j = s0 + i
            if 0 <= j < len(self.buf):
                self.buf[j] += v * gain
        return self

    def repeat(self, start, chunk, gap, times, gain=1.0):
        for k in range(times):
            self.add(start + k * gap, chunk, gain)


def pad_chord(freqs, dur, vol=0.25):
    nn = int(dur * SR)
    out = [0.0] * nn
    for f in freqs:
        note = tone(f, dur, "sine", vol, vibrato=0.004, attack=min(0.4, dur * 0.2), release=min(0.8, dur * 0.3))
        for i, v in enumerate(note):
            out[i] += v
    return out


# ---------------- BGM（科幻·欢快，16s A+B） ----------------

def bgm_menu():
    """空灵科幻菜单曲：C大调 add9 垫音 + 高频五声音阶闪光琶音 + 舒缓主旋律"""
    tl = Timeline(BGM_SECS)
    bar = BGM_SECS / 4.0
    # 垫音四小节：Cadd9 - Am7 - Fmaj7 - G
    chords = [[60, 64, 67, 74], [57, 60, 64, 69], [53, 57, 60, 65], [55, 59, 62, 67]]
    for k, ch in enumerate(chords):
        tl.add(k * bar, pad_chord([n(m) for m in ch], bar + 0.5, 0.16))
    # 闪光琶音：C 五声高八度，16 分音符质感（每 0.22s 一粒）
    sparkle = [84, 88, 91, 93, 88, 84, 91, 93, 88, 84, 93, 91, 84, 88, 91, 88,
               84, 88, 91, 93, 96, 91, 88, 84, 91, 88, 84, 88, 93, 91, 88, 84]
    for i, m in enumerate(sparkle):
        tl.add(0.5 * i % BGM_SECS if i < len(sparkle) // 2 else 0.5 * i, tone(n(m), 0.09, "sine", 0.09, attack=0.002, release=0.07))
    # 主旋律（A 段 8s 陈述，B 段高八度回应）
    mel_a = [(2.0, 76, 1.2), (3.4, 79, 0.9), (4.4, 84, 1.4), (6.0, 83, 1.8)]
    mel_b = [(10.0, 84, 1.2), (11.4, 88, 0.9), (12.4, 86, 1.0), (13.6, 83, 1.2), (14.8, 79, 1.1)]
    for t, m, d in mel_a + mel_b:
        tl.add(t, tone(n(m), d, "sine", 0.22, vibrato=0.006, attack=0.05, release=0.25))
    return tl.buf


def bgm_battle():
    """欢快推进战斗曲：Em-C-G-D（明亮小调），八度跳低音 + 方波琶音 + 鼓组 + 铜管感 lead"""
    tl = Timeline(BGM_SECS)
    bar = 2.0            # 120bpm，4 拍小节
    roots = [40, 36, 43, 38] * 2          # Em C G D ×2
    chord_tops = [[64, 67, 71], [60, 64, 67], [67, 71, 74], [62, 66, 69]] * 2
    # A 段(0~8s)与 B 段(8~16s) lead 不同
    lead_a = {0: [76, 79, 83], 1: [79, 76, 72], 2: [74, 79, 83], 3: [74, 78, 81]}
    lead_b = {4: [83, 81, 79], 5: [79, 76, 79], 6: [83, 79, 74], 7: [81, 79, 76]}
    kick = sweep(150, 42, 0.13, 0.6)
    hat = noise(0.04, 0.5, 80.0, bright=2)
    for b in range(8):
        t0 = b * bar
        r = roots[b]
        # 八度跳跃低音（8 分）
        for i in range(8):
            m = r + (12 if i % 2 == 1 else 0)
            tl.add(t0 + i * 0.25, tone(n(m), 0.16, "saw", 0.30, attack=0.004, release=0.06))
        # 琶音层（每小节 8 粒，亮 tri）
        ct = chord_tops[b]
        for i in range(8):
            tl.add(t0 + i * 0.25, tone(n(ct[i % 3] + 12), 0.12, "tri", 0.085, attack=0.002, release=0.06))
        # 鼓： kick 每拍，hat 反拍
        for i in range(4):
            tl.add(t0 + i * 0.5, kick)
            tl.add(t0 + i * 0.5 + 0.25, hat, 0.5)
        # lead 重音（ beats 0 和 2.5）
        ln = (lead_a if b < 4 else lead_b)[b if b < 4 else b]
        tl.add(t0, tone(n(ln[0]), 0.45, "square", 0.16, attack=0.01, release=0.15))
        tl.add(t0 + 1.25, tone(n(ln[1]), 0.3, "square", 0.14, attack=0.01, release=0.1))
        tl.add(t0 + 1.6, tone(n(ln[2]), 0.38, "square", 0.14, attack=0.01, release=0.15))
    return tl.buf


def bgm_boss():
    """Boss 英气压迫感（协和不阴森）：Dm-Bb-F-C，快速三音琶音 + 强脉动低音 + 军鼓感节奏"""
    tl = Timeline(BGM_SECS)
    bar = 16.0 / 9.0          # 135bpm，9 小节
    beats = bar / 4.0
    roots = [38, 34, 41, 36, 38, 34, 41, 36, 38]     # Dm Bb F C Dm Bb F C Dm
    chords = [[62, 65, 69], [58, 62, 65], [53, 57, 60], [60, 64, 67]]
    kick = sweep(160, 45, 0.14, 0.7)
    crack = noise(0.06, 0.7, 60.0, bright=2)
    for b in range(9):
        t0 = b * bar
        ch = chords[b % 4]
        r = roots[b]
        # 低音脉动（每拍双八分，方波更冲）
        for i in range(8):
            tl.add(t0 + i * beats / 2, tone(n(r + (12 if i % 4 >= 2 else 0)), 0.1, "square", 0.26, attack=0.003, release=0.04))
        # 快速琶音（每拍 3 粒三连感）
        for i in range(12):
            m = ch[i % 3] + (24 if (i // 3) % 2 == 1 else 12)
            tl.add(t0 + i * bar / 12.0, tone(n(m), 0.1, "tri", 0.08, attack=0.002, release=0.05))
        # 鼓：正拍大鼓 + 2/4 拍军鼓样脆响
        for i in range(4):
            tl.add(t0 + i * beats, kick)
            if i in (1, 3):
                tl.add(t0 + i * beats, crack, 0.6)
    # 每小节头的高音“号角”重音（Dm 段用 A/C 音，Bb 段用 D/F…保持协和）
    horns = [81, 77, 84, 79, 81, 77, 84, 79, 81]
    for b in range(9):
        tl.add(b * bar, tone(n(horns[b]), bar * 0.42, "saw", 0.10, vibrato=0.008, attack=0.06, release=0.3))
    return tl.buf


# ---------------- 音效（更清脆） ----------------

def build_sfx():
    out = {}
    # 打击：短促明亮的“啪”——高通噪声 + 高频下滑
    out["sfx_hit"] = Timeline(0.14).buf
    t = Timeline(0.14)
    t.add(0, noise(0.05, 0.9, 60.0, bright=2))
    t.add(0, sweep(1400, 500, 0.07, 0.45))
    out["sfx_hit"] = t.buf
    # 暴击：金属“锵”——高频下滑 + 亮噪声 + 1200Hz 铃
    t = Timeline(0.3)
    t.add(0, noise(0.18, 1.0, 18.0, bright=1))
    t.add(0, sweep(2200, 700, 0.22, 0.4))
    t.add(0.02, tone(1245, 0.22, "sine", 0.25, attack=0.002, release=0.18))
    t.add(0.02, tone(1867, 0.16, "sine", 0.12, attack=0.002, release=0.12))
    out["sfx_crit"] = t.buf
    # 治疗：上升五声音阶闪光（更亮）
    t = Timeline(0.5)
    for i, m in enumerate([72, 76, 79, 84]):
        t.add(i * 0.1, tone(n(m), 0.16, "sine", 0.35, attack=0.005, release=0.1))
    t.add(0.32, noise(0.08, 0.15, 40.0, bright=2))
    out["sfx_heal"] = t.buf
    # 胜利：三音上行 + 结尾和弦
    t = Timeline(1.4)
    for i, m in enumerate([64, 67, 72]):
        t.add(i * 0.16, tone(n(m), 0.16, "tri", 0.4, attack=0.005, release=0.08))
    for m in [72, 76, 79]:
        t.add(0.48, tone(n(m), 0.7, "tri", 0.3, attack=0.01, release=0.5))
    out["sfx_victory"] = t.buf
    # 失败：短促下行小三度（不拖沓）
    t = Timeline(1.0)
    t.add(0.0, tone(n(55), 0.3, "tri", 0.4, attack=0.01, release=0.15))
    t.add(0.28, tone(n(51), 0.3, "tri", 0.4, attack=0.01, release=0.15))
    t.add(0.56, tone(n(48), 0.4, "tri", 0.4, attack=0.01, release=0.3))
    out["sfx_defeat"] = t.buf
    # 目标选择轻音（UI 顺手加一点反馈）
    t = Timeline(0.1)
    t.add(0, sweep(700, 1100, 0.06, 0.25))
    out["sfx_select"] = t.buf
    return out


def main():
    os.makedirs(OUT, exist_ok=True)
    print("生成 BGM（科幻欢快·16s）...")
    for name, fn in [("bgm_menu", bgm_menu), ("bgm_battle", bgm_battle), ("bgm_boss", bgm_boss)]:
        s = fn()
        s = s + [0.0] * (int(BGM_SECS * SR) - len(s))   # 对齐 16 秒循环点
        write_wav(name, s)
    print("生成音效（清脆版）...")
    for name, s in build_sfx().items():
        write_wav(name, s)
    print("完成。")


if __name__ == "__main__":
    main()

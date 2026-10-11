# -*- coding: utf-8 -*-
"""P7 程序化音频生成：用纯 Python 合成 BGM/音效 WAV（零版权风险、可复现）。
运行：python tools/gen_audio.py   （输出到 assets/audio/）
设计：BGM 为 8 秒可循环段落（菜单=平静垫音 / 战斗=驱动脉冲 / Boss=低沉压迫）；
音效为短促波形（打击/暴击/治疗/胜利/失败）。22050Hz 16bit 单声道。"""
import math
import os
import struct
import wave

SR = 22050
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


def env(i, n, a=0.01, r=0.05):
    """简单攻击-释放包络"""
    t = i / float(SR)
    dur = n / float(SR)
    if t < a:
        return t / a
    if t > dur - r:
        return max(0.0, (dur - t) / r)
    return 1.0


def tone(freq, dur, kind="sine", vol=1.0, vibrato=0.0):
    n = int(dur * SR)
    out = []
    for i in range(n):
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
        out.append(v * vol * env(i, n))
    return out


def noise(dur, vol=1.0, decay=8.0):
    n = int(dur * SR)
    import random
    random.seed(42)
    return [(random.random() * 2 - 1) * vol * math.exp(-decay * i / float(SR)) for i in range(n)]


def mix(*tracks):
    n = max(len(t) for t in tracks)
    out = [0.0] * n
    for t in tracks:
        for i, v in enumerate(t):
            out[i] += v
    return out


def pad_chord(freqs, dur, vol=0.25):
    """柔和垫音：多正弦叠加 + 慢颤"""
    return mix(*[tone(f, dur, "sine", vol, vibrato=0.004) for f in freqs])


def seq_note(freq, start, dur, kind="tri", vol=0.5):
    """在时间轴上放置一个音"""
    n = int(dur * SR)
    s0 = int(start * SR)
    track = [0.0] * (s0 + n)
    note = tone(freq, dur, kind, vol)
    for i, v in enumerate(note):
        track[s0 + i] = v
    return track


def loop_bgm_menu():
    dur = 8.0
    bed = pad_chord([220.0, 277.18, 329.63], dur, 0.22)          # Am 垫
    bed = mix(bed, pad_chord([174.61, 220.0, 261.63], dur, 0.10))  # 低八度色彩
    mel = mix(
        seq_note(440.0, 0.0, 1.8, "sine", 0.30),
        seq_note(523.25, 2.0, 1.8, "sine", 0.26),
        seq_note(659.25, 4.0, 1.8, "sine", 0.24),
        seq_note(587.33, 6.0, 1.9, "sine", 0.22),
    )
    return mix(bed, mel)


def loop_bgm_battle():
    dur = 8.0
    bass = []
    for b in range(8):  # 每秒一个脉冲低音
        bass = mix(bass, seq_note(82.41 if b % 2 == 0 else 73.42, float(b), 0.45, "saw", 0.42))
    hat = mix(*[seq_note(1200.0, 0.5 + i * 0.5, 0.05, "square", 0.06) for i in range(15)])
    lead = mix(
        seq_note(329.63, 0.0, 0.4, "square", 0.20),
        seq_note(392.0, 1.0, 0.4, "square", 0.20),
        seq_note(440.0, 2.0, 0.8, "square", 0.22),
        seq_note(392.0, 4.0, 0.4, "square", 0.20),
        seq_note(329.63, 5.0, 0.4, "square", 0.20),
        seq_note(293.66, 6.0, 0.9, "square", 0.22),
    )
    return mix(bass, hat, lead)


def loop_bgm_boss():
    dur = 8.0
    drone = pad_chord([55.0, 58.27, 82.41], dur, 0.40)  # 低沉不协和持续音
    pulse = mix(*[seq_note(110.0, float(i), 0.22, "saw", 0.30) for i in range(0, 8)])
    stab = mix(
        seq_note(233.08, 0.0, 0.6, "square", 0.18),
        seq_note(220.0, 2.0, 0.6, "square", 0.18),
        seq_note(207.65, 4.0, 0.6, "square", 0.20),
        seq_note(233.08, 6.0, 0.9, "square", 0.20),
    )
    return mix(drone, pulse, stab)


def main():
    os.makedirs(OUT, exist_ok=True)
    print("生成 BGM ...")
    for name, fn in [("bgm_menu", loop_bgm_menu), ("bgm_battle", loop_bgm_battle), ("bgm_boss", loop_bgm_boss)]:
        s = fn()
        s = s + [0.0] * (8 * SR - len(s))  # 对齐 8 秒循环点
        write_wav(name, s)
    print("生成音效 ...")
    write_wav("sfx_hit", mix(noise(0.14, 0.9, 22.0), tone(160.0, 0.12, "saw", 0.5)))
    write_wav("sfx_crit", mix(noise(0.2, 1.0, 16.0), tone(220.0, 0.18, "saw", 0.6), tone(880.0, 0.12, "square", 0.25)))
    write_wav("sfx_heal", mix(seq_note(523.25, 0.0, 0.14, "sine", 0.5), seq_note(659.25, 0.12, 0.14, "sine", 0.5), seq_note(783.99, 0.24, 0.22, "sine", 0.5)))
    write_wav("sfx_victory", mix(seq_note(523.25, 0.0, 0.16, "tri", 0.5), seq_note(659.25, 0.16, 0.16, "tri", 0.5), seq_note(783.99, 0.32, 0.16, "tri", 0.5), seq_note(1046.5, 0.48, 0.5, "tri", 0.5)))
    write_wav("sfx_defeat", mix(seq_note(392.0, 0.0, 0.3, "tri", 0.5), seq_note(311.13, 0.3, 0.3, "tri", 0.5), seq_note(233.08, 0.6, 0.6, "tri", 0.5)))
    print("完成。")


if __name__ == "__main__":
    main()

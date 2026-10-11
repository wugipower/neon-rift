# -*- coding: utf-8 -*-
"""P7f: 程序化生成 9 个怪物头像（零版权、可复现，ImageGen 配额不足时的本地方案）。
运行：python tools/gen_monster_icons.py  （输出 assets/art/portrait_e_*.png，512x512）
风格：深色底 + 元素色霓虹剪影 + 发光眼睛，与游戏内 ELEMENT_COLOR 配色一致。"""
import os
import random

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "art")
S = 512

ELE = {  # 与 battle_manager ELEMENT_COLOR 对应的十六进制
    "电": (255, 217, 77),
    "水": (77, 153, 255),
    "火": (255, 122, 61),
    "冰": (112, 216, 255),
    "无": (168, 150, 200),
}


def canvas():
    """深色底：径向渐变 + 细星点"""
    yy, xx = np.mgrid[0:S, 0:S]
    d = np.sqrt((xx - S / 2) ** 2 + (yy - S / 2) ** 2) / (S * 0.72)
    g = (1 - np.clip(d, 0, 1)) * 46 + 10
    base = np.zeros((S, S, 3), np.uint8)
    base[:, :, 0] = g * 0.75
    base[:, :, 1] = g * 0.8
    base[:, :, 2] = g * 1.15
    img = Image.fromarray(np.clip(base, 0, 255).astype(np.uint8))
    rnd = random.Random(7)
    dr = ImageDraw.Draw(img)
    for _ in range(60):
        x, y = rnd.randrange(S), rnd.randrange(S)
        v = rnd.randint(30, 80)
        dr.point((x, y), fill=(v, v, v + 20))
    return img


def shape_layer(painter):
    """透明层上画剪影，返回该层"""
    layer = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    dr = ImageDraw.Draw(layer)
    painter(dr)
    return layer


def compose(bg, color, painter, glow=16, silhouette_alpha=235):
    """主体剪影(近黑+元素描边) + 外发光 + 亮部细节"""
    light = tuple(min(255, int(c * 0.85) + 40) for c in color)
    dark = tuple(int(c * 0.16) for c in color)
    body = shape_layer(painter)
    # 外发光：把剪影染成亮色再模糊
    glow_img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    glow_img.paste(light + (160,), (0, 0), body)
    glow_img = glow_img.filter(ImageFilter.GaussianBlur(glow))
    bg = bg.convert("RGBA")
    bg.alpha_composite(glow_img)
    # 剪影本体：深色填充
    fill = Image.new("RGBA", (S, S), dark + (silhouette_alpha,))
    mask = body.split()[3]
    bg.paste(fill, (0, 0), mask)
    # 描边：剪影轮廓染亮色
    edge = body.filter(ImageFilter.FIND_EDGES)
    edge2 = Image.new("RGBA", (S, S), light + (255,))
    bg.paste(edge2, (0, 0), edge.split()[3].point(lambda a: min(255, a * 3)))
    return bg


def eyes(dr, pts, color, r=13):
    light = tuple(min(255, int(c * 0.8) + 60) for c in color)
    for (x, y) in pts:
        dr.ellipse([x - r, y - r, x + r, y + r], fill=light + (255,))


def blob(dr, cx, cy, w, h, color, steps=40):
    """不规则团块（slime 用）"""
    rnd = random.Random(3)
    pts = []
    for i in range(steps):
        a = 2 * 3.14159 * i / steps
        rr = 1 + 0.12 * rnd.random()
        x = cx + (w / 2) * rr * np.cos(a)
        y = cy + (h / 2) * rr * np.sin(a) * (1 if np.cos(a) >= -0.85 else 0.55)
        pts.append((x, y))
    dr.polygon(pts, fill=(255, 0, 0, 255))


def poly(dr, pts):
    dr.polygon(pts, fill=(255, 0, 0, 255))


def ell(dr, box):
    dr.ellipse(box, fill=(255, 0, 0, 255))


def rect(dr, box):
    dr.rectangle(box, fill=(255, 0, 0, 255))


# ---------------- 9 个怪物剪影 ----------------

def slime(dr):
    blob(dr, 256, 310, 300, 230, ELE["无"])
    ell(dr, [206, 170, 306, 250])  # 顶部小瘤


def bat(dr):
    ell(dr, [206, 196, 306, 316])                    # 身体
    poly(dr, [(212, 230), (40, 150), (70, 250), (150, 235), (206, 260)])   # 左翼
    poly(dr, [(300, 230), (472, 150), (442, 250), (362, 235), (306, 260)])  # 右翼
    poly(dr, [(222, 200), (232, 130), (252, 196)])   # 左耳
    poly(dr, [(290, 200), (280, 130), (260, 196)])   # 右耳
    poly(dr, [(238, 310), (256, 380), (274, 310)])   # 尾


def turret(dr):
    rect(dr, [120, 330, 392, 420])                   # 底座
    ell(dr, [176, 200, 336, 340])                    # 圆头
    rect(dr, [236, 60, 276, 240])                    # 竖炮管
    ell(dr, [222, 40, 290, 96])                      # 炮口
    rect(dr, [96, 250, 150, 320])
    rect(dr, [362, 250, 416, 320])                   # 侧挂弹仓


def drone(dr):
    ell(dr, [196, 206, 316, 326])                    # 机身
    for x in (70, 442):
        rect(dr, [min(x, 256) + (0 if x == 70 else 0), 250, max(x, 256), 270])  # 机臂
        ell(dr, [x - 46, 214, x + 46, 246])          # 旋翼盘
    rect(dr, [244, 320, 268, 372])                   # 起落架
    ell(dr, [230, 356, 282, 400])                    # 摄像头吊舱


def hound(dr):
    poly(dr, [(120, 330), (150, 220), (260, 200), (360, 220), (410, 260),
              (430, 220), (455, 260), (420, 330), (330, 360), (170, 360)])  # 躯干+头
    rect(dr, [150, 350, 185, 440])
    rect(dr, [250, 355, 285, 440])
    rect(dr, [340, 350, 375, 440])                   # 三腿
    poly(dr, [(410, 240), (470, 150), (430, 250)])   # 耳
    poly(dr, [(120, 300), (40, 250), (110, 340)])    # 尾焰


def warden(dr):
    """中Boss：盾卫头部+肩甲，冰蓝"""
    poly(dr, [(150, 150), (362, 150), (400, 260), (360, 420), (256, 470),
              (152, 420), (112, 260)])               # 头盔盾面
    rect(dr, [60, 170, 150, 240])
    rect(dr, [362, 170, 452, 240])                   # 肩甲
    poly(dr, [(236, 60), (256, 140), (276, 60)])     # 顶冠刺


def shade(dr):
    """裂隙之影：兜帽幽灵"""
    poly(dr, [(256, 90), (360, 190), (376, 330), (340, 430), (290, 400),
              (256, 450), (222, 400), (172, 430), (136, 330), (152, 190)])
    ell(dr, [196, 190, 316, 300])                    # 面部阴影区（mask 用亮部）


def crystal(dr):
    """共鸣水晶：三根棱柱"""
    poly(dr, [(256, 60), (330, 260), (290, 440), (222, 440), (182, 260)])
    poly(dr, [(130, 200), (180, 320), (150, 430), (100, 380), (86, 280)])
    poly(dr, [(382, 200), (430, 280), (412, 380), (362, 430), (332, 320)])


def rift_core(dr):
    """最终Boss：虚空核心+环+刺"""
    ell(dr, [156, 156, 356, 356])                    # 主体环
    for i in range(8):
        a = 2 * 3.14159 * i / 8
        x, y = 256 + 210 * np.cos(a), 256 + 210 * np.sin(a)
        poly(dr, [(256 + 150 * np.cos(a - 0.12), 256 + 150 * np.sin(a - 0.12)),
                  (x, y),
                  (256 + 150 * np.cos(a + 0.12), 256 + 150 * np.sin(a + 0.12))])


MONSTERS = {
    "e_slime": ("无", slime, [(226, 300), (290, 300)]),
    "e_bat": ("电", bat, [(234, 240), (278, 240)]),
    "e_turret": ("火", turret, [(256, 250)]),
    "e_drone": ("电", drone, [(256, 266)]),
    "e_hound": ("火", hound, [(380, 252), (410, 258)]),
    "e_warden": ("冰", warden, [(216, 280), (296, 280)]),
    "e_shade": ("无", shade, [(226, 244), (286, 244)]),
    "e_crystal": ("冰", crystal, [(256, 250)]),
    "e_rift_core": ("无", rift_core, []),
}


def add_detail(img, mid):
    """剪影之外的高亮：眼睛/核心"""
    dr = ImageDraw.Draw(img, "RGBA")
    elem, painter, eye_pts = MONSTERS[mid]
    color = ELE[elem]
    for (x, y) in eye_pts:
        eyes(dr, [(x, y)], color, r=13 if mid != "e_hound" else 9)
    if mid == "e_rift_core":
        light = tuple(min(255, c + 70) for c in color)
        dr.ellipse([196, 196, 316, 316], fill=(20, 8, 30, 255), outline=light + (255,), width=8)
        dr.ellipse([236, 236, 276, 276], fill=light + (255,))
    if mid == "e_crystal":
        light = tuple(min(255, c + 60) for c in color)
        dr.line([(256, 100), (256, 400)], fill=light + (200,), width=6)


def main():
    os.makedirs(OUT, exist_ok=True)
    for mid, (elem, painter, _) in MONSTERS.items():
        img = canvas()
        img = compose(img, ELE[elem], painter, glow=18 if mid != "e_rift_core" else 26)
        add_detail(img, mid)
        path = os.path.join(OUT, "portrait_%s.png" % mid)
        img.convert("RGB").save(path)
        print("wrote", os.path.basename(path))


if __name__ == "__main__":
    main()

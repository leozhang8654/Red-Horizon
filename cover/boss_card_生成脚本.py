# -*- coding: utf-8 -*-
# 生成 MANTIS-LUX Boss 参考资料卡 PNG
from PIL import Image, ImageDraw, ImageFont
import math

W, H = 1400, 1980
BG = (16, 13, 26, 255)        # 深紫黑底
PANEL = (28, 23, 46, 255)     # 面板底色
PANEL_LINE = (78, 66, 120, 255)
TXT = (235, 230, 250, 255)
SUB = (168, 158, 200, 255)
ACC_AMBER = (255, 178, 64, 255)   # 炮台标注（阶段一目标）
ACC_RED = (255, 92, 92, 255)      # 核心标注（阶段二弱点）
ACC_PURPLE = (178, 132, 255, 255)

def font(sz, bold=False):
    try:
        return ImageFont.truetype('/System/Library/Fonts/PingFang.ttc', sz, index=2 if bold else 0)
    except Exception:
        return ImageFont.truetype('/System/Library/Fonts/Hiragino Sans GB.ttc', sz)

img = Image.new('RGBA', (W, H), BG)
d = ImageDraw.Draw(img)

F_TITLE = font(56, True)
F_H2 = font(40, True)
F_BODY = font(28)
F_SMALL = font(24)
F_LABEL = font(26, True)

def text_c(x, y, s, f, fill=TXT, anchor='mm'):
    d.text((x, y), s, font=f, fill=fill, anchor=anchor)

# ---------- 标题 ----------
text_c(W/2, 70, 'MANTIS-LUX 母舰 · Boss 参考卡', F_TITLE)
text_c(W/2, 130, '第三波 Boss — 紫色蝠鲼母舰 · 分阶段击破', F_BODY, SUB)

# ---------- Boss 大图 + 部件标注 ----------
boss = Image.open('/tmp/boss_composite.png').convert('RGBA')
bw = 880
r = bw / boss.width
boss_s = boss.resize((bw, round(boss.height * r)), Image.LANCZOS)
bx, by = (W - bw) // 2, 180
img.alpha_composite(boss_s, (bx, by))

# 炮台/核心在合成图(1450宽)中的坐标 -> 缩放后画布坐标
def P(cx, cy):
    return (bx + cx * r, by + cy * r)
pts = {
    'bl': P(373, 482),   # 左大炮管 (134/520*1450=373...)
    'br': P(1068, 488),
    'dl': P(524, 271),
    'dr': P(920, 271),
    'core': P(723, 430),
}
# 注: 上面坐标按 1450 宽合成图换算: small520 * (1450/520)
def ring(p, rad, color):
    x, y = p
    d.ellipse([x-rad, y-rad, x+rad, y+rad], outline=color, width=5)

ring(pts['bl'], 88, ACC_AMBER)
ring(pts['br'], 88, ACC_AMBER)
ring(pts['dl'], 56, ACC_AMBER)
ring(pts['dr'], 56, ACC_AMBER)
ring(pts['core'], 60, ACC_RED)

def callout(p, rad, tx, ty, label, sub, color):
    x, y = p
    ang = math.atan2(ty - y, tx - x)
    sx, sy = x + rad * math.cos(ang), y + rad * math.sin(ang)
    d.line([sx, sy, tx, ty], fill=color, width=3)
    anchor = 'lm' if tx > x else 'rm'
    off = 14 if tx > x else -14
    d.text((tx + off, ty - 14), label, font=F_LABEL, fill=color, anchor=anchor)
    d.text((tx + off, ty + 22), sub, font=F_SMALL, fill=SUB, anchor=anchor)

callout(pts['dl'], 56, 150, 260, '小炮塔 ×2', '阶段一目标 · 会瞄准玩家', ACC_AMBER)
callout(pts['bl'], 88, 150, 600, '大炮管 ×2', '阶段一目标 · 会瞄准玩家', ACC_AMBER)
callout(pts['core'], 60, 1250, 330, '核心', '阶段二唯一弱点', ACC_RED)
callout(P(1010, 620), 0, 1250, 600, '船体为实体', '撞上去会被挡住并扣血', ACC_PURPLE)

# ---------- 攻击方式 ----------
sec_y = 900
text_c(W/2, sec_y, '攻击方式', F_H2)
panel_y = sec_y + 50
panel_h = 560
panel_w = 420
gap = (W - 3 * panel_w) // 4

core_b = Image.open('boss_cut/core_bullet.png').convert('RGBA')
turret_b = Image.open('boss_cut/turret_bullet.png').convert('RGBA')
laser = Image.open('boss_cut/laser.png').convert('RGBA')

def panel(i, title, tag):
    px = gap + i * (panel_w + gap)
    d.rounded_rectangle([px, panel_y, px + panel_w, panel_y + panel_h], 18, fill=PANEL, outline=PANEL_LINE, width=2)
    text_c(px + panel_w/2, panel_y + 45, title, font(32, True))
    text_c(px + panel_w/2, panel_y + 90, tag, F_SMALL, SUB)
    return px

def arrow(x0, y0, x1, y1, color, w=4):
    d.line([x0, y0, x1, y1], fill=color, width=w)
    ang = math.atan2(y1 - y0, x1 - x0)
    for s in (-1, 1):
        a = ang + math.pi + s * 0.5
        d.line([x1, y1, x1 + 16*math.cos(a), y1 + 16*math.sin(a)], fill=color, width=w)

# ① 核心环形弹幕
px = panel(0, '① 核心环形弹幕', '全程都会放 · 来自核心')
ccx, ccy = px + panel_w/2, panel_y + 270
d.ellipse([ccx-26, ccy-26, ccx+26, ccy+26], outline=ACC_RED, width=5)
cb = core_b.resize((44, 44), Image.LANCZOS)
for k in range(8):
    a = k * math.pi / 4 + math.pi/8
    bxp, byp = ccx + 95*math.cos(a), ccy + 95*math.sin(a)
    img.alpha_composite(cb, (round(bxp-22), round(byp-22)))
    arrow(ccx + 130*math.cos(a), ccy + 130*math.sin(a),
          ccx + 165*math.cos(a), ccy + 165*math.sin(a), (190, 120, 255, 255))
d2 = ImageDraw.Draw(img)
text_c(px + panel_w/2, panel_y + 460, '紫色光球从核心向四周', F_BODY)
text_c(px + panel_w/2, panel_y + 500, '环状扩散，找空隙穿过去', F_BODY)

# ② 炮台机枪散射
px = panel(1, '② 炮台机枪散射', '阶段一主火力 · 四座炮台')
tcx, tcy = px + panel_w/2, panel_y + 170
d.ellipse([tcx-22, tcy-22, tcx+22, tcy+22], outline=ACC_AMBER, width=5)
tb = turret_b.resize((26, 66), Image.LANCZOS)
for k, ang_deg in enumerate([-28, -10, 10, 28]):
    a = math.radians(90 + ang_deg)
    L = 120 + (k % 2) * 45
    bxp, byp = tcx + L*math.cos(a), tcy + L*math.sin(a)
    rot = tb.rotate(-ang_deg, expand=True, resample=Image.BICUBIC)
    img.alpha_composite(rot, (round(bxp - rot.width/2), round(byp - rot.height/2)))
    arrow(tcx + (L+95)*math.cos(a), tcy + (L+95)*math.sin(a),
          tcx + (L+130)*math.cos(a), tcy + (L+130)*math.sin(a), ACC_AMBER)
text_c(px + panel_w/2, panel_y + 460, '四座炮台实时瞄准玩家', F_BODY)
text_c(px + panel_w/2, panel_y + 500, '扇形连射火舌弹，别停留', F_BODY)

# ③ 横扫激光
px = panel(2, '③ 中央横扫激光', '阶段二解锁 · 整船侧倾')
lcx = px + panel_w/2
ls = laser.resize((56, 290), Image.LANCZOS)
img.alpha_composite(ls, (round(lcx - 28), panel_y + 130))
arrow(lcx - 60, panel_y + 400, lcx - 150, panel_y + 400, ACC_PURPLE)
arrow(lcx + 60, panel_y + 400, lcx + 150, panel_y + 400, ACC_PURPLE)
text_c(px + panel_w/2, panel_y + 460, '激光从船身中央射出并横扫', F_BODY)
text_c(px + panel_w/2, panel_y + 500, '激光始终垂直机身，贴边躲', F_BODY)

# ---------- 击破流程 ----------
flow_y = panel_y + panel_h + 80
text_c(W/2, flow_y, '击破流程', F_H2)
steps = [
    ('登场', '出场演出期间无敌'),
    ('阶段一', '逐个打爆四座炮台'),
    ('阶段二', '核心暴露 · 激光解锁'),
    ('击破', '核心打空 → 爆炸演出'),
]
sw, sh = 280, 130
sgap = (W - 4 * sw) // 5
sy = flow_y + 50
for i, (t, s) in enumerate(steps):
    sx = sgap + i * (sw + sgap)
    color = ACC_AMBER if i == 1 else ACC_RED if i == 2 else PANEL_LINE
    d.rounded_rectangle([sx, sy, sx + sw, sy + sh], 16, fill=PANEL, outline=color, width=3)
    text_c(sx + sw/2, sy + 42, t, font(32, True))
    text_c(sx + sw/2, sy + 90, s, F_SMALL, SUB)
    if i < 3:
        arrow(sx + sw + 8, sy + sh/2, sx + sw + sgap - 8, sy + sh/2, SUB, 4)

# ---------- 底部备注 ----------
note_y = sy + sh + 60
text_c(W/2, note_y, 'Boss 全程在屏幕顶部悬停、左右游移；阶段一核心无敌，只能先打炮台', F_BODY, SUB)

img.convert('RGB').save('/Users/leozhang/一号游戏/cover/boss_reference.png', quality=95)
print('saved', img.size)

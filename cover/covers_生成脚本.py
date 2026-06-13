# -*- coding: utf-8 -*-
# Red Horizon 封面生成 v2：itch.io 630x500 / GitHub 1280x640
# 设计哲学「引力井」：上方威压、下方意志、弹幕留缺口、三色声部
from PIL import Image, ImageDraw, ImageFilter, ImageEnhance, ImageFont
import math, random

random.seed(11)
ROOT = '/Users/leozhang/一号游戏'
FONTS = '/Users/leozhang/Library/Application Support/Claude/local-agent-mode-sessions/skills-plugin/cf29fb74-6060-416b-a0ea-dc892f9e75ac/9a06fbae-4875-4603-ac10-cf23f7dee7d1/skills/canvas-design/canvas-fonts'

title_img = Image.open(f'{ROOT}/标题_透明.png').convert('RGBA')
ship_img = ImageEnhance.Brightness(Image.open(f'{ROOT}/ship.png').convert('RGBA')).enhance(1.18)
boss_img = ImageEnhance.Brightness(Image.open('/tmp/boss_composite.png').convert('RGBA')).enhance(1.08)
bg_full = Image.open(f'{ROOT}/bg_top.png').convert('RGB')

def radial_vignette(w, h, strength=165, inner=0.55):
    sw, sh = 158, 125
    m = Image.new('L', (sw, sh))
    px = m.load()
    for y in range(sh):
        for x in range(sw):
            dx = (x - sw/2) / (sw/2); dy = (y - sh/2) / (sh/2)
            d = math.sqrt(dx*dx + dy*dy)
            v = 0 if d < inner else min(1.0, (d - inner) / (1.45 - inner))
            px[x, y] = int(strength * (v ** 1.6))
    m = m.resize((w, h), Image.LANCZOS).filter(ImageFilter.GaussianBlur(6))
    black = Image.new('RGBA', (w, h), (5, 2, 8, 255)); black.putalpha(m)
    return black

def glow_dot(layer, x, y, r, color, alpha=140, blur=None):
    g = Image.new('RGBA', layer.size, (0, 0, 0, 0))
    ImageDraw.Draw(g).ellipse([x-r, y-r, x+r, y+r], fill=color + (alpha,))
    g = g.filter(ImageFilter.GaussianBlur(blur if blur else r*0.9))
    layer.alpha_composite(g)

def draw_orb(canvas, x, y, r):
    """紫色弹幕光球:辉光/球体/亮芯 三层"""
    glow_dot(canvas, x, y, r*2.1, (150, 70, 255), alpha=80, blur=r*1.4)
    d = ImageDraw.Draw(canvas)
    d.ellipse([x-r, y-r, x+r, y+r], fill=(168, 96, 250, 235))
    rr = r*0.5
    d.ellipse([x-rr, y-rr*1.1, x+rr, y+rr*0.9], fill=(238, 216, 255, 255))

def make_background(w, h, crop_y=2600, top_dark=0.42):
    src_h = round(bg_full.width * h / w)
    bg = bg_full.crop((0, crop_y, 1024, crop_y + src_h)).resize((w, h), Image.LANCZOS)
    bg = bg.filter(ImageFilter.GaussianBlur(2.2))
    bg = ImageEnhance.Brightness(bg).enhance(0.42)
    bg = ImageEnhance.Color(bg).enhance(0.85)
    base = bg.convert('RGBA')
    band = Image.new('L', (1, h))
    for y in range(h):
        t = max(0.0, 1.0 - y / (h * top_dark))
        band.putpixel((0, y), int(130 * t * t))
    band = band.resize((w, h))
    dark = Image.new('RGBA', (w, h), (8, 4, 10, 255)); dark.putalpha(band)
    base.alpha_composite(dark)
    return base

def paste_boss(canvas, cx, top, bw):
    r = bw / boss_img.width
    b = boss_img.resize((bw, round(boss_img.height * r)), Image.LANCZOS)
    bx, by = round(cx - bw/2), top
    glow_dot(canvas, cx, by + b.height*0.42, bw*0.42, (120, 70, 200), alpha=75, blur=bw*0.18)
    canvas.alpha_composite(b, (bx, by))
    core = (cx, by + b.height * 0.395)
    glow_dot(canvas, core[0], core[1], bw*0.05, (255, 90, 80), alpha=170, blur=bw*0.04)
    return core, b.height

def bullet_arcs(canvas, core, radii, gap_deg, gap_width, orb_r, a0=24, a1=156):
    """残缺同心弧:下半球扩散,缺口=生路"""
    for i, rad in enumerate(radii):
        step = 10.5 - i*0.8
        a = a0 + (i % 2) * step/2
        while a <= a1:
            if abs(a - gap_deg) > gap_width:
                jr = rad + random.uniform(-5, 5)
                x = core[0] + jr * math.cos(math.radians(a))
                y = core[1] + jr * math.sin(math.radians(a))
                draw_orb(canvas, x, y, orb_r * random.uniform(0.92, 1.08))
            a += step + random.uniform(-1.2, 1.2)

def paste_player(canvas, x, y, pw, core):
    """玩家:机头指向Boss核心,蓝色尾焰+两发主炮弹"""
    dx, dy = core[0] - x, core[1] - y
    L = math.hypot(dx, dy); ux, uy = dx/L, dy/L
    a = math.degrees(math.atan2(-dx, -dy))          # PIL逆时针角度,使机头指向核心
    # 尾焰(三层透明度,沿机尾方向)
    for k in range(1, 10):
        tx, ty = x - ux*pw*0.19*k, y - uy*pw*0.19*k
        glow_dot(canvas, tx, ty, pw*0.16*(1-k*0.085), (95, 175, 255), alpha=int(150*(1-k*0.10)), blur=pw*0.10)
    # 主炮弹道:沿机头方向飞向缺口
    d = ImageDraw.Draw(canvas)
    for k in (1.6, 2.6):
        bx, by = x + ux*pw*k, y + uy*pw*k
        glow_dot(canvas, bx, by, pw*0.10, (150, 215, 255), alpha=190, blur=pw*0.07)
        d.line([bx-ux*pw*0.18, by-uy*pw*0.18, bx+ux*pw*0.18, by+uy*pw*0.18],
               fill=(215, 240, 255, 240), width=max(3, pw//22))
    s = ship_img.resize((pw, pw), Image.LANCZOS).rotate(a, expand=True, resample=Image.BICUBIC)
    glow_dot(canvas, x, y, pw*0.55, (70, 140, 255), alpha=70, blur=pw*0.32)
    canvas.alpha_composite(s, (round(x - s.width/2), round(y - s.height/2)))

def paste_title(canvas, cx, top, tw):
    t = title_img.resize((tw, round(title_img.height * tw / title_img.width)), Image.LANCZOS)
    canvas.alpha_composite(t, (round(cx - tw/2), top))
    return t.height

def footnote(canvas, x, y, text, size, fill=(200, 172, 152, 205), anchor='mm', mono=True):
    f = ImageFont.truetype(f'{FONTS}/GeistMono-Regular.ttf' if mono else f'{ROOT}/fusion-pixel-12px-proportional-zh_hans.ttf', size)
    ImageDraw.Draw(canvas).text((x, y), text, font=f, fill=fill, anchor=anchor)

# ============ itch.io 630x500 (2x: 1260x1000) ============
W, H = 1260, 1000
c = make_background(W, H, crop_y=2300)
title_h = paste_title(c, W/2, 30, 800)            # 30..241
core, bh = paste_boss(c, W*0.5, 280, 640)          # 280..760, core y≈470
player = (W*0.660, H*0.825)
gap = math.degrees(math.atan2(player[1]-core[1], player[0]-core[0]))
bullet_arcs(c, core, radii=[225, 320, 418], gap_deg=gap, gap_width=15, orb_r=11)
paste_player(c, player[0], player[1], 150, core)
c.alpha_composite(radial_vignette(W, H))
footnote(c, W/2, H-32, "A MARS SHOOT 'EM UP  ·  MADE WITH GODOT", 23)
c.convert('RGB').resize((630, 500), Image.LANCZOS).save(f'{ROOT}/cover/cover_itch_630x500.png')
print('itch ok, gap angle', round(gap))

# ============ GitHub 1280x640 (2x: 2560x1280) ============
W, H = 2560, 1280
c = make_background(W, H, crop_y=2150, top_dark=0.30)
core, bh = paste_boss(c, W*0.70, 95, 700)          # 95..620, core y≈302
player = (W*0.485, H*0.800)
gap = math.degrees(math.atan2(player[1]-core[1], player[0]-core[0]))
bullet_arcs(c, core, radii=[250, 350, 455], gap_deg=gap, gap_width=14, orb_r=12, a0=20, a1=175)
paste_player(c, player[0], player[1], 155, core)
# 标题坐镇左侧,拥有干净领空
tx = W*0.245
th = paste_title(c, tx, round(H*0.26), 1000)
footnote(c, tx, H*0.26 + th + 78, "TOP-DOWN SHOOT 'EM UP", 36)
footnote(c, tx, H*0.26 + th + 148, '击毁 MANTIS-LUX 母舰', 38, fill=(180, 152, 136, 195), mono=False)
c.alpha_composite(radial_vignette(W, H, strength=145))
footnote(c, W-50, H-42, 'MADE WITH GODOT', 27, fill=(172, 148, 132, 165), anchor='rm')
c.convert('RGB').resize((1280, 640), Image.LANCZOS).save(f'{ROOT}/cover/cover_github_1280x640.png')
print('github ok, gap angle', round(gap))

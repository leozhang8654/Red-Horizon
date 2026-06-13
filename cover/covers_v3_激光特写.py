# -*- coding: utf-8 -*-
# Red Horizon 封面 v3：用 AI 三联图的最下面一格（激光特写）+ 标题
# 产出：cover_itch_630x500.png / cover_github_1280x640.png
from PIL import Image, ImageDraw, ImageFilter, ImageEnhance, ImageFont

ROOT = '/Users/leozhang/一号游戏'
FONTS = '/Users/leozhang/Library/Application Support/Claude/local-agent-mode-sessions/skills-plugin/cf29fb74-6060-416b-a0ea-dc892f9e75ac/9a06fbae-4875-4603-ac10-cf23f7dee7d1/skills/canvas-design/canvas-fonts'

# 两份素材都来自第三格特写：
#   GitHub 用保留激光的版本：飞机左移错开(move_ship.py) + 激光改从船腹发射口射出、
#          不再连着核心(detach_beam.py，符合游戏设定：核心只是弱点)
#   itch   用抹掉激光的干净版本（remove_laser.py 的产物）
panel_laser = Image.open(f'{ROOT}/cover/panel3_laser_final.png')      # 1024x506
panel = Image.open(f'{ROOT}/cover/panel3_v2_clean.png')               # 1024x506
title_img = Image.open(f'{ROOT}/标题_透明.png').convert('RGBA')


def top_band(canvas, depth, strength=150):
    """顶部手刷暗带：给标题一块干净领空"""
    w, h = canvas.size
    band = Image.new('L', (1, h), 0)
    for y in range(h):
        t = max(0.0, 1.0 - y / depth)
        band.putpixel((0, y), int(strength * t * t))
    dark = Image.new('RGBA', (w, h), (4, 2, 6, 255))
    dark.putalpha(band.resize((w, h)))
    canvas.alpha_composite(dark)


def vignette(canvas, strength=120):
    w, h = canvas.size
    m = Image.new('L', (w // 8, h // 8), 0)
    d = ImageDraw.Draw(m)
    d.rectangle([0, 0, w // 8, h // 8], outline=None)
    import math
    px = m.load()
    sw, sh = m.size
    for y in range(sh):
        for x in range(sw):
            dx = (x - sw / 2) / (sw / 2)
            dy = (y - sh / 2) / (sh / 2)
            dd = math.sqrt(dx * dx + dy * dy)
            v = 0 if dd < 0.62 else min(1.0, (dd - 0.62) / 0.85)
            px[x, y] = int(strength * v ** 1.7)
    m = m.resize((w, h), Image.LANCZOS).filter(ImageFilter.GaussianBlur(5))
    black = Image.new('RGBA', (w, h), (3, 1, 5, 255))
    black.putalpha(m)
    canvas.alpha_composite(black)


def paste_title(canvas, cx, top, tw):
    t = title_img.resize((tw, round(title_img.height * tw / title_img.width)), Image.LANCZOS)
    # 标题落地前先垫一层柔和黑晕，保证可读
    halo = Image.new('RGBA', canvas.size, (0, 0, 0, 0))
    hd = ImageDraw.Draw(halo)
    hd.rounded_rectangle([cx - tw / 2 - 30, top - 18, cx + tw / 2 + 30, top + t.height + 18],
                         radius=40, fill=(2, 1, 4, 110))
    halo = halo.filter(ImageFilter.GaussianBlur(28))
    canvas.alpha_composite(halo)
    canvas.alpha_composite(t, (round(cx - tw / 2), top))
    return t.height


def footnote(canvas, x, y, text, size, fill=(205, 178, 158, 200), anchor='mm', mono=True):
    f = ImageFont.truetype(f'{FONTS}/GeistMono-Regular.ttf' if mono else
                           f'{ROOT}/fusion-pixel-12px-proportional-zh_hans.ttf', size)
    ImageDraw.Draw(canvas).text((x, y), text, font=f, fill=fill, anchor=anchor)


# ============ GitHub 1280x640（2x: 2560x1280）============
# 整格刚好 2:1，原图直接放大铺满
W, H = 2560, 1280
c = panel_laser.resize((W, H), Image.LANCZOS).convert('RGBA')
c = ImageEnhance.Brightness(c).enhance(1.04)
top_band(c, depth=H * 0.42, strength=140)
# 新构图：飞机在左、Boss 在右上 → 标题放左上的岩壁区，正对玩家上方
tx, tw = W * 0.30, 1150
th = paste_title(c, tx, 96, tw)
footnote(c, tx, 96 + th + 64, "TOP-DOWN SHOOT 'EM UP", 36)
footnote(c, tx, 96 + th + 134, '击毁 MANTIS-LUX 母舰', 38, fill=(185, 158, 140, 195), mono=False)
vignette(c, strength=110)
footnote(c, W - 50, H - 42, 'MADE WITH GODOT', 27, fill=(175, 150, 134, 160), anchor='rm')
c.convert('RGB').resize((1280, 640), Image.LANCZOS).save(f'{ROOT}/cover/cover_github_1280x640.png')
print('github ok')

# ============ itch.io 630x500（2x: 1260x1000）============
# 1.26:1 竖一点的画幅：裁中段，保住玩家 + Boss核心
W, H = 1260, 1000
crop_w = round(506 * W / H)  # 638
src = panel.crop((85, 0, 85 + crop_w, 506)).resize((W, H), Image.LANCZOS).convert('RGBA')
c = ImageEnhance.Brightness(src).enhance(1.04)
top_band(c, depth=H * 0.42, strength=160)
tx, tw = W / 2, 980
th = paste_title(c, tx, 60, tw)
footnote(c, tx, 60 + th + 52, "BULLET HELL  ·  MADE WITH GODOT", 30)
vignette(c, strength=120)
c.convert('RGB').resize((630, 500), Image.LANCZOS).save(f'{ROOT}/cover/cover_itch_630x500.png')
print('itch ok')

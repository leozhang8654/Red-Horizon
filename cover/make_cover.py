# -*- coding: utf-8 -*-
"""用真实游戏素材 + 程序特效合成两版封面：itch.io 方封面 / GitHub 宽横幅。"""
import os, math, random
from PIL import Image, ImageDraw, ImageFilter, ImageEnhance, ImageFont

random.seed(7)
ROOT = "/Users/leozhang/一号游戏"
OUT = os.path.join(ROOT, "cover")
FONT_PATH = os.path.join(ROOT, "fusion-pixel-12px-proportional-zh_hans.ttf")

def L(p):  # load RGBA
    return Image.open(os.path.join(ROOT, p)).convert("RGBA")

def scaled(img, w=None, h=None):
    iw, ih = img.size
    if w and not h: h = round(ih * w / iw)
    if h and not w: w = round(iw * h / ih)
    return img.resize((w, h), Image.LANCZOS)

def glow(size, center, radius, color, alpha=255, blur=None):
    """一团径向发光（中心实、边缘虚）。"""
    layer = Image.new("RGBA", size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    cx, cy = center
    d.ellipse([cx - radius, cy - radius, cx + radius, cy + radius],
              fill=(color[0], color[1], color[2], alpha))
    layer = layer.filter(ImageFilter.GaussianBlur(blur or radius * 0.55))
    return layer

def vignette(size, strength=160):
    """四周压暗。"""
    w, h = size
    v = Image.new("L", size, 0)
    d = ImageDraw.Draw(v)
    m = int(min(w, h) * 0.62)
    d.ellipse([w*0.5 - w*0.62, h*0.5 - h*0.62, w*0.5 + w*0.62, h*0.5 + h*0.62], fill=255)
    v = v.filter(ImageFilter.GaussianBlur(min(w, h) * 0.18))
    dark = Image.new("RGBA", size, (0, 0, 0, strength))
    out = Image.new("RGBA", size, (0, 0, 0, 0))
    out.paste(dark, (0, 0), ImageOps_invert(v))
    return out

def ImageOps_invert(L_img):
    return Image.eval(L_img, lambda x: 255 - x)

def vgrad(size, top_rgba, bot_rgba):
    """竖直渐变。"""
    w, h = size
    base = Image.new("RGBA", (1, h))
    for y in range(h):
        t = y / (h - 1)
        r = int(top_rgba[0]*(1-t) + bot_rgba[0]*t)
        g = int(top_rgba[1]*(1-t) + bot_rgba[1]*t)
        b = int(top_rgba[2]*(1-t) + bot_rgba[2]*t)
        a = int(top_rgba[3]*(1-t) + bot_rgba[3]*t)
        base.putpixel((0, y), (r, g, b, a))
    return base.resize((w, h))

def bg_slice(canvas_w, canvas_h, row0):
    """从峡谷长图截一段，缩放铺满画布。"""
    bg = L("bg_top.png")
    bw, bh = bg.size                      # 1024 x 15360
    crop_h = round(bw * canvas_h / canvas_w)
    crop = bg.crop((0, row0, bw, row0 + crop_h))
    return crop.resize((canvas_w, canvas_h), Image.LANCZOS)

def streak(size, x, y0, y1, color, width, alpha=220, blur=2):
    """一条竖直弹道/光束。"""
    layer = Image.new("RGBA", size, (0,0,0,0))
    d = ImageDraw.Draw(layer)
    d.line([(x, y0), (x, y1)], fill=(color[0],color[1],color[2],alpha), width=width)
    return layer.filter(ImageFilter.GaussianBlur(blur))

def comp(base, layer):
    return Image.alpha_composite(base, layer)

def paste(base, img, center):
    layer = Image.new("RGBA", base.size, (0,0,0,0))
    layer.paste(img, (round(center[0]-img.size[0]/2), round(center[1]-img.size[1]/2)), img)
    return Image.alpha_composite(base, layer)

# 预载素材
TITLE = L("标题_透明.png")
SHIP  = L("ship.png")
BOSS  = L("boss_cut/body_full.png")
PSHOT = L("副炮子弹.png")
CORE  = L("boss_cut/core_bullet.png")

# ============ 1) itch.io 方封面 1600 x 1280 ============
def make_itch():
    W, H = 1600, 1280
    img = bg_slice(W, H, 3200)
    img = ImageEnhance.Brightness(img).enhance(0.40)
    img = ImageEnhance.Color(img).enhance(1.25)
    # 顶部更暗、底部暖红渐变
    img = comp(img, vgrad((W,H), (8,4,10,210), (40,12,6,40)))
    # Boss 背后大红光
    img = comp(img, glow((W,H), (W//2, 690), 560, (255,70,30), 150))
    img = comp(img, glow((W,H), (W//2, 700), 300, (255,150,60), 120))
    # Boss 弹幕（红，下落）
    for i in range(7):
        x = random.randint(420, 1180); cb = scaled(CORE, w=random.randint(26,46))
        img = paste(img, cb, (x, random.randint(720, 1060)))
    # Boss 母舰
    boss = scaled(BOSS, w=1040)
    img = paste(img, boss, (W//2, 560))
    # 标题 logo（叠在最上方，带描边光）
    title = scaled(TITLE, w=1180)
    tglow = title.filter(ImageFilter.GaussianBlur(10))
    img = paste(img, tglow, (W//2, 200))
    img = paste(img, title, (W//2, 195))
    # 玩家蓝光 + 引擎尾焰 + 飞机
    img = comp(img, glow((W,H), (W//2, 1090), 230, (60,150,255), 150))
    for dx in (-46, 0, 46):
        img = comp(img, streak((W,H), W//2+dx, 1110, 1275, (120,200,255), 14, 200, 7))
    for i in range(6):  # 玩家子弹（蓝，上行）
        x = W//2 + random.randint(-120,120); ps = scaled(PSHOT, w=random.randint(16,24))
        img = paste(img, ps, (x, random.randint(820, 1010)))
    ship = scaled(SHIP, w=300)
    img = paste(img, ship, (W//2, 1070))
    # 标语
    draw_text(img, "竖版弹幕过关射击  ·  BULLET HELL SHOOTER", (W//2, 372), 34, center=True)
    # 暗角
    img = comp(img, vignette((W,H), 170))
    img.convert("RGB").save(os.path.join(OUT, "cover_itch.png"))
    print("saved cover_itch.png", img.size)

# ============ 2) GitHub 宽横幅 1600 x 640 ============
def make_github():
    W, H = 1600, 640
    img = bg_slice(W, H, 4200)
    img = ImageEnhance.Brightness(img).enhance(0.38)
    img = ImageEnhance.Color(img).enhance(1.25)
    img = comp(img, vgrad((W,H), (8,4,10,200), (38,12,6,30)))
    # 右侧 Boss 大红光 + 母舰（压在右上角）
    img = comp(img, glow((W,H), (1180, 300), 430, (255,70,30), 150))
    img = comp(img, glow((W,H), (1180, 300), 230, (255,150,60), 120))
    for i in range(6):
        x = random.randint(900, 1500); cb = scaled(CORE, w=random.randint(22,40))
        img = paste(img, cb, (x, random.randint(260, 560)))
    boss = scaled(BOSS, w=760)
    img = paste(img, boss, (1180, 250))
    # 左侧标题 + 标语
    title = scaled(TITLE, w=820)
    tglow = title.filter(ImageFilter.GaussianBlur(9))
    img = paste(img, tglow, (470, 235))
    img = paste(img, title, (468, 230))
    draw_text(img, "竖版弹幕过关射击  ·  击破紫色母舰 MANTIS-LUX", (468, 352), 27, center=True)
    draw_text(img, "Godot 4.6  ·  Bullet-Hell Shooter", (468, 396), 23, center=True, color=(255,180,120))
    # 玩家（中下，朝右上冲）+ 蓝光尾焰 —— 压在标语下方、与文字错开
    img = comp(img, glow((W,H), (760, 520), 150, (60,150,255), 150))
    for dx in (-28, 0, 28):
        img = comp(img, streak((W,H), 760+dx, 535, 638, (120,200,255), 10, 190, 6))
    ship = scaled(SHIP, w=190)
    img = paste(img, ship, (760, 510))
    img = comp(img, vignette((W,H), 150))
    img.convert("RGB").save(os.path.join(OUT, "cover_github.png"))
    print("saved cover_github.png", img.size)

def draw_text(img, text, pos, size, color=(245,235,225), center=True):
    try:
        font = ImageFont.truetype(FONT_PATH, size)
    except Exception:
        font = ImageFont.load_default()
    d = ImageDraw.Draw(img)
    bbox = d.textbbox((0,0), text, font=font)
    tw, th = bbox[2]-bbox[0], bbox[3]-bbox[1]
    x = pos[0]-tw/2 if center else pos[0]
    y = pos[1]-th/2
    # 描边
    for ox in (-2,-1,0,1,2):
        for oy in (-2,-1,0,1,2):
            d.text((x+ox, y+oy), text, font=font, fill=(0,0,0,180))
    d.text((x, y), text, font=font, fill=color)

make_itch()
make_github()
print("DONE")

# -*- coding: utf-8 -*-
# 游戏设定修正：核心不发射激光。
# 把"核心 → 船腹下方"整段光束删干净（含核心正下方的残段），
# 激光改为从船腹下方的发射口射出。
# 输入: cover/panel3_laser_shipmoved.png  输出: cover/panel3_laser_final.png
from PIL import Image, ImageDraw
import numpy as np
import cv2

ROOT = '/Users/leozhang/一号游戏'
panel = Image.open(f'{ROOT}/cover/panel3_laser_shipmoved.png')
W, H = panel.size
a = np.asarray(panel).astype(np.uint8)

def fit_x(y):  # 激光中线: 过 (100,589) (480,418)
    return 589 - (y - 100) * (589 - 418) / 380.0

CUT_Y0, CUT_Y1 = 84, 208      # 删除区间：核心环亮心下缘 → 船腹下方
HULL_EDGE = 186               # 这以下是岩石背景
EMIT = (int(fit_x(212)), 212)  # 发射口（比上一版再往下）

def hw_at(y):  # 蒙版半宽
    if y < 118:   return 28    # 核心环里:只切光束芯,别吃环
    if y < 132:   return 38
    if y < 162:   return 38 + (y - 132) * (74 - 38) / 30
    return 78                  # 船腹以下连柔光一起吃

# ---- 1. 蒙版 ----
mi = Image.new('L', (W, H), 0); md = ImageDraw.Draw(mi)
for y in range(CUT_Y0, CUT_Y1):
    cx, hw = fit_x(y), hw_at(y)
    md.line([cx - hw, y, cx + hw, y], fill=255, width=1)
mask_np = np.asarray(mi) > 127

# ---- 2. 打底：逐行从两侧取色，横向插值（环里采到环光、甲板采到甲板）----
src_blur = cv2.GaussianBlur(a.astype(np.float32), (0, 0), 7)
lf = src_blur.copy()
for y in range(CUT_Y0, CUT_Y1):
    cx, hw = fit_x(y), hw_at(y)
    x0, x1 = int(cx - hw), int(cx + hw)
    cl = src_blur[y, max(0, x0 - 95):x0 - 25].mean(axis=0)
    cr = src_blur[y, x1 + 25:min(W, x1 + 95)].mean(axis=0)
    xs = np.arange(max(0, x0), min(W, x1 + 1))
    t = (xs - x0) / max(1, x1 - x0)
    lf[y, xs] = cl[None, :] * (1 - t)[:, None] + cr[None, :] * t[:, None]
lf = cv2.GaussianBlur(lf, (0, 0), 8)

# ---- 3. 借纹理：船体段借右侧甲板，岩石段借左缘岩壁 ----
def tile_hp(src, seed):
    hp = src - cv2.GaussianBlur(src, (0, 0), 4)
    ph, pw, _ = hp.shape
    tex = np.zeros((H, W, 3), np.float32)
    rng = np.random.default_rng(seed)
    for ty in range(0, H, ph):
        for tx in range(0, W, pw):
            t = np.roll(np.roll(hp, int(rng.integers(0, ph)), axis=0),
                        int(rng.integers(0, pw)), axis=1)
            h2, w2 = min(ph, H - ty), min(pw, W - tx)
            tex[ty:ty + h2, tx:tx + w2] = t[:h2, :w2]
    return tex

tex_hull = tile_hp(a[120:190, 700:880].astype(np.float32), 9)
tex_rock = tile_hp(a[150:330, 0:170].astype(np.float32), 5)
zone_hull = mask_np.copy(); zone_hull[HULL_EDGE:] = False
zone_rock = mask_np.copy(); zone_rock[:HULL_EDGE] = False
fe_h = cv2.GaussianBlur(zone_hull.astype(np.float32), (0, 0), 5)[..., None]
fe_r = cv2.GaussianBlur(zone_rock.astype(np.float32), (0, 0), 5)[..., None]
out = (a.astype(np.float32) * (1 - fe_h - fe_r)
       + np.clip(lf + tex_hull * 0.85, 0, 255) * fe_h
       + np.clip(lf + tex_rock * 0.9, 0, 255) * fe_r)

# ---- 4. 发射口加光点：白热芯 + 红色柔光 ----
yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
d2 = (yy - EMIT[1]) ** 2 + (xx - EMIT[0]) ** 2
glow = np.exp(-d2 / (2 * 13 ** 2))[..., None] * np.array([255, 235, 215], np.float32) * 0.95
halo = np.exp(-d2 / (2 * 42 ** 2))[..., None] * np.array([255, 90, 60], np.float32) * 0.55
final = np.clip(out + glow + halo, 0, 255).astype(np.uint8)

Image.fromarray(final).save(f'{ROOT}/cover/panel3_laser_final.png')
print('done')

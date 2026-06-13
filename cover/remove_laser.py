# -*- coding: utf-8 -*-
# 把第三格(激光特写)里的中央激光与落点爆炸修掉，保留核心光环
# 思路: 宽蒙版 + OpenCV 扩散修复打底色(低频) + 从岩壁借高频纹理 + 撒火星
# 输入: cover/boss_art_3panel_v2.png  输出: cover/panel3_v2_clean.png
from PIL import Image, ImageDraw, ImageFilter
import numpy as np
import cv2

ROOT = '/Users/leozhang/一号游戏'
im = Image.open(f'{ROOT}/cover/boss_art_3panel_v2.png').crop((0, 1030, 1024, 1536))
W, H = im.size
a = np.asarray(im).astype(np.uint8)

# ---- 1. 逐行定位激光中线 ----
def fit_x(y):  # 过 (100,589) (480,418) 的直线
    return 589 - (y - 100) * (589 - 418) / 380.0

bright = (a[:, :, 0] > 235) & (a[:, :, 1] > 150) & (a[:, :, 2] > 120)
center = {}
for y in range(55, H):
    fx = fit_x(y)
    lo, hi = max(0, int(fx - 60)), min(W, int(fx + 60))
    xs = np.where(bright[y, lo:hi])[0]
    center[y] = lo + xs.mean() if len(xs) > 3 else fx

CORE = (612, 72)   # 核心圆心
CORE_R = 55        # 这个半径以内的光环保留
HULL_Y = 168       # 这条线以上是船体，以下是岩石背景

# ---- 2. 蒙版（够宽，把激光柔光整条吃进去）----
mask = Image.new('L', (W, H), 0)
md = ImageDraw.Draw(mask)
for y in range(55, H):
    cx = center[y]
    hw = 42 if y < HULL_Y else 85 + (y - HULL_Y) * 35 / (H - HULL_Y)
    md.line([cx - hw, y, cx + hw, y], fill=255, width=1)
md.ellipse([435 - 230, 482 - 95, 435 + 230, 482 + 95], fill=255)   # 落点爆炸
hot = ((a[:, :, 0].astype(int) + a[:, :, 1] + a[:, :, 2]) > 540) & \
      (np.arange(H)[:, None] > 360)
hot_m = Image.fromarray((hot * 255).astype(np.uint8)).filter(ImageFilter.MaxFilter(17))
mask = Image.fromarray(np.maximum(np.asarray(mask), np.asarray(hot_m)))
md = ImageDraw.Draw(mask)
md.ellipse([CORE[0] - CORE_R, CORE[1] - CORE_R, CORE[0] + CORE_R, CORE[1] + CORE_R], fill=0)
md.rectangle([40, 200, 400, 370], fill=0)        # 飞机+尾焰保护区
mask_np = (np.asarray(mask) > 127)
mask255 = (mask_np * 255).astype(np.uint8)

# ---- 3. 打底色：每行采蒙版两侧的真实颜色做横向插值（不会发亮发粉）----
out = a.copy()
src_blur = cv2.GaussianBlur(a.astype(np.float32), (0, 0), 8)

def row_sample(y, x_from, x_to):
    """取 [x_from,x_to) 一段的平均色；避开蒙版、飞机保护区"""
    x_from, x_to = max(0, x_from), min(W, x_to)
    cols = []
    for x in range(x_from, x_to):
        if mask_np[y, x]:
            continue
        if 40 <= x <= 400 and 200 <= y <= 370:   # 飞机保护区不取色
            continue
        cols.append(src_blur[y, x])
    return np.mean(cols, axis=0) if cols else None

lf = src_blur.copy()
for y in range(50, H):
    xs = np.where(mask_np[y])[0]
    if not len(xs):
        continue
    x0, x1 = xs.min(), xs.max()
    cl = row_sample(y, x0 - 80, x0 - 12)
    cr = row_sample(y, x1 + 12, x1 + 80)
    if cl is None and cr is None:
        continue
    if cl is None: cl = cr
    if cr is None: cr = cl
    t = (xs - x0) / max(1, x1 - x0)
    lf[y, xs] = cl[None, :] * (1 - t)[:, None] + cr[None, :] * t[:, None]
# 纵向再揉一遍，去掉行与行之间的条纹
lf = cv2.GaussianBlur(lf, (0, 0), 9)

# ---- 4. 高频纹理从纯岩石区借（左缘中段的岩壁，不含任何机械）----
patch = a[150:330, 0:170].astype(np.float32)
hp = patch - cv2.GaussianBlur(patch, (0, 0), 5)
ph, pw, _ = hp.shape
tex = np.zeros((H, W, 3), np.float32)
rng = np.random.default_rng(3)
for ty in range(0, H, ph):
    for tx in range(0, W, pw):
        t = np.roll(np.roll(hp, int(rng.integers(0, ph)), axis=0),
                    int(rng.integers(0, pw)), axis=1)
        h2, w2 = min(ph, H - ty), min(pw, W - tx)
        tex[ty:ty + h2, tx:tx + w2] = t[:h2, :w2]

rock_zone = mask_np.copy(); rock_zone[:HULL_Y] = False
hull_zone = mask_np.copy(); hull_zone[HULL_Y:] = False
fe_rock = cv2.GaussianBlur(rock_zone.astype(np.float32), (0, 0), 6)[..., None]
fe_hull = cv2.GaussianBlur(hull_zone.astype(np.float32), (0, 0), 4)[..., None]
rebuilt = np.clip(lf + tex * 0.9, 0, 255)
final = (a.astype(np.float32) * (1 - fe_rock - fe_hull)
         + rebuilt * fe_rock + lf * fe_hull)
final = np.clip(final, 0, 255).astype(np.uint8)

# ---- 5. 撒几颗火星，让走廊不显得空 ----
glow = np.zeros((H, W, 3), np.float32)
ys = sorted(rng.integers(HULL_Y + 30, H - 20, 14))
for y in ys:
    cx = center.get(int(y), fit_x(y))
    x = int(cx + rng.integers(-70, 71))
    r = int(rng.integers(2, 6))
    color = np.array([255, 120 + rng.integers(0, 60), 70], np.float32)
    yy, xx = np.mgrid[max(0, y - r * 4):min(H, y + r * 4), max(0, x - r * 4):min(W, x + r * 4)]
    d2 = ((yy - y) ** 2 + (xx - x) ** 2) / (r * r)
    g = np.exp(-d2 * 0.8)[..., None] * color * float(rng.uniform(0.5, 0.95))
    glow[max(0, y - r * 4):min(H, y + r * 4), max(0, x - r * 4):min(W, x + r * 4)] += g
final = np.clip(final.astype(np.float32) + glow, 0, 255).astype(np.uint8)

# ---- 6. 边界轻揉，吃掉接缝 ----
blur = cv2.GaussianBlur(final, (0, 0), 1.6)
fe2 = cv2.GaussianBlur(mask_np.astype(np.float32), (0, 0), 7)[..., None]
final = (final * (1 - fe2 * 0.35) + blur * fe2 * 0.35).astype(np.uint8)

Image.fromarray(final).save(f'{ROOT}/cover/panel3_v2_clean.png')
print('done')

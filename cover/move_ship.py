# -*- coding: utf-8 -*-
# 保留激光版素材：把玩家飞机往左挪，跟激光错开
# 输入: cover/boss_art_3panel_v2.png  输出: cover/panel3_laser_shipmoved.png
from PIL import Image, ImageDraw, ImageFilter
import numpy as np
import cv2

ROOT = '/Users/leozhang/一号游戏'
panel = Image.open(f'{ROOT}/cover/boss_art_3panel_v2.png').crop((0, 1030, 1024, 1536))
W, H = panel.size
a = np.asarray(panel).astype(np.uint8)

# 飞机(含尾焰)所在矩形
BX0, BY0, BX1, BY1 = 88, 242, 396, 408
DX, DY = -85, 6          # 往左挪 85px、微微下移

# ---- 1. 裁出飞机贴片（带羽化边）----
ship = a[BY0:BY1, BX0:BX1].copy()
sh, sw, _ = ship.shape
alpha = np.ones((sh, sw), np.float32)
alpha[:12] = 0; alpha[-12:] = 0; alpha[:, :12] = 0; alpha[:, -12:] = 0
alpha = cv2.GaussianBlur(alpha, (0, 0), 6)

# ---- 2. 原位置补岩石：逐行采两侧颜色 + 借纹理（激光不动）----
mask_np = np.zeros((H, W), bool)
mask_np[BY0:BY1, BX0:BX1] = True
src_blur = cv2.GaussianBlur(a.astype(np.float32), (0, 0), 8)
lf = src_blur.copy()
for y in range(BY0, BY1):
    xs = np.arange(BX0, BX1)
    cl = src_blur[y, max(0, BX0 - 70):BX0 - 12].mean(axis=0)
    cr = src_blur[y, BX1 + 12:min(W, BX1 + 70)].mean(axis=0)
    t = (xs - BX0) / (BX1 - BX0)
    lf[y, xs] = cl[None, :] * (1 - t)[:, None] + cr[None, :] * t[:, None]
lf = cv2.GaussianBlur(lf, (0, 0), 9)

patch = a[150:330, 0:170].astype(np.float32)        # 左缘纯岩壁
hp = patch - cv2.GaussianBlur(patch, (0, 0), 5)
ph, pw, _ = hp.shape
tex = np.zeros((H, W, 3), np.float32)
rng = np.random.default_rng(5)
for ty in range(0, H, ph):
    for tx in range(0, W, pw):
        t = np.roll(np.roll(hp, int(rng.integers(0, ph)), axis=0),
                    int(rng.integers(0, pw)), axis=1)
        h2, w2 = min(ph, H - ty), min(pw, W - tx)
        tex[ty:ty + h2, tx:tx + w2] = t[:h2, :w2]

fe = cv2.GaussianBlur(mask_np.astype(np.float32), (0, 0), 6)[..., None]
rebuilt = np.clip(lf + tex * 0.9, 0, 255)
out = (a.astype(np.float32) * (1 - fe) + rebuilt * fe)

# ---- 3. 把飞机贴回新位置 ----
nx0, ny0 = BX0 + DX, BY0 + DY
# 目标区域（裁掉越界部分）
tx0, ty0 = max(0, nx0), max(0, ny0)
sx0, sy0 = tx0 - nx0, ty0 - ny0
tx1, ty1 = min(W, nx0 + sw), min(H, ny0 + sh)
seg_a = alpha[sy0:sy0 + ty1 - ty0, sx0:sx0 + tx1 - tx0][..., None]
seg_s = ship[sy0:sy0 + ty1 - ty0, sx0:sx0 + tx1 - tx0].astype(np.float32)
out[ty0:ty1, tx0:tx1] = out[ty0:ty1, tx0:tx1] * (1 - seg_a) + seg_s * seg_a

final = np.clip(out, 0, 255).astype(np.uint8)
Image.fromarray(final).save(f'{ROOT}/cover/panel3_laser_shipmoved.png')
print('done')

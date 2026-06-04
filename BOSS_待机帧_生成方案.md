# Boss「锯齿战车」待机动画 —— 逐帧帧生成方案

> 目标：做一个**循环播放的"待机"动画**（boss 停在原地，活着、在喘气、灯在闪），
> 让这台 boss 不像一张死图片。
> 方式：**AI 直接出序列帧 / 精灵表**，我负责导入 Godot 拼成循环动画。

---

## ★ 这条路最大的坑：帧与帧"抖"

普通图像模型一张张画，每张的细节（铆钉、线条、零件位置）都会乱跳，连起来就"抖"得像噪点。
所以**待机动画的设计原则只有一条**：

> **让"变化"尽量小、尽量只动那些'抖了也看不出来'的东西。**

待机不需要大动作。我们只动下面这些**"耐抖"**的元素，整机轮廓、零件位置**保持不动**：

| 动的东西 | 抖不抖得出来 | 建议 |
|---|---|---|
| 🔴 所有红灯/红条/独眼 **一起明灭呼吸** | 完全不怕抖 | **必做**（最出效果） |
| 整机**极轻微上下浮动**（1~2%，像怠速震动） | 不怕 | 必做 |
| 天线**轻微摆动** | 不怕 | 可做 |
| 炮口/排气口 **热浪微光闪动** | 不怕 | 可做 |
| 加特林炮管 / 电锯 **缓慢微转** | **容易抖** | 先别强求，循环跑通再说 |

---

## ★ 最关键技巧：尽量"一次出全部帧"

帧间一致性最好的办法，是**让所有帧在同一次生成里产生**（同一次 = 同一套细节）：

- **首选：让 AI 直接出一张"精灵表(sprite sheet)"**——一张大图里排好 N 格，每格是一帧。
  因为是一次画出来的，风格最统一。我来负责把它切成单帧。
- 如果你的工具支持 **img2img / 局部重绘 / 固定种子(seed)**：
  用 `boss_idle_placeholder.png` 当**底图**，每帧只做**很小的改动**（改变强度/denoise 调低，比如 0.2~0.35），这样每帧都"贴着原图改"，不会乱跳。

**每次生成都附上底图：`boss_idle_placeholder.png`（已抠成透明底的整只 boss）。**

---

## ★ 硬性规格（每帧都要满足，否则没法拼成动画）

1. **画布尺寸完全一样**（建议 `1024×1024` 正方形；精灵表则每格等大）。
2. **boss 在每帧里的位置、大小、角度完全一致**——只有上面那几样"耐抖元素"在动，轮廓别漂。
3. **透明背景 PNG**；做不到就**纯品红 `#FF00FF`** 背景，我来抠。
4. **不要画地面投影**（影子游戏里另加）。
5. **能循环**：最后一帧要能平滑接回第一帧（用"正弦往复"的节奏：灯由暗→亮→暗，机身由低→高→低，一个来回正好一轮）。
6. **帧数**：先做 **6~8 帧** 就够（待机不用多）。

---

## ★ 给 AI 的提示词

### 方案一（推荐）：一次出精灵表
附上 `boss_idle_placeholder.png`，提示词：

```
A sprite sheet of the SAME mecha tank boss (from the attached reference image),
arranged in a 4x2 grid = 8 frames, for a looping idle animation.
Across the 8 frames, keep the boss IDENTICAL in pose, scale, position, framing and
every mechanical detail — ONLY these change subtly and loopably:
- all the red lights / red strips / the central red eye gently pulse brighter then dimmer
- the whole body bobs up and down by a tiny amount (engine idle vibration)
- the antennae sway slightly
Each grid cell same size, boss centered identically in every cell, transparent
background, NO ground shadow. Frame 8 must flow smoothly back into frame 1.
Crisp, high detail, consistent lighting.
```

### 方案二：一帧一帧出（用 img2img / 固定种子）
以 `boss_idle_placeholder.png` 为底图，**改动强度调到很低**，逐帧给"灯亮度 + 机身高度"的小指令，例如：

- 第1帧：`...red lights at dim, body at lowest position...`
- 第3帧：`...red lights medium, body slightly raised...`
- 第5帧：`...red lights at brightest, body at highest...`
- 第7帧：`...red lights medium, body lowering...`
（中间帧插值，整体走一个"暗→亮→暗 / 低→高→低"的来回）

---

## ★ 交给我的方式（二选一）

- **A. 单帧 PNG**：放进一个文件夹 `boss_idle_frames/`，命名 `boss_idle_01.png ~ boss_idle_08.png`。
- **B. 一张精灵表**：直接给我那张大图（告诉我是几行几列），我来切。

我拿到后会：导入 → 建 `idle` 循环动画 → 替换掉现在的占位图 → 在游戏里跑起来。

---

## ★ 退路（万一还是抖得厉害）

`AI 直接出帧`对这种超复杂机甲，抖动风险确实高。如果出来连不顺：
**改用"图生视频→抽帧"**——把 `boss_idle_placeholder.png` 丢给 AI 视频模型生成 2~3 秒待机循环，
我从视频里抽 8~12 帧。视频天生帧间连续，几乎不抖。到时说一声我给你换这套方案。

---

## ★ 发我之前自检
- [ ] 每帧画布尺寸一样、boss 大小位置一致（没漂）？
- [ ] 只有"灯/微浮动/天线"在动，轮廓零件没乱跳？
- [ ] 背景透明 / 或纯品红，没自带影子？
- [ ] 6~8 帧，且能首尾相接循环？

shader_type canvas_item;
// Boss 隐形护盾：平时全透明，只在"最近被击打的几个点"附近局部点亮护盾贴图，并逐渐淡掉。
// boss.gd 每帧把命中点(UV)和强度传进来：hits[]=命中位置(纹理UV)，strengths[]=各点当前亮度(0~1)。

const int MAX_HITS = 8;
uniform vec2 hits[MAX_HITS];           // 命中点（纹理UV坐标）
uniform float strengths[MAX_HITS];     // 各命中点当前亮度(0灭~1最亮)，由 boss.gd 逐帧衰减
uniform float reveal_radius = 0.18;    // 每个命中点点亮的半径(UV)，越大亮的范围越广
uniform float glow = 1.5;              // 点亮处的提亮倍数
uniform float aspect = 1.333;          // 贴图宽/高，用来把点亮区域校正成圆形
uniform float base_alpha = 0.0;        // 常显底透明度(0=平时完全隐身)
uniform float hit_opacity = 1.8;       // 命中处不透明度倍数：越大被打中时那块越实越清楚

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float reveal = 0.0;
	for (int i = 0; i < MAX_HITS; i++) {
		vec2 d = UV - hits[i];
		d.x *= aspect;                                  // 校正成圆形(贴图是扁的)
		float f = clamp(1.0 - length(d) / reveal_radius, 0.0, 1.0);
		f = f * f;                                      // 柔化：中心亮、边缘快速淡出
		reveal = max(reveal, f * strengths[i]);
	}
	// 平时隐身(base_alpha=0)；命中处按 reveal 显形，并乘 hit_opacity 提高不透明度让它更实
	float vis = clamp(base_alpha + reveal, 0.0, 1.0);
	COLOR = vec4(tex.rgb * glow, clamp(tex.a * vis * hit_opacity, 0.0, 1.0));
}

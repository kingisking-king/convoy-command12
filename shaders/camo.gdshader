shader_type spatial;

varying vec3 wpos;

uniform vec4 color_a : source_color = vec4(0.30, 0.36, 0.18, 1.0);
uniform vec4 color_b : source_color = vec4(0.16, 0.20, 0.10, 1.0);
uniform vec4 color_c : source_color = vec4(0.48, 0.40, 0.24, 1.0);
uniform float scale = 0.46;
uniform float rough : hint_range(0.0, 1.0) = 0.76;
uniform float metal : hint_range(0.0, 1.0) = 0.07;

float hash(vec3 p) {
	p = fract(p * 0.3183099 + vec3(0.11, 0.17, 0.13));
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float vnoise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(mix(hash(i), hash(i + vec3(1.0, 0.0, 0.0)), f.x),
			mix(hash(i + vec3(0.0, 1.0, 0.0)), hash(i + vec3(1.0, 1.0, 0.0)), f.x), f.y),
		mix(mix(hash(i + vec3(0.0, 0.0, 1.0)), hash(i + vec3(1.0, 0.0, 1.0)), f.x),
			mix(hash(i + vec3(0.0, 1.0, 1.0)), hash(i + vec3(1.0, 1.0, 1.0)), f.x), f.y),
		f.z);
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float n = vnoise(wpos * scale);
	float n2 = vnoise(wpos * scale * 2.2 + vec3(5.1, 1.4, 8.2));
	vec3 col = mix(color_a.rgb, color_b.rgb, smoothstep(0.38, 0.62, n));
	col = mix(col, color_c.rgb, smoothstep(0.55, 0.82, n2) * 0.82);
	float grit = vnoise(wpos * 5.5 + vec3(2.0, 0.4, 1.0));
	col *= mix(0.84, 1.05, grit);
	float panel = step(0.94, fract(wpos.x * 1.45)) + step(0.95, fract(wpos.z * 1.15));
	col *= 1.0 - clamp(panel, 0.0, 1.0) * 0.09;
	ALBEDO = col;
	ROUGHNESS = rough;
	METALLIC = metal;
}

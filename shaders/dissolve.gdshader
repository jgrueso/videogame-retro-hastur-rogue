shader_type canvas_item;

uniform float progress : hint_range(0.0, 1.1) = 0.0;
uniform vec4 edge_color : source_color = vec4(1.0, 0.45, 0.08, 1.0);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x),
		f.y
	);
}

void fragment() {
	float n = noise(UV * 5.5) * 0.6 + noise(UV * 11.0) * 0.4;
	if (n < progress) {
		discard;
	}
	float edge = smoothstep(progress, progress + 0.12, n);
	COLOR = mix(edge_color, COLOR, edge);
}

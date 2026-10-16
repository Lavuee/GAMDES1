shader_type canvas_item;
// River surface: per-row ripple offsets and twinkling reflections.
// grain = texels per art pixel; ripple_pixels is in texels.

uniform float grain = 1.0;
uniform float ripple_speed = 1.6;
uniform float ripple_pixels = 1.0;
uniform float sparkle_rate = 5.0;
uniform float sparkle_amount : hint_range(0.0, 1.0) = 0.012;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

void fragment() {
	vec2 px = floor(UV / TEXTURE_PIXEL_SIZE / grain);
	float shift = round(sin(px.y * 0.9 + TIME * ripple_speed) * ripple_pixels);
	vec4 c = texture(TEXTURE, UV + vec2(shift, 0.0) * TEXTURE_PIXEL_SIZE);
	float glint = step(1.0 - sparkle_amount, hash(px + floor(TIME * sparkle_rate)));
	c.rgb = mix(c.rgb, vec3(1.0), glint * smoothstep(0.55, 0.8, c.b) * 0.8);
	COLOR = c;
}

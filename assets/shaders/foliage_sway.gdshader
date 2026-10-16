shader_type canvas_item;
// Leaves, vines and plants sway by whole texels; stone and other non-green
// pixels stay put. grain = texels per art pixel; amplitude is in texels.

uniform float grain = 1.0;
uniform float amplitude = 1.0;
uniform float speed = 1.3;
uniform float wave_length = 0.06;

float leafy(vec4 c) {
	return step(0.03, c.g - max(c.r, c.b)) * step(0.5, c.a);
}

void fragment() {
	vec2 px = floor(UV / TEXTURE_PIXEL_SIZE / grain);
	vec4 base = texture(TEXTURE, UV);
	float shift = round(sin(TIME * speed + px.x * wave_length + px.y * 0.2) * amplitude);
	vec4 moved = texture(TEXTURE, UV + vec2(shift, 0.0) * TEXTURE_PIXEL_SIZE);
	vec4 c = base;
	if (leafy(moved) > 0.5) {
		c = moved;
	} else if (leafy(base) > 0.5 && moved.a < 0.5) {
		c = moved;
	}
	COLOR = c;
}

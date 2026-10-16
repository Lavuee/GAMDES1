shader_type canvas_item;
// Animated falling-water streaks on the waterfall pixels of a layer.
// Phases run on the art's pixel grid (grain texels per art pixel) so the
// motion stays pixel-crisp.

uniform float grain = 1.0;
uniform float speed = 1.4;
uniform float streak_density : hint_range(0.0, 1.0) = 0.3;
uniform vec3 highlight = vec3(0.25, 0.3, 0.32);

float hash(float n) { return fract(sin(n * 12.9898) * 43758.5453); }

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	vec2 px = floor(UV / TEXTURE_PIXEL_SIZE / grain);
	// Falling water is bright cyan-white; shadowed blue rock is darker.
	float bright = (c.r + c.g + c.b) / 3.0;
	float water = step(0.72, bright) * step(c.r + 0.1, c.b) * step(0.7, c.g) * step(0.5, c.a);
	float t = fract(px.y * 0.14 - TIME * speed + hash(px.x));
	float streak = step(1.0 - streak_density, t);
	c.rgb += highlight * streak * water;
	COLOR = c;
}

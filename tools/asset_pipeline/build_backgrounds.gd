extends SceneTree
## Cuts the parallax layers out of the reference sheet, removes the baked
## checkerboard, makes layers horizontally tileable and writes PNGs.
## Usage: godot --headless --path <proj> --script build_backgrounds.gd -- <ref.png> <out_dir>
## The reference sheet lives next to this script: background_reference.png.

const X0 := 167          # first content column right of the label panel
const X1 := 1981         # exclusive
const STRIPS := {
	"sky": [320, 381],
	"mountains": [383, 444],
	"floating_islands": [446, 510],
	"forest": [511, 569],
	"waterfalls": [570, 627],
	"ruins_vines": [629, 679],
	"river": [732, 790],
}

var src: Image
var out_dir := ""


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	src = Image.load_from_file(args[0])
	src.convert(Image.FORMAT_RGBA8)
	out_dir = args[1]
	DirAccess.make_dir_recursive_absolute(out_dir)

	_build_sky_and_clouds()
	_build_silhouette("mountains", 0.0)
	_build_silhouette("forest", 0.0)
	_build_sparse("floating_islands", true)
	_build_sparse("waterfalls")
	_build_sparse("ruins_vines")
	_build_river()
	_build_panorama()
	_build_fx_textures()
	print("done")
	quit()


## Strip without its 1px anti-aliased border rows.
func _strip(name: String) -> Image:
	var r: Array = STRIPS[name]
	return src.get_region(Rect2i(X0, r[0] + 1, X1 - X0, r[1] - r[0] - 2))


func _save(img: Image, name: String) -> void:
	img.save_png(out_dir.path_join(name + ".png"))
	print(name, " ", img.get_size())


# ---------------------------------------------------------------------------
# Checkerboard removal
# ---------------------------------------------------------------------------

## The baked checkerboard is a pale, low-saturation blue-grey.
func _is_checker(c: Color) -> bool:
	return c.v > 0.80 and c.s < 0.20


## Flood-fills from every border pixel through checker-like pixels and makes
## them transparent; pixels enclosed by the art survive.
func _remove_checker(img: Image) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var seen := PackedByteArray()
	seen.resize(w * h)
	var stack: Array[int] = []
	for x in w:
		stack.append(x)
		stack.append(x + (h - 1) * w)
	for y in h:
		stack.append(y * w)
		stack.append(w - 1 + y * w)
	while not stack.is_empty():
		var i: int = stack.pop_back()
		if seen[i]:
			continue
		seen[i] = 1
		var x := i % w
		var y := i / w
		if not _is_checker(img.get_pixel(x, y)):
			continue
		img.set_pixel(x, y, Color(0, 0, 0, 0))
		if x > 0: stack.append(i - 1)
		if x < w - 1: stack.append(i + 1)
		if y > 0: stack.append(i - w)
		if y < h - 1: stack.append(i + w)
	# Halo: pale fringe pixels touching transparency.
	for pass_i in 2:
		var kill: Array[Vector2i] = []
		for y in h:
			for x in w:
				var c := img.get_pixel(x, y)
				if c.a == 0.0 or not (c.v > 0.72 and c.s < 0.28):
					continue
				if _touches_clear(img, x, y):
					kill.append(Vector2i(x, y))
		for p in kill:
			img.set_pixelv(p, Color(0, 0, 0, 0))
	_remove_enclosed_checker(img, 14)
	_remove_specks(img, 10)


## Checker patches fully enclosed by art (gaps between pillars, under arches)
## are unreachable by the border flood fill; large pale patches are never
## real art highlights, so clear those too.
func _remove_enclosed_checker(img: Image, min_size: int) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var seen := PackedByteArray()
	seen.resize(w * h)
	for start in w * h:
		if seen[start]:
			continue
		var c := img.get_pixel(start % w, start / w)
		if c.a == 0.0 or not _is_checker(c):
			continue
		var comp: Array[int] = []
		var stack: Array[int] = [start]
		seen[start] = 1
		while not stack.is_empty():
			var i: int = stack.pop_back()
			comp.append(i)
			var x := i % w
			var y := i / w
			for n in [i - 1 if x > 0 else -1, i + 1 if x < w - 1 else -1, i - w if y > 0 else -1, i + w if y < h - 1 else -1]:
				if n >= 0 and not seen[n]:
					var nc := img.get_pixel(n % w, n / w)
					if nc.a > 0.0 and _is_checker(nc):
						seen[n] = 1
						stack.append(n)
		if comp.size() >= min_size:
			for i in comp:
				img.set_pixel(i % w, i / w, Color(0, 0, 0, 0))


## Pale cloud / mist wisps around the islands carry checkerboard residue
## and turn to speckle when scaled. Peel them away from the transparent
## area; saturated waterfall water and the island rock stop the fill.
func _remove_mist(img: Image) -> void:
	var w := img.get_width()
	var h := img.get_height()
	for pass_i in 40:
		var kill: Array[Vector2i] = []
		for y in h:
			for x in w:
				var c := img.get_pixel(x, y)
				if c.a > 0.0 and c.v > 0.7 and c.s < 0.32 and _touches_clear(img, x, y):
					kill.append(Vector2i(x, y))
		if kill.is_empty():
			break
		for p in kill:
			img.set_pixelv(p, Color(0, 0, 0, 0))
	_remove_specks(img, 12)


func _touches_clear(img: Image, x: int, y: int) -> bool:
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var p: Vector2i = Vector2i(x, y) + d
		if p.x < 0 or p.y < 0 or p.x >= img.get_width() or p.y >= img.get_height():
			continue
		if img.get_pixelv(p).a == 0.0:
			return true
	return false


## Deletes opaque islands smaller than min_size pixels (checker residue).
func _remove_specks(img: Image, min_size: int) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var label := PackedInt32Array()
	label.resize(w * h)
	for start in w * h:
		if label[start] != 0 or img.get_pixel(start % w, start / w).a == 0.0:
			continue
		var comp: Array[int] = []
		var stack: Array[int] = [start]
		label[start] = 1
		while not stack.is_empty():
			var i: int = stack.pop_back()
			comp.append(i)
			var x := i % w
			var y := i / w
			for n in [i - 1 if x > 0 else -1, i + 1 if x < w - 1 else -1, i - w if y > 0 else -1, i + w if y < h - 1 else -1]:
				if n >= 0 and label[n] == 0 and img.get_pixel(n % w, n / w).a > 0.0:
					label[n] = 1
					stack.append(n)
		if comp.size() < min_size:
			for i in comp:
				img.set_pixel(i % w, i / w, Color(0, 0, 0, 0))


# ---------------------------------------------------------------------------
# Tiling helpers
# ---------------------------------------------------------------------------

## Crossfades the last `blend` columns into the first ones and drops them, so
## the result wraps seamlessly.
func _make_tileable(img: Image, blend: int) -> Image:
	var w := img.get_width()
	var h := img.get_height()
	var out := img.get_region(Rect2i(0, 0, w - blend, h))
	for x in blend:
		var t := float(x) / float(blend)
		for y in h:
			var a := img.get_pixel(w - blend + x, y)
			var b := img.get_pixel(x, y)
			# Hard switch for alpha-dominant pixels avoids ghost halos.
			var c := a.lerp(b, t)
			if a.a < 0.5 or b.a < 0.5:
				c = a if t < 0.5 else b
			out.set_pixel(x, y, c)
	return out


func _column_count(img: Image, x: int) -> int:
	var n := 0
	for y in img.get_height():
		if img.get_pixel(x, y).a > 0.0:
			n += 1
	return n


## Crops sparse art at the emptiest column near each end and clears those
## seam columns, so the wrap seam falls in a gap.
func _crop_to_gaps(img: Image) -> Image:
	var w := img.get_width()
	var span := w / 8
	var left := 0
	var best := 1 << 30
	for x in span:
		var n := _column_count(img, x)
		if n < best:
			best = n
			left = x
	var right := w - 1
	best = 1 << 30
	for x in range(w - 1, w - 1 - span, -1):
		var n := _column_count(img, x)
		if n < best:
			best = n
			right = x
	var out := img.get_region(Rect2i(left, 0, right - left + 1, img.get_height()))
	for y in out.get_height():
		out.set_pixel(0, y, Color(0, 0, 0, 0))
		out.set_pixel(out.get_width() - 1, y, Color(0, 0, 0, 0))
	return out


# ---------------------------------------------------------------------------
# Layers
# ---------------------------------------------------------------------------

func _build_sky_and_clouds() -> void:
	var sky := _strip("sky")
	var w := sky.get_width()
	var h := sky.get_height()
	# Per-row sky colour = median-ish: average of the bluest half of the row.
	var row_col: Array[Color] = []
	for y in h:
		var acc := Color(0, 0, 0, 0)
		var n := 0
		for x in range(0, w, 2):
			var c := sky.get_pixel(x, y)
			if c.s > 0.35:
				acc += c
				n += 1
		row_col.append(acc / float(max(n, 1)) if n > 0 else Color(0.55, 0.8, 1.0))
	for y in h:
		row_col[y].a = 1.0

	# Sun: bounding box of warm pixels in the strip.
	var sun_rect := Rect2i()
	for y in h:
		for x in w:
			var c := sky.get_pixel(x, y)
			if c.r > 0.9 and c.g > 0.82 and c.b < 0.72:
				sun_rect = Rect2i(x, y, 1, 1) if sun_rect.size == Vector2i.ZERO else sun_rect.expand(Vector2i(x, y)).expand(Vector2i(x + 1, y + 1))
	sun_rect = sun_rect.grow(3)
	var sun_exclude := sun_rect.grow(10)

	var clouds := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		var base := row_col[y]
		# Clouds at the bottom of the strip are cut flat: fade them out.
		var fade := clampf(float(h - 1 - y) / 8.0, 0.0, 1.0)
		for x in w:
			if sun_exclude.has_point(Vector2i(x, y)):
				continue
			var c := sky.get_pixel(x, y)
			var whiteness := clampf((c.v - base.v) * 2.5 + (base.s - c.s) * 2.0, 0.0, 1.0)
			if whiteness > 0.12:
				var a := clampf(whiteness * 1.6, 0.0, 1.0) * fade
				if a > 0.05:
					clouds.set_pixel(x, y, Color(c.r, c.g, c.b, a))
	# The strip cuts its lowest clouds off flat; carve puffy scalloped
	# undersides so no straight edge shows in game.
	for x in w:
		var lift := 4.0 + 4.0 * absf(sin(x * 0.07)) + 3.0 * absf(sin(x * 0.19 + 1.3))
		for y in range(h - int(lift), h):
			clouds.set_pixel(x, y, Color(0, 0, 0, 0))
	_remove_specks(clouds, 6)
	_save(_make_tileable(clouds, 80), "clouds")

	# Sky (drawn at 2x in the scene, matching the layers' art-pixel grid):
	# smooth gradient from deep blue to the strip's horizon colour, ordered-
	# dithered between fine colour steps so it never bands, plus a pixel-art
	# sun with a stepped glow where the light shafts come from.
	const SKY_W := 480
	const SKY_H := 270
	const BAYER := [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5]
	const LEVELS := 40.0
	var top_col := Color(0.09, 0.32, 0.78)
	var horizon := row_col[h - 1].lerp(Color(0.85, 0.94, 1.0), 0.35)
	var sun_centre := Vector2(316.5, 34.5)
	var gradient := Image.create(SKY_W, SKY_H, false, Image.FORMAT_RGBA8)
	for y in SKY_H:
		var t := float(y) / float(SKY_H - 1)
		var base := top_col.lerp(row_col[0], smoothstep(0.0, 0.45, t)).lerp(horizon, smoothstep(0.35, 1.0, t))
		for x in SKY_W:
			# Warm glow around the sun.
			var d := Vector2(x, y).distance_to(sun_centre)
			var c := base.lerp(Color(1.0, 0.95, 0.78), clampf(1.0 - d / 105.0, 0.0, 1.0) * 0.45)
			var threshold: float = (BAYER[(x % 4) + (y % 4) * 4] + 0.5) / 16.0
			c = Color(
				floorf(c.r * LEVELS + threshold) / LEVELS,
				floorf(c.g * LEVELS + threshold) / LEVELS,
				floorf(c.b * LEVELS + threshold) / LEVELS)
			gradient.set_pixel(x, y, c)
	_draw_sun(gradient, sun_centre)
	_save(gradient, "sky")


## Pixel-art sun: bright core, warm rim, two dithered halo rings.
func _draw_sun(img: Image, centre: Vector2) -> void:
	const R := 16.0
	for y in range(int(centre.y - R - 11), int(centre.y + R + 12)):
		for x in range(int(centre.x - R - 11), int(centre.x + R + 12)):
			if x < 0 or y < 0 or x >= img.get_width() or y >= img.get_height():
				continue
			var d := Vector2(x, y).distance_to(centre)
			var dst := img.get_pixel(x, y)
			if d <= R - 2.0:
				# Core with a soft highlight toward the upper left.
				var hl := clampf(1.0 - Vector2(x, y).distance_to(centre + Vector2(-3, -3)) / R, 0.0, 1.0)
				img.set_pixel(x, y, Color(1.0, 0.94, 0.7).lerp(Color(1.0, 1.0, 0.93), snappedf(hl, 0.5)))
			elif d <= R:
				img.set_pixel(x, y, Color(1.0, 0.84, 0.5))
			elif d <= R + 4.0:
				img.set_pixel(x, y, dst.lerp(Color(1.0, 0.95, 0.75), 0.55))
			elif d <= R + 10.0 and (x + y) % 2 == 0:
				img.set_pixel(x, y, dst.lerp(Color(1.0, 0.95, 0.8), 0.3))


func _build_silhouette(name: String, _unused: float) -> void:
	var img := _strip(name)
	_remove_checker(img)
	_save(_make_tileable(img, 96), name)


func _build_sparse(name: String, strip_mist := false) -> void:
	var img := _strip(name)
	_remove_checker(img)
	if strip_mist:
		_remove_mist(img)
	_save(_crop_to_gaps(img), name)


func _build_river() -> void:
	var img := _strip("river")
	_save(_make_tileable(img, 96), "river")


## Full combined view, used as the title-screen backdrop.
func _build_panorama() -> void:
	var left := 0
	while src.get_pixel(left, 300).get_luminance() < 0.15:
		left += 1
	var img := src.get_region(Rect2i(left, 0, src.get_width() - left, 317))
	_save(img, "panorama")


# ---------------------------------------------------------------------------
# FX textures (the reference particle strip is too faint to cut out)
# ---------------------------------------------------------------------------

func _build_fx_textures() -> void:
	# 4-point pixel sparkle, 9x9.
	var sparkle := Image.create(9, 9, false, Image.FORMAT_RGBA8)
	for i in 9:
		var d := absi(i - 4)
		var a := 1.0 - d * 0.22
		sparkle.set_pixel(4, i, Color(1, 1, 1, a))
		sparkle.set_pixel(i, 4, Color(1, 1, 1, a))
	for d in [Vector2i(3, 3), Vector2i(5, 3), Vector2i(3, 5), Vector2i(5, 5)]:
		sparkle.set_pixelv(d, Color(1, 1, 1, 0.45))
	_save(sparkle, "sparkle")

	# Soft round glow, 32x32, stepped falloff for a pixel-art look.
	var glow := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	for y in 32:
		for x in 32:
			var dist := Vector2(x + 0.5 - 16.0, y + 0.5 - 16.0).length() / 16.0
			var a := clampf(1.0 - dist, 0.0, 1.0)
			a = snappedf(a * a, 0.125)
			glow.set_pixel(x, y, Color(1, 1, 1, a))
	_save(glow, "glow")

	# Light shaft, 48x180, fades toward the bottom and both sides.
	var ray := Image.create(48, 180, false, Image.FORMAT_RGBA8)
	for y in 180:
		for x in 48:
			var side := 1.0 - absf((x + 0.5) / 24.0 - 1.0)
			var a := side * (1.0 - float(y) / 180.0) * 0.55
			ray.set_pixel(x, y, Color(1.0, 0.97, 0.82, snappedf(a, 0.05)))
	_save(ray, "light_ray")

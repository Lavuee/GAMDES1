extends SceneTree
## Second pass over the layers cut by build_backgrounds.gd:
##   1. unsharp-mask sharpening (the reference layers are only ~60 px tall,
##      so local contrast is what reads as detail),
##   2. palette cleanup: k-means colour quantisation (removes the compression
##      speckle of the AI reference) + a single-pixel noise filter,
##   3. optional atmospheric haze toward the sky colour for far layers,
##   4. Scale2x / Scale3x upscale: smooth pixel-art diagonals instead of
##      nearest-neighbour stair steps. Scenes then draw layers at scale 1.
## Usage: godot --headless --path . --script <abs>/enhance_backgrounds.gd -- <in_dir> <out_dir> [layer ...]

## layer: [palette size, haze amount, alpha levels, upscale factor, sharpen]
## In-game layers use 2x: 3x magnified the low-res source into blur.
const LAYERS := {
	"clouds": [24, 0.0, 1, 2, 0.3],
	"mountains": [64, 0.22, 1, 2, 0.6],
	"floating_islands": [72, 0.12, 1, 2, 0.7],
	"forest": [96, 0.1, 1, 2, 0.8],
	"waterfalls": [96, 0.04, 1, 2, 0.8],
	"river": [80, 0.0, 1, 2, 0.5],
	"ruins_vines": [96, 0.0, 1, 2, 0.9],
	# Title-screen backdrop (opaque); the menu scales it down with filtering.
	"panorama": [160, 0.0, 1, 3, 0.5],
}
## Aerial-perspective haze: the further back a layer, the more it fades
## toward this pale sky colour (layers are listed back to front).
const HAZE := Color(0.7, 0.85, 0.98)


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var only := args.slice(2)
	DirAccess.make_dir_recursive_absolute(args[1])
	for layer: String in LAYERS:
		if not only.is_empty() and not (layer in only):
			continue
		var t0 := Time.get_ticks_msec()
		var img := Image.load_from_file(args[0].path_join(layer + ".png"))
		img.convert(Image.FORMAT_RGBA8)
		var cfg: Array = LAYERS[layer]
		_sharpen(img, cfg[4])
		var out := _enhance(img, cfg[0], cfg[1], cfg[2], cfg[3])
		out.save_png(args[1].path_join(layer + ".png"))
		print(layer, " ", img.get_size(), " -> ", out.get_size(), "  ", Time.get_ticks_msec() - t0, " ms")
	quit()


## Unsharp mask on opaque pixels: c + amount * (c - 3x3 average of the
## opaque neighbourhood). Edges against transparency are left alone.
func _sharpen(img: Image, amount: float) -> void:
	if amount <= 0.0:
		return
	var src := img.duplicate() as Image
	for y in range(1, img.get_height() - 1):
		for x in range(1, img.get_width() - 1):
			var c := src.get_pixel(x, y)
			if c.a < 0.5:
				continue
			var sum := Color(0, 0, 0, 0)
			var n := 0
			for dy in [-1, 0, 1]:
				for dx in [-1, 0, 1]:
					var q := src.get_pixel(x + dx, y + dy)
					if q.a >= 0.5:
						sum += q
						n += 1
			var avg := sum / n
			var out := Color(
				clampf(c.r + amount * (c.r - avg.r), 0.0, 1.0),
				clampf(c.g + amount * (c.g - avg.g), 0.0, 1.0),
				clampf(c.b + amount * (c.b - avg.b), 0.0, 1.0), c.a)
			img.set_pixel(x, y, out)


func _enhance(img: Image, k: int, haze: float, alpha_levels: int, factor: int) -> Image:
	var w := img.get_width()
	var h := img.get_height()
	var n := w * h
	var data := img.get_data()

	# Alpha: binary for solid art, a few steps for soft clouds.
	var alpha := PackedFloat32Array()
	alpha.resize(n)
	for i in n:
		var a := data[i * 4 + 3] / 255.0
		if alpha_levels <= 1:
			a = 1.0 if a >= 0.5 else 0.0
		else:
			a = roundf(a * alpha_levels) / alpha_levels
		alpha[i] = a

	# k-means on a sample of opaque pixels.
	var sample := PackedVector3Array()
	var step := maxi(1, n / 8000)
	for i in range(0, n, step):
		if alpha[i] > 0.0:
			sample.append(Vector3(data[i * 4], data[i * 4 + 1], data[i * 4 + 2]) / 255.0)
	var centres := PackedVector3Array()
	for c in k:
		centres.append(sample[int(float(c) / k * sample.size())])
	for iteration in 10:
		var sums := PackedVector3Array()
		sums.resize(k)
		var counts := PackedInt32Array()
		counts.resize(k)
		for p in sample:
			var best := _nearest(centres, p)
			sums[best] += p
			counts[best] += 1
		for c in k:
			if counts[c] > 0:
				centres[c] = sums[c] / counts[c]

	# Assign every pixel to a palette index (-1 = transparent).
	var index := PackedInt32Array()
	index.resize(n)
	for i in n:
		if alpha[i] == 0.0:
			index[i] = -1
		else:
			index[i] = _nearest(centres, Vector3(data[i * 4], data[i * 4 + 1], data[i * 4 + 2]) / 255.0)

	# Single-pixel noise: a pixel unlike all 4 neighbours takes the colour
	# that at least 3 of them share.
	var cleaned := index.duplicate()
	for y in range(1, h - 1):
		for x in range(1, w - 1):
			var i := x + y * w
			var e := index[i]
			var nb := [index[i - 1], index[i + 1], index[i - w], index[i + w]]
			if e in nb:
				continue
			for cand in nb:
				if nb.count(cand) >= 3:
					cleaned[i] = cand
					break

	# Edge cleanup: fill pinholes (transparent with 3+ opaque neighbours)
	# and drop lone pixels (opaque with at most 1 opaque neighbour).
	for pass_i in 2:
		var src := cleaned.duplicate()
		for y in range(1, h - 1):
			for x in range(1, w - 1):
				var i := x + y * w
				var nb := [src[i - 1], src[i + 1], src[i - w], src[i + w]]
				var opaque := 4 - nb.count(-1)
				if src[i] < 0 and opaque >= 3:
					for cand in nb:
						if cand >= 0:
							cleaned[i] = cand
							alpha[i] = maxf(alpha[i - 1], maxf(alpha[i + 1], maxf(alpha[i - w], alpha[i + w])))
							break
				elif src[i] >= 0 and opaque <= 1:
					cleaned[i] = -1

	# Palette colours with haze applied.
	var palette: Array[Color] = []
	for c in centres:
		palette.append(Color(c.x, c.y, c.z).lerp(HAZE, haze))

	# Pack (index, alpha) into one comparable key per pixel for Scale3x.
	var key := PackedInt32Array()
	key.resize(n)
	for i in n:
		key[i] = -1 if cleaned[i] < 0 else cleaned[i] * 16 + int(alpha[i] * alpha_levels)
	if factor == 2:
		return _scale2x(key, w, h, palette, alpha_levels)
	return _scale3x(key, w, h, palette, alpha_levels)


func _nearest(centres: PackedVector3Array, p: Vector3) -> int:
	var best := 0
	var best_d := INF
	for c in centres.size():
		var d := centres[c].distance_squared_to(p)
		if d < best_d:
			best_d = d
			best = c
	return best


func _colour(k: int, palette: Array[Color], alpha_levels: int) -> Color:
	if k < 0:
		return Color(0, 0, 0, 0)
	var c := palette[k / 16]
	c.a = float(k % 16) / alpha_levels
	return c


## Scale2x (EPX).
func _scale2x(key: PackedInt32Array, w: int, h: int, palette: Array[Color], alpha_levels: int) -> Image:
	var out := Image.create(w * 2, h * 2, false, Image.FORMAT_RGBA8)
	for y in h:
		var ym := maxi(y - 1, 0)
		var yp := mini(y + 1, h - 1)
		for x in w:
			var B := key[x + ym * w]
			var D := key[maxi(x - 1, 0) + y * w]
			var E := key[x + y * w]
			var F := key[mini(x + 1, w - 1) + y * w]
			var H := key[x + yp * w]
			var e := [E, E, E, E]
			if B != H and D != F:
				e[0] = D if D == B else E
				e[1] = F if B == F else E
				e[2] = D if D == H else E
				e[3] = F if H == F else E
			for j in 4:
				if e[j] >= 0:
					out.set_pixel(x * 2 + j % 2, y * 2 + j / 2, _colour(e[j], palette, alpha_levels))
	return out


## AdvMAME3x / Scale3x.
func _scale3x(key: PackedInt32Array, w: int, h: int, palette: Array[Color], alpha_levels: int) -> Image:
	var out := Image.create(w * 3, h * 3, false, Image.FORMAT_RGBA8)
	for y in h:
		var ym := maxi(y - 1, 0)
		var yp := mini(y + 1, h - 1)
		for x in w:
			var xm := maxi(x - 1, 0)
			var xp := mini(x + 1, w - 1)
			var A := key[xm + ym * w]
			var B := key[x + ym * w]
			var C := key[xp + ym * w]
			var D := key[xm + y * w]
			var E := key[x + y * w]
			var F := key[xp + y * w]
			var G := key[xm + yp * w]
			var H := key[x + yp * w]
			var I := key[xp + yp * w]
			var e := [E, E, E, E, E, E, E, E, E]
			if B != H and D != F:
				e[0] = D if D == B else E
				e[1] = B if (D == B and E != C) or (B == F and E != A) else E
				e[2] = F if B == F else E
				e[3] = D if (D == B and E != G) or (D == H and E != A) else E
				e[5] = F if (B == F and E != I) or (H == F and E != C) else E
				e[6] = D if D == H else E
				e[7] = H if (D == H and E != I) or (H == F and E != G) else E
				e[8] = F if H == F else E
			for j in 9:
				if e[j] >= 0:
					out.set_pixel(x * 3 + j % 3, y * 3 + j / 3, _colour(e[j], palette, alpha_levels))
	return out

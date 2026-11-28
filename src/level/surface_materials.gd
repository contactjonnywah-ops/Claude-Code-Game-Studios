class_name SurfaceMaterials
extends RefCounted
## The look: clean and minimal. Pale panels, dark grip panels, a braced orange crate,
## green for the plate and the door it opens, cyan for gravity, violet for traction.
##
## Textures are drawn at load from a seed, so the project ships no image files.

## Gun colours by mode.
const GRAVITY_COLOR := Color("35e0ff")
const TRACTION_COLOR := Color("c77dff")
const PLATE_OFF := Color("1f9d55")
const PLATE_ON := Color("5dff9a")

var wall: StandardMaterial3D
var block: StandardMaterial3D
var dark: StandardMaterial3D
var cube: StandardMaterial3D
var door: StandardMaterial3D
var glass: StandardMaterial3D
var exit_glow: StandardMaterial3D
var plate: StandardMaterial3D
var gun_body: StandardMaterial3D
var gun_glow: StandardMaterial3D
## Floors: larger, darker tiles, so up reads as up after a flip.
var floor_tile: StandardMaterial3D
## Door frames, pillars and light housings: brushed grey metal.
var trim: StandardMaterial3D
## The glowing face of a light fixture.
var lamp: StandardMaterial3D


## Builds every material. [param seed] fixes the grime pattern.
static func create(seed: int) -> SurfaceMaterials:
	var m := SurfaceMaterials.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	m.wall = _tiled(_panel_texture(rng, Color("e4e7eb"), Color("b9c0c9"), Color.TRANSPARENT), 0.5, 0.75, 0.0)
	m.block = _tiled(_panel_texture(rng, Color("aeb9c6"), Color("8793a2"), Color.TRANSPARENT), 0.5, 0.7, 0.1)
	# Matte: a metallic dark panel mirrors the bright room and stops reading as grippable.
	m.dark = _tiled(_panel_texture(rng, Color("1c2128"), Color("0c0f13"), Color.TRANSPARENT), 1.0, 0.85, 0.0)
	m.cube = _tiled(_panel_texture(rng, Color("3a4350"), Color("20262e"), Color("ff8a1f")), 1.0, 0.5, 0.4)
	m.cube.uv1_world_triplanar = false
	m.cube.uv1_offset = Vector3.ONE * 0.5
	m.door = _tiled(_panel_texture(rng, Color("1f9d55"), Color("0f5c30"), Color.TRANSPARENT), 1.0 / 1.2, 0.5, 0.2)
	m.door.emission_enabled = true
	m.door.emission = Color("0b3a1e")
	m.glass = StandardMaterial3D.new()
	m.glass.albedo_color = Color(0.62, 0.85, 1.0, 0.1)
	m.glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.glass.roughness = 0.05
	m.glass.metallic_specular = 0.5
	m.glass.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.exit_glow = _glow(PLATE_ON, 2.5)
	m.plate = _glow(PLATE_OFF, 0.6)
	m.gun_body = StandardMaterial3D.new()
	m.gun_body.albedo_color = Color("2b323c")
	m.gun_body.roughness = 0.35
	m.gun_body.metallic = 0.7
	m.gun_glow = _glow(GRAVITY_COLOR, 1.1)
	for g: StandardMaterial3D in [m.gun_body, m.gun_glow]:
		# Drawn shrunk toward the eye (same look on screen): the 0.9 m gun reaches past the
		# 0.6 m body, so at full size it pokes into any wall you walk up to.
		g.use_z_clip_scale = true
		g.z_clip_scale = 0.25
	m.floor_tile = _tiled(_panel_texture(rng, Color("9ea6b0"), Color("6f7882"), Color.TRANSPARENT), 0.5, 0.6, 0.0)
	m.trim = StandardMaterial3D.new()
	m.trim.albedo_color = Color("5b636d")
	m.trim.roughness = 0.4
	m.trim.metallic = 0.6
	m.lamp = _glow(Color("eef4ff"), 3.0)
	# Every panel shares one frame layout, so one normal map recesses all their seams.
	var seams := _seam_normals()
	for t: StandardMaterial3D in [m.wall, m.block, m.dark, m.door, m.floor_tile]:
		t.normal_enabled = true
		t.normal_texture = seams
	return m


## An unshaded-looking emissive material of [param color].
static func _glow(color: Color, energy: float) -> StandardMaterial3D:
	var g := StandardMaterial3D.new()
	g.albedo_color = color
	g.emission_enabled = true
	g.emission = color
	g.emission_energy_multiplier = energy
	return g


## A world-space triplanar material, so the panels tile at [param tiles_per_m] on any box.
static func _tiled(tex: Texture2D, tiles_per_m: float, roughness: float, metallic: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex
	m.roughness = roughness
	m.metallic = metallic
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3.ONE * tiles_per_m
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return m


## A square panel: base colour, a seam round the edge, faint grime; with an accent, a braced crate face.
static func _panel_texture(rng: RandomNumberGenerator, base: Color, line: Color, accent: Color) -> ImageTexture:
	const N := 256
	var img := Image.create(N, N, false, Image.FORMAT_RGBA8)
	img.fill(base)
	for y in N:
		for x in N:
			var n := rng.randf_range(-0.025, 0.025)
			var c := img.get_pixel(x, y)
			img.set_pixel(x, y, Color(c.r + n, c.g + n, c.b + n))
	_frame(img, 0, 6, line)
	_frame(img, 6, 2, line.lerp(base, 0.6))
	if accent.a > 0.0:
		_frame(img, 30, 18, accent)
		for i in range(30, N - 30):
			for w in range(-9, 9):
				_dot(img, i + w, i, accent)
				_dot(img, N - 1 - i + w, i, accent)
		for r in 4: # rivets at the brace corners
			var cx := 40 if r % 2 == 0 else N - 40
			var cy := 40 if r < 2 else N - 40
			for dy in range(-4, 5):
				for dx in range(-4, 5):
					if dx * dx + dy * dy <= 16:
						_dot(img, cx + dx, cy + dy, accent.darkened(0.35))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


## Normal map of a panel's edge: the seam sunk in, a narrow bevel stepping up to the face.
static func _seam_normals() -> ImageTexture:
	const N := 256
	var h := Image.create(N, N, false, Image.FORMAT_RGBA8)
	h.fill(Color.WHITE)
	_frame(h, 0, 6, Color.BLACK)
	_frame(h, 6, 3, Color(0.55, 0.55, 0.55))
	h.bump_map_to_normal_map(6.0)
	h.generate_mipmaps()
	return ImageTexture.create_from_image(h)


static func _frame(img: Image, inset: int, width: int, c: Color) -> void:
	var n := img.get_width()
	img.fill_rect(Rect2i(inset, inset, n - inset * 2, width), c)
	img.fill_rect(Rect2i(inset, n - inset - width, n - inset * 2, width), c)
	img.fill_rect(Rect2i(inset, inset, width, n - inset * 2), c)
	img.fill_rect(Rect2i(n - inset - width, inset, width, n - inset * 2), c)


static func _dot(img: Image, x: int, y: int, c: Color) -> void:
	if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height():
		img.set_pixel(x, y, c)

class_name Hud
extends Control
## Everything drawn over the 3D view: crosshair, fall readout, room and deaths,
## the hurt vignette, and the title, pause, death and results screens.

enum Screen { TITLE, PLAY, PAUSE, DEAD, RESULTS }

const FONT_SIZE := 22
const CONTROLS := [
	"WASD: move    Space: jump    Mouse or arrows: look",
	"Q: switch the gun between GRAVITY and TRACTION",
	"GRAVITY: click or F on a dark panel makes it the ground",
	"TRACTION: hold click or F on the crate to lock and carry it",
	"Gravity is real: 9.81 m/s². A fall of ~15 m kills. Reach the green exit door",
	"R: restart room    P / Esc: pause    M: mute    L: low-spec mode",
]

var screen := Screen.TITLE
var room_text := ""
var deaths := 0
var traction := false
## The gun's aim dictionary (see [member GravityGun.aim]).
var aim: Dictionary = {}
var lock := 0.0
var holding := false
var hurt := 0.0
var result_text := ""
var muted := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var size_now := get_rect().size
	var c := size_now * 0.5
	match screen:
		Screen.TITLE:
			draw_rect(Rect2(Vector2.ZERO, size_now), Color(0.043, 0.059, 0.078, 0.82))
			_text("GROUNDSHIFT", Vector2(c.x, size_now.y * 0.2), 72, SurfaceMaterials.GRAVITY_COLOR)
			for i in CONTROLS.size():
				_text(CONTROLS[i], Vector2(c.x, c.y - 100 + i * 38), 24, Color("dfe3e8"))
			_text("Click or press Enter to start", Vector2(c.x, size_now.y - 60), 28, Color.WHITE)
			return
		Screen.RESULTS:
			draw_rect(Rect2(Vector2.ZERO, size_now), Color(0.02, 0.08, 0.05, 0.78))
			_text(result_text, Vector2(c.x, c.y - 30), 46, SurfaceMaterials.PLATE_ON)
			_text("Click or press Enter to play again", Vector2(c.x, c.y + 40), 26, Color.WHITE)
			return
	_draw_play(size_now, c)
	if screen == Screen.PAUSE:
		draw_rect(Rect2(Vector2.ZERO, size_now), Color(0, 0, 0, 0.45))
		_text("Paused: click or P to go on", Vector2(c.x, c.y - 70), 40, Color.WHITE)
	elif screen == Screen.DEAD:
		draw_rect(Rect2(Vector2.ZERO, size_now), Color(0.59, 0, 0, 0.55))
		_text("You fell too far", Vector2(c.x, c.y - 60), 56, Color.WHITE)


func _draw_play(size_now: Vector2, c: Vector2) -> void:
	if hurt > 0.02: # a hard landing reddens the edges
		var edge := Color(0.78, 0, 0, hurt * 0.55)
		var w := size_now.x * 0.18
		var h := size_now.y * 0.18
		for i in 8:
			var k := 1.0 - i / 8.0
			var e := Color(edge, edge.a * k * k / 3.0)
			draw_rect(Rect2(0, 0, w * (i + 1) / 8.0, size_now.y), e)
			draw_rect(Rect2(size_now.x - w * (i + 1) / 8.0, 0, w * (i + 1) / 8.0, size_now.y), e)
			draw_rect(Rect2(0, 0, size_now.x, h * (i + 1) / 8.0), e)
			draw_rect(Rect2(0, size_now.y - h * (i + 1) / 8.0, size_now.x, h * (i + 1) / 8.0), e)
	var kind: String = aim.get("kind", "none")
	var lethal: bool = aim.get("lethal", false)
	var col := Color("8c98a6")
	if kind != "none":
		col = Color("ff4136") if lethal else (SurfaceMaterials.TRACTION_COLOR if traction else SurfaceMaterials.GRAVITY_COLOR)
	draw_arc(c, 9, 0, TAU, 32, Color(0, 0, 0, 0.5), 4.0, true)
	draw_arc(c, 9, 0, TAU, 32, col, 2.0, true)
	for d: Vector2 in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]:
		draw_line(c + d * 14, c + d * 22, Color(0, 0, 0, 0.5), 4.0, true)
		draw_line(c + d * 14, c + d * 22, col, 2.0, true)
	if kind == "fall":
		var fall: float = aim["fall"]
		var impact: float = aim["impact"]
		var label := "DEADLY FALL  %d m  (%.0f m/s)" % [roundi(fall), impact] if lethal else "fall %d m  (%.0f m/s)" % [roundi(fall), impact]
		_text(label, c + Vector2(0, 48), FONT_SIZE, col)
	if traction and lock > 0.0:
		_text("LOCKED" if holding else "locking", c + Vector2(0, 48), FONT_SIZE, col)
	_text(room_text, Vector2(24, 30), FONT_SIZE, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT)
	_text("Deaths %d%s" % [deaths, "   (muted)" if muted else ""], Vector2(size_now.x - 24, 30), FONT_SIZE, Color.WHITE, HORIZONTAL_ALIGNMENT_RIGHT)
	_text("Gun: %s  (Q switches)" % ("TRACTION" if traction else "GRAVITY"), Vector2(c.x, 30), FONT_SIZE,
		SurfaceMaterials.TRACTION_COLOR if traction else SurfaceMaterials.GRAVITY_COLOR)
	var hint := "TRACTION: hold click or F on the crate to lock it in stasis and carry it · R restart room" if traction \
		else "GRAVITY: click or F on a dark panel to make it the ground · WASD move · Space jump · R restart room"
	_text(hint, Vector2(c.x, size_now.y - 28), 18, Color.WHITE)


## Draws [param s] centred (or aligned) on [param at], with a soft shadow.
func _text(s: String, at: Vector2, size_px: int, col: Color, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_CENTER) -> void:
	var font := get_theme_default_font()
	var w := font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x
	var x := at.x - w * 0.5
	if align == HORIZONTAL_ALIGNMENT_LEFT:
		x = at.x
	elif align == HORIZONTAL_ALIGNMENT_RIGHT:
		x = at.x - w
	var base := Vector2(x, at.y + size_px * 0.35)
	draw_string(font, base + Vector2(2, 2), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, Color(0, 0, 0, 0.7))
	draw_string(font, base, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, col)

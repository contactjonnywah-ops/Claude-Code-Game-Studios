class_name InputBindings
extends RefCounted
## Registers the game's input actions at start, by key position (physical keys).

## Action name -> physical keys (and "mouse_left" for the left button).
const BINDINGS := {
	&"move_forward": [KEY_W],
	&"move_back": [KEY_S],
	&"move_left": [KEY_A],
	&"move_right": [KEY_D],
	&"jump": [KEY_SPACE],
	&"look_left": [KEY_LEFT],
	&"look_right": [KEY_RIGHT],
	&"look_up": [KEY_UP],
	&"look_down": [KEY_DOWN],
	&"fire": [KEY_F, "mouse_left"],
	&"switch_mode": [KEY_Q],
	&"restart_room": [KEY_R],
	&"pause": [KEY_P, KEY_ESCAPE],
	&"mute": [KEY_M],
	&"low_spec": [KEY_L],
	&"confirm": [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, "mouse_left"],
}


## Adds every action that is not already in the InputMap.
static func register() -> void:
	for action: StringName in BINDINGS:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		for key: Variant in BINDINGS[action]:
			if key is String:
				var mb := InputEventMouseButton.new()
				mb.button_index = MOUSE_BUTTON_LEFT
				InputMap.action_add_event(action, mb)
			else:
				var ev := InputEventKey.new()
				ev.physical_keycode = key
				InputMap.action_add_event(action, ev)

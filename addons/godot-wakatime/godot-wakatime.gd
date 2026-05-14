@tool
extends EditorPlugin

var scene_mode := false
var api_key := ""
var wakatime_cli_path := ""
var heartbeat_interval := 30.0
var inactive_time := 30.0
var output := []
var active_time := Time.get_unix_time_from_system()
var timer: Timer = null

func _enter_tree() -> void:
scene_changed.connect(_on_activity)
scene_saved.connect(_on_activity)
script_changed.connect(_on_activity)
project_settings_changed.connect(_on_activity)
resource_saved.connect(_on_activity)
main_screen_changed.connect(_on_activity)
wakatime_cli_path = _get_wakatime_cli_path()
_start_timer()
detect_activity()

func _exit_tree() -> void:
scene_changed.disconnect(_on_activity)
scene_saved.disconnect(_on_activity)
script_changed.disconnect(_on_activity)
project_settings_changed.disconnect(_on_activity)
resource_saved.disconnect(_on_activity)
main_screen_changed.disconnect(_on_activity)
if timer:
timer.queue_free()
timer = null

func _forward_canvas_gui_input(event: InputEvent) -> bool:
if event is InputEventMouseButton and event.pressed:
scene_mode = true
_on_activity()
return false

func _forward_3d_gui_input(_viewport_camera: Camera3D, event: InputEvent) -> int:
if event is InputEventMouseButton and event.pressed:
scene_mode = true
_on_activity()
return 0

func _unhandled_key_input(_event: InputEvent) -> void:
_on_activity()

func _on_activity(_unused = null) -> void:
active_time = Time.get_unix_time_from_system()
_update_mode()

func _start_timer() -> void:
if timer:
return
timer = Timer.new()
timer.wait_time = heartbeat_interval
timer.one_shot = false
timer.autostart = true
add_child(timer)
timer.timeout.connect(detect_activity)

func detect_activity() -> void:
if Time.get_unix_time_from_system() - active_time < inactive_time:
send_heartbeat()

func _update_mode() -> void:
var editor = get_editor_interface().get_script_editor()
if editor and editor.get_current_script():
scene_mode = false
else:
scene_mode = true

func send_heartbeat() -> void:
if wakatime_cli_path.is_empty() or not FileAccess.file_exists(wakatime_cli_path):
return
var config_path = _get_wakatime_config_path()
if config_path.is_empty() or not FileAccess.file_exists(config_path):
return
if api_key.is_empty():
api_key = _load_api_key(config_path)
if api_key.is_empty():
return

var project_name = ProjectSettings.get_setting("application/config/name")
var current_time = Time.get_unix_time_from_system()
var cursor_pos = get_current_cursor_position()
var line_number = cursor_pos[0]
var column_number = cursor_pos[1]
var total_lines = cursor_pos[2]
var category = "building" if scene_mode else "coding"

	var args = [
		"--key", api_key,
		"--entity", project_name,
		"--time", str(current_time),
		"--write",
		"--plugin", "godot-wakatime/0.0.1",
		"--alternate-project", project_name,
		"--language", "Godot",
		"--cursorpos", str(column_number),
		"--lineno", str(line_number),
		"--lines-in-file", str(total_lines),
		"--category", category
	]

OS.execute(wakatime_cli_path, args, output, true)
scene_mode = false

func get_current_cursor_position() -> Array:
var script_editor = get_editor_interface().get_script_editor()
if not script_editor:
return [0, 0, 0]
var current_editor = script_editor.get_current_editor()
if not current_editor:
return [0, 0, 0]

var text_edit = _find_text_edit_recursive(current_editor)
if text_edit:
var line = text_edit.get_caret_line(0)
var column = text_edit.get_caret_column(0)
var lines = text_edit.get_line_count()
return [line, column, lines]
return [0, 0, 0]

func _find_text_edit_recursive(node: Node) -> TextEdit:
if node is TextEdit:
return node
for child in node.get_children():
var found = _find_text_edit_recursive(child)
if found:
return found
return null

func _get_wakatime_config_path() -> String:
var home = _get_home_directory()
if home.is_empty():
return ""
return home.path_join(".wakatime.cfg")

func _get_wakatime_cli_path() -> String:
	var home = _get_home_directory()
	if home.is_empty():
		return ""
	var base = home.path_join(".wakatime")
	var os_name = OS.get_name()
	var arch = Engine.get_architecture_name()
	var arch_label = ""
	match arch:
		"x86_64", "amd64":
			arch_label = "amd64"
		"arm64", "aarch64":
			arch_label = "arm64"
		_:
			return ""
var suffix = ""
var os_label = ""

if os_name == "Windows":
os_label = "windows"
suffix = ".exe"
elif os_name == "macOS":
os_label = "darwin"
elif os_name == "Linux":
os_label = "linux"
else:
return ""

return base.path_join("wakatime-cli-%s-%s%s" % [os_label, arch_label, suffix])

func _get_home_directory() -> String:
var home = OS.get_environment("HOME")
if home.is_empty():
home = OS.get_environment("USERPROFILE")
return home

func _load_api_key(path: String) -> String:
var file = FileAccess.open(path, FileAccess.READ)
if not file:
return ""
while not file.eof_reached():
var line = file.get_line().strip_edges()
if line.begins_with("api_key"):
var parts = line.split("=", true, 1)
if parts.size() == 2:
return parts[1].strip_edges()
return ""

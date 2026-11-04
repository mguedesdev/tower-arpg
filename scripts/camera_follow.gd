extends Camera3D

@export var target_path: NodePath
@export var offset: Vector3 = Vector3(6.6, 8.8, 6.6)
@export var lobby_offset: Vector3 = Vector3(6.5, 4.8, 6.5)
@export var follow_speed: float = 10.0
@export var view_size: float = 9.2
@export var lobby_view_size: float = 7.0
@export var min_view_size: float = 7.0
@export var max_view_size: float = 13.5
@export var zoom_step: float = 0.85

var target: Node3D
var _in_lobby: bool = false
var _target_view_size: float = 9.2
var _active_offset: Vector3 = Vector3(6.6, 8.8, 6.6)
var _look_height: float = 0.65
var _shake_timer: float = 0.0
var _shake_intensity: float = 0.0


func apply_shake(intensity: float = 0.45, duration: float = 1.2) -> void:
	_shake_intensity = intensity
	_shake_timer = duration

func _ready() -> void:
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	target = get_node_or_null(target_path) as Node3D
	projection = PROJECTION_ORTHOGONAL
	_target_view_size = view_size
	_active_offset = offset
	size = view_size
	if target != null:
		global_position = target.global_position + _active_offset
		look_at(target.global_position + Vector3(0, _look_height, 0))

func _unhandled_input(event: InputEvent) -> void:
	if _in_lobby:
		return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_target_view_size = clampf(_target_view_size - zoom_step, min_view_size, max_view_size)
			view_size = _target_view_size
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_target_view_size = clampf(_target_view_size + zoom_step, min_view_size, max_view_size)
			view_size = _target_view_size

func set_lobby_mode(enabled: bool, immediate: bool = false) -> void:
	_in_lobby = enabled
	_target_view_size = lobby_view_size if enabled else view_size
	_active_offset = lobby_offset if enabled else offset
	var desired_look_h: float = 0.95 if enabled else 0.65
	if immediate:
		size = _target_view_size
		_look_height = desired_look_h
		if is_instance_valid(target):
			global_position = target.global_position + _active_offset
			look_at(target.global_position + Vector3(0, _look_height, 0))

func _process(delta: float) -> void:
	if not is_instance_valid(target):
		return
	var target_pos: Vector3 = target.get_global_transform_interpolated().origin
	var desired: Vector3 = target_pos + _active_offset
	var desired_look_h: float = 0.95 if _in_lobby else 0.65
	var weight: float = 1.0 - exp(-follow_speed * delta)
	var clamped_w: float = clampf(weight, 0.0, 1.0)
	global_position = global_position.lerp(desired, clamped_w)
	if _shake_timer > 0.0:
		_shake_timer -= delta
		var trauma: float = clampf(_shake_timer, 0.0, 1.0)
		var shake_vec := Vector3(
			randf_range(-1.0, 1.0) * _shake_intensity * trauma,
			randf_range(-1.0, 1.0) * _shake_intensity * 0.4 * trauma,
			randf_range(-1.0, 1.0) * _shake_intensity * trauma
		)
		global_position += shake_vec
	size = lerpf(size, _target_view_size, clamped_w)
	_look_height = lerpf(_look_height, desired_look_h, clamped_w)
	look_at(global_position - _active_offset + Vector3(0, _look_height, 0))

extends Camera3D

@export var target_path: NodePath
@export var offset: Vector3 = Vector3(10.0, 13.0, 10.0)
@export var lobby_offset: Vector3 = Vector3(7.2, 5.2, 7.2)
@export var follow_speed: float = 10.0
@export var view_size: float = 17.0
@export var lobby_view_size: float = 7.4

var target: Node3D
var _in_lobby: bool = false
var _target_view_size: float = 17.0
var _active_offset: Vector3 = Vector3(10.0, 13.0, 10.0)
var _look_height: float = 0.65

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
	size = lerpf(size, _target_view_size, clamped_w)
	_look_height = lerpf(_look_height, desired_look_h, clamped_w)
	look_at(global_position - _active_offset + Vector3(0, _look_height, 0))

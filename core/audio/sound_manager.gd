extends Node
class_name SoundManager

## Gerenciador Central de Áudio (SFX & Trilha Sonora).
## Suporta reprodução 2D global, 3D posicional, pool dinâmico e crossfade de música.

const SOUNDS: Dictionary = {
	"malakor_spawn": "res://assets/audio/sfx/malakor_spawn.wav",
	"malakor_roar": "res://assets/audio/sfx/malakor_roar.wav",
	"cleaver_swing": "res://assets/audio/sfx/cleaver_swing.wav",
	"cleaver_impact": "res://assets/audio/sfx/cleaver_impact.wav",
	"chain_throw": "res://assets/audio/sfx/chain_throw.wav",
	"chain_hook_hit": "res://assets/audio/sfx/chain_hook_hit.wav",
	"boss_music": "res://assets/audio/music/boss_battle_malakor.wav"
}

static var _stream_cache: Dictionary = {}
static var _music_player: AudioStreamPlayer = null
static var _active_tween: Tween = null


static func _get_or_load_stream(sound_name: String) -> AudioStream:
	if _stream_cache.has(sound_name):
		return _stream_cache[sound_name] as AudioStream
	if not SOUNDS.has(sound_name):
		return null
	var path: String = SOUNDS[sound_name]
	if ResourceLoader.exists(path):
		var st: AudioStream = load(path) as AudioStream
		_stream_cache[sound_name] = st
		return st
	return null


static func play_sfx(sound_name: String, at_position: Vector3 = Vector3.ZERO, volume_db: float = 0.0, pitch_scale: float = 1.0) -> void:
	var stream: AudioStream = _get_or_load_stream(sound_name)
	if stream == null:
		return

	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	var scene_root: Node = tree.current_scene if tree.current_scene != null else tree.root
	if scene_root == null:
		return

	if at_position != Vector3.ZERO and scene_root is Node3D:
		var p3d := AudioStreamPlayer3D.new()
		p3d.stream = stream
		p3d.volume_db = volume_db
		p3d.pitch_scale = pitch_scale
		p3d.max_distance = 32.0
		p3d.unit_size = 6.0
		scene_root.add_child(p3d)
		p3d.global_position = at_position
		p3d.play()
		p3d.finished.connect(p3d.queue_free)
	else:
		var p2d := AudioStreamPlayer.new()
		p2d.stream = stream
		p2d.volume_db = volume_db
		p2d.pitch_scale = pitch_scale
		scene_root.add_child(p2d)
		p2d.play()
		p2d.finished.connect(p2d.queue_free)


static func play_boss_music(volume_db: float = -4.0, fade_duration: float = 1.5) -> void:
	var stream: AudioStream = _get_or_load_stream("boss_music")
	if stream == null:
		return

	# Configura loop se for AudioStreamWAV
	if stream is AudioStreamWAV:
		(stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD

	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	var scene_root: Node = tree.current_scene if tree.current_scene != null else tree.root
	if scene_root == null:
		return

	if _music_player == null or not is_instance_valid(_music_player):
		_music_player = AudioStreamPlayer.new()
		_music_player.name = "BossMusicPlayer"
		scene_root.add_child(_music_player)

	if _active_tween != null and _active_tween.is_valid():
		_active_tween.kill()

	_music_player.stream = stream
	_music_player.volume_db = -45.0
	_music_player.play()

	_active_tween = scene_root.create_tween()
	_active_tween.tween_property(_music_player, "volume_db", volume_db, fade_duration)


static func stop_boss_music(fade_duration: float = 2.0) -> void:
	if _music_player == null or not is_instance_valid(_music_player) or not _music_player.playing:
		return

	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		if _music_player != null:
			_music_player.stop()
		return
	var scene_root: Node = tree.current_scene if tree.current_scene != null else tree.root
	if scene_root == null:
		if _music_player != null:
			_music_player.stop()
		return

	if _active_tween != null and _active_tween.is_valid():
		_active_tween.kill()

	_active_tween = scene_root.create_tween()
	_active_tween.tween_property(_music_player, "volume_db", -45.0, fade_duration)
	_active_tween.tween_callback(func() -> void:
		if _music_player != null and is_instance_valid(_music_player):
			_music_player.stop()
	)

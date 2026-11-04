extends Node3D
## Cena isolada de preview: abra scenes/vfx/vfx_gallery.tscn com F6.

const VFX: Script = preload("res://scripts/vfx/tower_vfx_spawner.gd")
const EFFECT_LABELS = [
    "ESTOCADA", "MEIA-LUA", "GIRO", "IMPACTO", "FOGO", "GARRAS"
]
var _elapsed: float = 0.0


func _ready() -> void:
    _make_stage()
    _show_all()


func _process(delta: float) -> void:
    _elapsed += delta
    if _elapsed > 0.9:
        _elapsed = 0.0
        _show_all()


func _show_all() -> void:
    for index in range(6):
        var col: int = index % 3
        var row_index: int = floori(float(index) / 3.0)
        var where: Vector3 = Vector3(float(col - 1) * 4.0, 0.85, float(row_index) * -4.0)
        if index == 3 or index == 4:
            where.y = 0.45
        VFX.spawn(self, index, where, Vector3(0.0, 0.0, 1.0), 1.0)


func _make_stage() -> void:
    var floor_mesh: PlaneMesh = PlaneMesh.new()
    floor_mesh.size = Vector2(17.0, 13.0)
    var floor_material: StandardMaterial3D = StandardMaterial3D.new()
    floor_material.albedo_color = Color(0.075, 0.103, 0.094)
    floor_material.roughness = 1.0
    var floor_instance: MeshInstance3D = MeshInstance3D.new()
    floor_instance.mesh = floor_mesh
    floor_instance.material_override = floor_material
    floor_instance.position = Vector3(0.0, -0.20, -1.6)
    add_child(floor_instance)

    for index in range(6):
        var col: int = index % 3
        var row_index: int = floori(float(index) / 3.0)
        var spot: Vector3 = Vector3(float(col - 1) * 4.0, -0.11, float(row_index) * -4.0)
        var pedestal_mesh: CylinderMesh = CylinderMesh.new()
        pedestal_mesh.top_radius = 0.95
        pedestal_mesh.bottom_radius = 1.08
        pedestal_mesh.height = 0.15
        pedestal_mesh.radial_segments = 9
        var pedestal: MeshInstance3D = MeshInstance3D.new()
        pedestal.mesh = pedestal_mesh
        var pedestal_material: StandardMaterial3D = StandardMaterial3D.new()
        pedestal_material.albedo_color = Color(0.19, 0.235, 0.22)
        pedestal.material_override = pedestal_material
        pedestal.position = spot
        add_child(pedestal)

        var title: Label3D = Label3D.new()
        title.text = EFFECT_LABELS[index]
        title.font_size = 46
        title.pixel_size = 0.005
        title.position = spot + Vector3(0.0, 1.72, 0.0)
        title.modulate = Color(0.90, 0.94, 0.88)
        add_child(title)

    var camera: Camera3D = Camera3D.new()
    camera.projection = Camera3D.PROJECTION_ORTHOGONAL
    camera.size = 16.8
    camera.position = Vector3(0.0, 10.0, 12.0)
    add_child(camera)
    camera.look_at(Vector3(0.0, 0.0, -2.0), Vector3.UP)
    camera.current = true

    var world: WorldEnvironment = WorldEnvironment.new()
    var environment: Environment = Environment.new()
    environment.background_mode = Environment.BG_COLOR
    environment.background_color = Color(0.035, 0.048, 0.047)
    environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    environment.ambient_light_color = Color(0.74, 0.78, 0.80)
    environment.ambient_light_energy = 0.65
    world.environment = environment
    add_child(world)

    var light: DirectionalLight3D = DirectionalLight3D.new()
    light.rotation_degrees = Vector3(-55.0, 35.0, 0.0)
    light.light_energy = 1.4
    add_child(light)

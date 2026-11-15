extends Node2D

## Playable lunar exploration level built around the repository's current lunar atlas.
## The existing grayscale map composition is used as the art-directed terrain base;
## walkable gameplay, HUD, sample sites, collisions, and map bounds remain live nodes.

const PLAYER_SCENE: PackedScene = preload("res://scripts/player.tscn")
const MAP_TEXTURE: Texture2D = preload("res://Image_Assets/ImageAssets_Map/IMG-20261021-WA0013.jpg")
const WORLD_SIZE := Vector2(1536.0, 1024.0)
const WALK_SPEED := 115.0

var astronaut: CharacterBody2D
var oxygen := 100.0
var samples := 0
var active := true
var status_label: Label
var notice_label: Label
var sites: Array[Area2D] = []

func _ready() -> void:
	_configure_inputs()
	_add_map_art()
	_add_player()
	_add_landmark_collisions()
	_add_survey_sites()
	_add_hud()

func _physics_process(delta: float) -> void:
	if Input.is_action_just_pressed("restart"):
		get_tree().reload_current_scene()
	if not active:
		return
	# The outpost keeps the mission viable; outside its radius oxygen drains slowly.
	var at_outpost := astronaut.global_position.distance_to(Vector2(760, 330)) < 170.0
	if at_outpost:
		oxygen = minf(100.0, oxygen + delta * 2.0)
	else:
		oxygen = maxf(0.0, oxygen - delta * 0.22)
	if oxygen <= 0.0:
		active = false
		notice_label.text = "SUIT OXYGEN DEPLETED  •  Press R to restart"
	if Input.is_action_just_pressed("interact"):
		_interact()
	status_label.text = "O₂  %03d%%       SAMPLES  %d / %d" % [roundi(oxygen), samples, sites.size()]

func _configure_inputs() -> void:
	_bind_key("ui_up", KEY_W)
	_bind_key("ui_down", KEY_S)
	_bind_key("ui_left", KEY_A)
	_bind_key("ui_right", KEY_D)
	_bind_key("interact", KEY_E)
	_bind_key("restart", KEY_R)

func _bind_key(action: StringName, key: Key) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var event := InputEventKey.new()
	event.physical_keycode = key
	if not InputMap.action_has_event(action, event):
		InputMap.action_add_event(action, event)

func _add_map_art() -> void:
	var map := Sprite2D.new()
	map.name = "Moon_Surface_Atlas_Composition"
	map.texture = MAP_TEXTURE
	map.centered = false
	map.position = Vector2.ZERO
	map.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	map.z_index = -20
	add_child(map)
	# Keep the lightweight atlas-backed TileMapLayer from the prior version.
	var terrain := TileMapLayer.new()
	terrain.name = "Terrain_TileMapLayer"
	terrain.z_index = -19
	var tileset := TileSet.new()
	tileset.tile_size = Vector2i(32, 32)
	var atlas := TileSetAtlasSource.new()
	atlas.texture = load("res://Image_Assets/ImageAssets_Map/tilesets/Pixel-Art Lunar Base Asset Sheet(land) (1).png")
	atlas.texture_region_size = Vector2i(32, 32)
	if atlas.texture != null:
		atlas.create_tile(Vector2i.ZERO)
		tileset.add_source(atlas, 0)
	terrain.tile_set = tileset
	add_child(terrain)
func _add_player() -> void:
	astronaut = PLAYER_SCENE.instantiate() as CharacterBody2D
	astronaut.name = "Astronaut"
	astronaut.position = Vector2(770, 545)
	astronaut.z_index = 10
	astronaut.velocity = Vector2.ZERO
	astronaut.move_speed = WALK_SPEED
	var sprite := astronaut.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if sprite != null:
		sprite.scale = Vector2(0.14, 0.14)
	add_child(astronaut)
	var camera := Camera2D.new()
	camera.name = "ExplorationCamera"
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 7.0
	camera.zoom = Vector2(1.0, 1.0)
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = int(WORLD_SIZE.x)
	camera.limit_bottom = int(WORLD_SIZE.y)
	astronaut.add_child(camera)
	camera.make_current()

func _add_landmark_collisions() -> void:
	# Footprints match the habitat, greenhouse, launch platform, and highland rims.
	_add_blocker(Vector2(760, 330), Vector2(285, 142))
	_add_blocker(Vector2(480, 320), Vector2(155, 130))
	_add_blocker(Vector2(1300, 190), Vector2(255, 125))
	_add_blocker(Vector2(1390, 790), Vector2(290, 135))
	_add_blocker(Vector2(70, 860), Vector2(210, 130))
	_add_blocker(Vector2(1460, 540), Vector2(140, 230))
	# Solid map perimeter.
	_add_blocker(Vector2(WORLD_SIZE.x * 0.5, -16), Vector2(WORLD_SIZE.x, 32))
	_add_blocker(Vector2(WORLD_SIZE.x * 0.5, WORLD_SIZE.y + 16), Vector2(WORLD_SIZE.x, 32))
	_add_blocker(Vector2(-16, WORLD_SIZE.y * 0.5), Vector2(32, WORLD_SIZE.y))
	_add_blocker(Vector2(WORLD_SIZE.x + 16, WORLD_SIZE.y * 0.5), Vector2(32, WORLD_SIZE.y))

func _add_blocker(center: Vector2, size: Vector2) -> void:
	var body := StaticBody2D.new()
	body.position = center
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	body.add_child(shape)
	add_child(body)

func _add_survey_sites() -> void:
	_add_site("NORTH CRATER", Vector2(586, 150))
	_add_site("SOUTH RIM", Vector2(575, 730))
	_add_site("EAST BASALT", Vector2(1125, 765))

func _add_site(site_name: String, at: Vector2) -> void:
	var site := Area2D.new()
	site.name = site_name.replace(" ", "_")
	site.position = at
	var circle := CircleShape2D.new()
	circle.radius = 28.0
	var collision := CollisionShape2D.new()
	collision.shape = circle
	site.add_child(collision)
	var marker := Polygon2D.new()
	marker.polygon = PackedVector2Array([Vector2(0, -9), Vector2(9, 0), Vector2(0, 9), Vector2(-9, 0)])
	marker.color = Color(0.2, 0.86, 1.0, 0.95)
	site.add_child(marker)
	site.body_entered.connect(_on_site_entered.bind(site, site_name))
	add_child(site)
	sites.append(site)

func _on_site_entered(body: Node2D, site: Area2D, site_name: String) -> void:
	if body != astronaut or not is_instance_valid(site):
		return
	samples += 1
	oxygen = minf(100.0, oxygen + 12.0)
	notice_label.text = "SAMPLE LOGGED  •  %s" % site_name
	site.queue_free()
	sites.erase(site)

func _interact() -> void:
	if astronaut.global_position.distance_to(Vector2(760, 330)) < 185.0:
		oxygen = 100.0
		notice_label.text = "HABITAT AIRLOCK  •  SUIT RECHARGED"
	elif astronaut.global_position.distance_to(Vector2(1300, 190)) < 160.0:
		notice_label.text = "LANDING SITE  •  SYSTEMS NOMINAL"
	else:
		notice_label.text = "Move near the habitat or landing site to interact."

func _add_hud() -> void:
	var layer := CanvasLayer.new()
	layer.name = "Mission_HUD"
	add_child(layer)
	var panel := PanelContainer.new()
	panel.position = Vector2(18, 18)
	panel.custom_minimum_size = Vector2(360, 90)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.055, 0.09, 0.88)
	style.border_color = Color(0.22, 0.73, 0.92, 0.95)
	style.set_border_width_all(2)
	style.set_corner_radius_all(7)
	panel.add_theme_stylebox_override("panel", style)
	layer.add_child(panel)
	var stack := VBoxContainer.new()
	panel.add_child(stack)
	var title := Label.new()
	title.text = "LUNAR FIELD OPERATIONS"
	title.add_theme_color_override("font_color", Color(0.5, 0.9, 1.0))
	stack.add_child(title)
	status_label = Label.new()
	stack.add_child(status_label)
	notice_label = Label.new()
	notice_label.position = Vector2(20, 118)
	notice_label.text = "WASD / Arrows move    E interact    R restart"
	notice_label.add_theme_color_override("font_color", Color(0.95, 0.96, 1.0))
	layer.add_child(notice_label)
	status_label.text = "O₂  100%       SAMPLES  0 / 3"

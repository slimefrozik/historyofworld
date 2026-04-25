## Central singleton holding the entire world state.
extends Node

const Province = preload("res://scripts/province.gd")
const Country = preload("res://scripts/country.gd")
const ArmyUnit = preload("res://scripts/unit.gd")
const Character = preload("res://scripts/character.gd")

signal world_ready
signal date_changed(year: int, month: int, day: int)
signal selection_changed(province_id: int)
signal country_state_changed(country_id: String)
signal log_message(text: String, color: Color)

# Map size in world units (pixels)
const MAP_W: float = 3000.0
const MAP_H: float = 1500.0

var rng := RandomNumberGenerator.new()

var provinces: Array[Province] = []
var countries: Dictionary = {} # id -> Country
var units: Dictionary = {} # id -> ArmyUnit
var characters: Dictionary = {} # id -> Character

var unit_types: Dictionary = {}
var tech_tree: Dictionary = {}
var traits_db: Dictionary = {}
var countries_db: Dictionary = {}
var eras_db: Dictionary = {}
var regions_db: Dictionary = {}
var names_db: Dictionary = {}

var player_country_id: String = ""
var current_era: String = "antiquity"
var year: int = -500
var month: int = 1
var day: int = 1
var next_unit_id: int = 1
var next_char_id: int = 1
var paused: bool = true
var speed: int = 2 # 1..5
var selected_province_id: int = -1
var selected_unit_id: int = -1
var event_log: Array[String] = []
# Symmetric relations stored as keyed dict: "A|B" -> int (A < B lexicographically)
var relations: Dictionary = {}

func _ready() -> void:
	rng.randomize()
	_load_data()

func _load_data() -> void:
	unit_types = _read_json("res://data/unit_types.json")
	tech_tree = _read_json("res://data/tech_tree.json")
	traits_db = _read_json("res://data/traits.json")
	countries_db = _read_json("res://data/countries.json")
	eras_db = _read_json("res://data/eras.json")
	regions_db = _read_json("res://data/regions.json")
	names_db = _read_json("res://data/names.json")

func _read_json(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("Failed to open %s" % path)
		return {}
	var txt := f.get_as_text()
	f.close()
	var parsed = JSON.parse_string(txt)
	if parsed == null:
		push_error("Invalid JSON in %s" % path)
		return {}
	return parsed

func reset() -> void:
	provinces.clear()
	countries.clear()
	units.clear()
	characters.clear()
	relations.clear()
	next_unit_id = 1
	next_char_id = 1
	selected_province_id = -1
	selected_unit_id = -1
	event_log.clear()

func _rel_key(a: String, b: String) -> String:
	if a < b:
		return "%s|%s" % [a, b]
	return "%s|%s" % [b, a]

func get_country(id: String) -> Country:
	return countries.get(id, null)

func get_province(id: int) -> Province:
	if id < 0 or id >= provinces.size():
		return null
	return provinces[id]

func add_unit(u: ArmyUnit) -> int:
	u.id = next_unit_id
	next_unit_id += 1
	units[u.id] = u
	var c := get_country(u.owner_id)
	if c != null:
		c.unit_ids.append(u.id)
	return u.id

func remove_unit(unit_id: int) -> void:
	var u: ArmyUnit = units.get(unit_id)
	if u == null:
		return
	var c := get_country(u.owner_id)
	if c != null:
		c.unit_ids.erase(unit_id)
	units.erase(unit_id)

func add_character(ch: Character) -> int:
	ch.id = next_char_id
	next_char_id += 1
	characters[ch.id] = ch
	return ch.id

func log_event(text: String, color: Color = Color(0.85, 0.85, 0.85)) -> void:
	var stamp := "%d/%02d/%02d  " % [year, month, day]
	var msg := stamp + text
	event_log.append(msg)
	if event_log.size() > 200:
		event_log.pop_front()
	log_message.emit(msg, color)

func date_string() -> String:
	var era_label := "BC" if year < 0 else "AD"
	var y := absi(year)
	return "%d/%02d  %d %s" % [month, day, y, era_label]

func relations_score(a: String, b: String) -> int:
	if a == b:
		return 0
	var ca := get_country(a)
	if ca == null:
		return 0
	if ca.allies.has(b):
		return 100
	if ca.at_war_with.has(b):
		return -150
	return int(relations.get(_rel_key(a, b), 0))

func set_relations(a: String, b: String, val: int) -> void:
	if a == b:
		return
	relations[_rel_key(a, b)] = clamp(val, -200, 200)

func change_relations(a: String, b: String, delta: int) -> void:
	set_relations(a, b, relations_score(a, b) + delta)

func is_at_war(a: String, b: String) -> bool:
	var ca := get_country(a)
	return ca != null and ca.at_war_with.has(b)

func is_allied(a: String, b: String) -> bool:
	var ca := get_country(a)
	return ca != null and ca.allies.has(b)

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
## Fired when a province changes owner (capture, peace deal, gift). Subscribers
## that only need to redraw the map on territorial changes should listen to
## this instead of the much noisier country_state_changed.
signal province_owner_changed(province_id: int)
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
var buildings_db: Dictionary = {}

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
	buildings_db = _read_json("res://data/buildings.json")

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

## Effective relations score for display / AI decisions.
## Allies and wars override the stored value but do NOT replace it.
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

## Raw stored relations value (ignores transient war/ally overrides).
func relations_stored(a: String, b: String) -> int:
	if a == b:
		return 0
	return int(relations.get(_rel_key(a, b), 0))

func set_relations(a: String, b: String, val: int) -> void:
	if a == b:
		return
	relations[_rel_key(a, b)] = clamp(val, -200, 200)

func change_relations(a: String, b: String, delta: int) -> void:
	# Always mutate the stored value, not the transient war/ally override —
	# otherwise ally formation would reset stored to 100, then improve_relations
	# would compound from 100 instead of from the actual stored history.
	set_relations(a, b, relations_stored(a, b) + delta)

func is_at_war(a: String, b: String) -> bool:
	var ca := get_country(a)
	return ca != null and ca.at_war_with.has(b)

func is_allied(a: String, b: String) -> bool:
	var ca := get_country(a)
	return ca != null and ca.allies.has(b)

## A* shortest path between two provinces, using neighbour adjacency.
## `passable` is a callable taking a Province and returning true if it can be
## traversed by the moving unit. Returns the full path (including `from`) if
## reachable, or an empty array if no path exists or the from/to ids are bad.
func find_path(from_id: int, to_id: int, passable: Callable = Callable()) -> Array[int]:
	var out: Array[int] = []
	if from_id == to_id:
		out.append(from_id)
		return out
	var from_p: Province = get_province(from_id)
	var to_p: Province = get_province(to_id)
	if from_p == null or to_p == null:
		return out
	# Open: array sorted by f-cost. For ~1000 nodes a binary-heap-free version
	# is fine; we just rescan on every pop.
	var open: Array = [from_id]
	var came_from: Dictionary = {}
	var g_score: Dictionary = {from_id: 0.0}
	while not open.is_empty():
		# Pop node with lowest f = g + h
		var best_idx: int = 0
		var best_f: float = INF
		for i in open.size():
			var nid: int = open[i]
			var g_val: float = float(g_score.get(nid, INF))
			var nh: float = (provinces[nid].center.distance_to(to_p.center)) / 60.0
			var f_val: float = g_val + nh
			if f_val < best_f:
				best_f = f_val
				best_idx = i
		var current_id: int = open[best_idx]
		open.remove_at(best_idx)
		if current_id == to_id:
			# Reconstruct
			var node: int = current_id
			while node != from_id:
				out.push_front(node)
				node = int(came_from[node])
			out.push_front(from_id)
			return out
		var current_p: Province = provinces[current_id]
		for nb in current_p.neighbors:
			var nb_id: int = int(nb)
			var np: Province = provinces[nb_id]
			if np == null: continue
			if passable.is_valid() and not bool(passable.call(np)):
				continue
			var step_cost: float = 1.0 + float(np.terrain == Province.Terrain.MOUNTAINS) * 1.5 + float(np.terrain == Province.Terrain.JUNGLE) * 0.7
			var tentative_g: float = float(g_score.get(current_id, INF)) + step_cost
			if tentative_g < float(g_score.get(nb_id, INF)):
				came_from[nb_id] = current_id
				g_score[nb_id] = tentative_g
				if not open.has(nb_id):
					open.append(nb_id)
	return out

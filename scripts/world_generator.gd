## Procedural world generator: builds a stylized Earth map made of ~500 hex provinces.
extends Node

const Province = preload("res://scripts/province.gd")
const Country = preload("res://scripts/country.gd")
const ArmyUnit = preload("res://scripts/unit.gd")
const Character = preload("res://scripts/character.gd")

const HEX_SIZE: float = 30.0 # circumradius (point-to-point/2)

# Stylized "Earth" land regions in world coords (3000x1500). Each entry is
# either an ellipse (cx,cy,rx,ry) or rect (x,y,w,h). A hex is land if its
# center is inside any of these.
const LAND_BLOBS: Array = [
	{"k": "ellipse", "cx": 580,  "cy": 380,  "rx": 320, "ry": 220, "name": "north_america"},
	{"k": "ellipse", "cx": 760,  "cy": 600,  "rx": 110, "ry": 70,  "name": "central_america"},
	{"k": "ellipse", "cx": 820,  "cy": 1000, "rx": 130, "ry": 260, "name": "south_america"},
	{"k": "ellipse", "cx": 1180, "cy": 200,  "rx": 80,  "ry": 80,  "name": "greenland"},
	# Europe: extended south to include Italy & Iberia peninsulas, and east to Russia.
	{"k": "ellipse", "cx": 1500, "cy": 340,  "rx": 240, "ry": 170, "name": "europe"},
	{"k": "ellipse", "cx": 1320, "cy": 400,  "rx": 70,  "ry": 90,  "name": "iberia"},
	{"k": "ellipse", "cx": 1540, "cy": 470,  "rx": 50,  "ry": 100, "name": "italy"},
	{"k": "ellipse", "cx": 1640, "cy": 460,  "rx": 100, "ry": 90,  "name": "balkans"},
	{"k": "ellipse", "cx": 1370, "cy": 290,  "rx": 55,  "ry": 75,  "name": "britain"},
	{"k": "ellipse", "cx": 1530, "cy": 190,  "rx": 80,  "ry": 130, "name": "scandinavia"},
	{"k": "ellipse", "cx": 2050, "cy": 280,  "rx": 600, "ry": 180, "name": "siberia"},
	# Anatolia / Middle East / Persia
	{"k": "ellipse", "cx": 1750, "cy": 470,  "rx": 130, "ry": 70,  "name": "anatolia"},
	{"k": "ellipse", "cx": 1900, "cy": 540,  "rx": 200, "ry": 130, "name": "middle_east"},
	{"k": "ellipse", "cx": 2200, "cy": 650,  "rx": 130, "ry": 150, "name": "india"},
	{"k": "ellipse", "cx": 2480, "cy": 470,  "rx": 300, "ry": 220, "name": "east_asia"},
	{"k": "ellipse", "cx": 2700, "cy": 450,  "rx": 60,  "ry": 110, "name": "japan"},
	{"k": "ellipse", "cx": 2580, "cy": 760,  "rx": 200, "ry": 70,  "name": "indonesia"},
	# Africa: extend a bit into Mediterranean coast for Egypt.
	{"k": "ellipse", "cx": 1620, "cy": 700,  "rx": 320, "ry": 160, "name": "north_africa"},
	{"k": "ellipse", "cx": 1640, "cy": 1010, "rx": 200, "ry": 240, "name": "africa"},
	{"k": "ellipse", "cx": 1860, "cy": 1080, "rx": 30,  "ry": 70,  "name": "madagascar"},
	{"k": "ellipse", "cx": 2640, "cy": 1100, "rx": 200, "ry": 130, "name": "australia"},
	{"k": "rect",    "x":  0,    "y":  1410, "w":  3000,"h":  90,  "name": "antarctica"},
]

func _is_land(p: Vector2) -> bool:
	for b in LAND_BLOBS:
		if b.k == "ellipse":
			var dx: float = (p.x - b.cx) / b.rx
			var dy: float = (p.y - b.cy) / b.ry
			if dx * dx + dy * dy <= 1.0:
				return true
		elif b.k == "rect":
			if p.x >= b.x and p.x < b.x + b.w and p.y >= b.y and p.y < b.y + b.h:
				return true
	return false

func _hex_polygon(center: Vector2, size: float, jitter_seed: int) -> PackedVector2Array:
	# Pointy-top hex. Slight per-vertex jitter for organic look (deterministic per cell).
	var pts := PackedVector2Array()
	var r := RandomNumberGenerator.new()
	r.seed = jitter_seed
	for i in range(6):
		var ang: float = deg_to_rad(60.0 * i - 30.0)
		var jx: float = r.randf_range(-0.18, 0.18) * size
		var jy: float = r.randf_range(-0.18, 0.18) * size
		pts.append(center + Vector2(cos(ang) * size + jx, sin(ang) * size + jy))
	return pts

func _pick_terrain(center: Vector2) -> int:
	# Latitudinal climate: poles tundra, mid temperate, equator jungle/desert.
	var y_norm: float = center.y / GameState.MAP_H # 0=top
	var lat_factor: float = abs(y_norm - 0.5) * 2.0 # 0=equator,1=pole
	var rng := RandomNumberGenerator.new()
	rng.seed = int(center.x * 91.0 + center.y * 17.0)
	var roll: float = rng.randf()
	if lat_factor > 0.75:
		return Province.Terrain.TUNDRA
	if lat_factor < 0.18:
		# Tropical band
		if roll < 0.35:
			return Province.Terrain.JUNGLE
		if roll < 0.60:
			return Province.Terrain.DESERT
		return Province.Terrain.PLAINS
	if lat_factor < 0.32 and roll < 0.5:
		return Province.Terrain.DESERT
	# Temperate / cold-temperate
	if roll < 0.10:
		return Province.Terrain.MOUNTAINS
	if roll < 0.25:
		return Province.Terrain.HILLS
	if roll < 0.50:
		return Province.Terrain.FOREST
	if roll < 0.65:
		return Province.Terrain.STEPPE
	return Province.Terrain.PLAINS

const SEA_NAMES: Array = [
	"Northern Ocean", "Western Sea", "Eastern Ocean", "Inland Sea", "Southern Sea",
	"Great Strait", "Open Waters", "Coastal Waters", "Deep Channel", "Distant Sea",
]

func _gen_sea_name(idx: int) -> String:
	var rng := RandomNumberGenerator.new()
	rng.seed = idx * 4099 + 31
	return String(SEA_NAMES[rng.randi_range(0, SEA_NAMES.size() - 1)])

func _gen_province_name(idx: int) -> String:
	var roots: Array = GameState.names_db.get("province_roots", ["Tarn"])
	var prefixes: Array = GameState.names_db.get("province_prefixes", [""])
	# Use a local RNG so we don't reseed the global GameState.rng (which would
	# make all subsequent province generation deterministic on the same seed).
	var name_rng := RandomNumberGenerator.new()
	name_rng.seed = idx * 7919 + 13
	var root: String = String(roots[name_rng.randi_range(0, roots.size() - 1)])
	if name_rng.randf() < 0.35 and prefixes.size() > 0:
		var pref: String = String(prefixes[name_rng.randi_range(0, prefixes.size() - 1)])
		return "%s %s" % [pref, root]
	return root

func generate(starting_era: String) -> void:
	GameState.reset()
	GameState.current_era = starting_era
	var era_def: Dictionary = GameState.eras_db.get(starting_era, {})
	GameState.year = int(era_def.get("year_start", -500))
	GameState.month = 1
	GameState.day = 1

	var hex_w: float = sqrt(3.0) * HEX_SIZE
	var hex_v: float = 1.5 * HEX_SIZE
	var rows: int = int(GameState.MAP_H / hex_v) + 1
	var cols: int = int(GameState.MAP_W / hex_w) + 1

	# Track which provinces exist at which (col,row) for neighbour lookup.
	var grid: Dictionary = {} # Vector2i(col,row) -> province id

	for r in range(rows):
		for c in range(cols):
			var x: float = c * hex_w + (0.5 * hex_w if r % 2 == 1 else 0.0)
			var y: float = r * hex_v
			var center := Vector2(x, y)
			if center.x < HEX_SIZE * 0.4 or center.x > GameState.MAP_W - HEX_SIZE * 0.4:
				continue
			if center.y < HEX_SIZE * 0.4 or center.y > GameState.MAP_H - HEX_SIZE * 0.4:
				continue
			var is_land: bool = _is_land(center)
			var p := Province.new()
			p.id = GameState.provinces.size()
			p.center = center
			p.polygon = _hex_polygon(center, HEX_SIZE, p.id * 17 + 5)
			if is_land:
				p.terrain = _pick_terrain(center)
				p.development = GameState.rng.randi_range(1, 5)
				p.population = p.development * 1000 + GameState.rng.randi_range(0, 800)
				p.name = _gen_province_name(p.id)
				p.is_sea = false
			else:
				p.terrain = Province.Terrain.SEA
				p.development = 0
				p.population = 0
				p.name = _gen_sea_name(p.id)
				p.is_sea = true
			GameState.provinces.append(p)
			grid[Vector2i(c, r)] = p.id

	# Compute hex neighbours.
	# Pointy-top, odd-r offset coordinates: even rows / odd rows have different deltas.
	var even_neighbors := [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(-1, -1), Vector2i(0, 1), Vector2i(-1, 1)]
	var odd_neighbors  := [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(1, -1),  Vector2i(0, -1),  Vector2i(1, 1),  Vector2i(0, 1)]
	for key in grid.keys():
		var pid: int = grid[key]
		var deltas = even_neighbors if key.y % 2 == 0 else odd_neighbors
		var neigh: Array[int] = []
		for d in deltas:
			var nb: Variant = grid.get(key + d)
			if nb != null:
				neigh.append(int(nb))
		GameState.provinces[pid].neighbors = neigh

	# Mark coastal land provinces (have at least one sea neighbour) and
	# upgrade their terrain tint to COAST when they would otherwise be plains.
	var land_count: int = 0
	var sea_count: int = 0
	for p in GameState.provinces:
		if p.is_sea:
			sea_count += 1
			continue
		land_count += 1
		for nb_id in p.neighbors:
			var np: Province = GameState.provinces[int(nb_id)]
			if np != null and np.is_sea:
				p.is_coast = true
				if p.terrain == Province.Terrain.PLAINS:
					p.terrain = Province.Terrain.COAST
				break

	GameState.log_event("Generated %d land + %d sea provinces." % [land_count, sea_count])

	_assign_resources()

	_assign_starting_countries(starting_era)

	GameState.log_event("World ready: %s era starts in %d." % [str(era_def.get("name", starting_era)), GameState.year])
	GameState.world_ready.emit()

func _assign_resources() -> void:
	# Roughly 40% of land provinces get an economic resource based on terrain.
	# Coastal land additionally has a higher chance of fish.
	for p in GameState.provinces:
		if p.is_sea:
			continue
		if GameState.rng.randf() > 0.45:
			continue
		var r: String = ""
		match p.terrain:
			Province.Terrain.PLAINS, Province.Terrain.STEPPE:
				r = ["grain", "horses", "wool"][GameState.rng.randi_range(0, 2)]
			Province.Terrain.HILLS, Province.Terrain.MOUNTAINS:
				r = ["iron", "stone", "gold_ore"][GameState.rng.randi_range(0, 2)]
			Province.Terrain.FOREST:
				r = ["wood", "fur"][GameState.rng.randi_range(0, 1)]
			Province.Terrain.JUNGLE:
				r = ["spices", "wood"][GameState.rng.randi_range(0, 1)]
			Province.Terrain.DESERT:
				r = "salt"
			Province.Terrain.TUNDRA:
				r = "fur"
			Province.Terrain.COAST:
				r = "fish"
			_:
				r = ""
		if p.is_coast and r == "" and GameState.rng.randf() < 0.5:
			r = "fish"
		p.resource = r

func _assign_starting_countries(starting_era: String) -> void:
	var era_def: Dictionary = GameState.eras_db.get(starting_era, {})
	var starters: Array = era_def.get("starting_countries", [])
	var ruler_pool_m: Array = GameState.names_db.get("ruler_names_male", ["Ruler"])
	var ruler_pool_f: Array = GameState.names_db.get("ruler_names_female", ["Ruler"])
	var advisor_titles: Array = GameState.names_db.get("advisor_titles", ["Chancellor"])
	var general_titles: Array = GameState.names_db.get("general_titles", ["Marshal"])
	var trait_keys: Array = GameState.traits_db.keys()

	for cid in starters:
		var def: Dictionary = GameState.countries_db.get(cid, {})
		if def.is_empty():
			continue
		var c := Country.new()
		c.id = cid
		c.name = String(def.get("name", cid))
		var col: Array = def.get("color", [0.5, 0.5, 0.5])
		c.color = Color(col[0], col[1], col[2])
		c.era = String(def.get("era", starting_era))
		c.primary_culture = String(def.get("culture", "generic"))
		c.state_religion = String(def.get("religion", "pagan"))
		var gov_str: String = String(def.get("government", "MONARCHY"))
		c.government = Country.Government[gov_str] if gov_str in Country.Government else Country.Government.MONARCHY
		c.gold = 200.0
		c.manpower_pool = 8000.0
		c.legitimacy = 1.0
		c.stability = 0.0
		GameState.countries[cid] = c

		# Find provinces in country's region rect and assign as core territory.
		var region: Dictionary = GameState.regions_db.get(String(def.get("region", "")), {})
		var rx: float = float(region.get("x", -1))
		var ry: float = float(region.get("y", -1))
		var rw: float = float(region.get("w", 0))
		var rh: float = float(region.get("h", 0))
		var assigned_provinces: Array[int] = []
		if rx >= 0:
			for p in GameState.provinces:
				if p.is_sea:
					continue
				if p.owner_id != "" or p.center.x < rx or p.center.x >= rx + rw:
					continue
				if p.center.y < ry or p.center.y >= ry + rh:
					continue
				p.owner_id = cid
				p.culture = c.primary_culture
				p.religion = c.state_religion
				p.core_of.append(cid)
				assigned_provinces.append(p.id)
		c.province_ids = assigned_provinces
		# Capital = highest-development province (or first).
		if assigned_provinces.size() > 0:
			var cap_id: int = assigned_provinces[0]
			var best_dev: int = -1
			for pid in assigned_provinces:
				var pp: Province = GameState.provinces[pid]
				if pp.development > best_dev:
					best_dev = pp.development
					cap_id = pid
			c.capital_id = cap_id
			GameState.provinces[cap_id].is_capital = true
			GameState.provinces[cap_id].development = max(GameState.provinces[cap_id].development, 6)

		# Spawn ruler + advisors + generals.
		var ruler_male: bool = GameState.rng.randf() < 0.85
		var rname: String = String((ruler_pool_m if ruler_male else ruler_pool_f).pick_random())
		var ruler := Character.new()
		ruler.name = rname + " I"
		ruler.country_id = cid
		ruler.role = Character.Role.RULER
		ruler.age = GameState.rng.randi_range(25, 55)
		ruler.martial = GameState.rng.randi_range(0, 5)
		ruler.diplomacy = GameState.rng.randi_range(0, 5)
		ruler.stewardship = GameState.rng.randi_range(0, 5)
		ruler.intrigue = GameState.rng.randi_range(0, 5)
		ruler.learning = GameState.rng.randi_range(0, 5)
		ruler.traits = _pick_traits(trait_keys, 2)
		c.ruler_id = GameState.add_character(ruler)

		for ai in range(3):
			var adv := Character.new()
			adv.name = String(ruler_pool_m.pick_random()) + " " + String(advisor_titles[ai % advisor_titles.size()])
			adv.country_id = cid
			adv.role = Character.Role.ADVISOR
			adv.age = GameState.rng.randi_range(28, 65)
			adv.martial = GameState.rng.randi_range(0, 5)
			adv.diplomacy = GameState.rng.randi_range(0, 5)
			adv.stewardship = GameState.rng.randi_range(0, 5)
			adv.intrigue = GameState.rng.randi_range(0, 5)
			adv.learning = GameState.rng.randi_range(0, 5)
			adv.traits = _pick_traits(trait_keys, 1)
			c.advisor_ids.append(GameState.add_character(adv))

		for gi in range(2):
			var gen := Character.new()
			gen.name = String(ruler_pool_m.pick_random()) + " " + String(general_titles[gi % general_titles.size()])
			gen.country_id = cid
			gen.role = Character.Role.GENERAL
			gen.age = GameState.rng.randi_range(30, 60)
			gen.martial = GameState.rng.randi_range(2, 6)
			gen.diplomacy = GameState.rng.randi_range(0, 4)
			gen.stewardship = GameState.rng.randi_range(0, 4)
			gen.intrigue = GameState.rng.randi_range(0, 4)
			gen.learning = GameState.rng.randi_range(0, 4)
			gen.traits = _pick_traits(trait_keys, 1)
			c.general_ids.append(GameState.add_character(gen))

		# Starting army: 2 stacks of basic era units in capital.
		var starter_unit: String = _starter_unit_for(c.era)
		for i in range(2):
			var u := ArmyUnit.new()
			u.owner_id = cid
			u.type_id = starter_unit
			u.name = "%s Army %d" % [c.name, i + 1]
			u.province_id = c.capital_id
			u.strength = 5000
			u.max_strength = 5000
			GameState.add_unit(u)

		# Starting tech: era-appropriate.
		_grant_starter_tech(c)

	# Initialize neutral relations.
	for a in GameState.countries.keys():
		for b in GameState.countries.keys():
			if a == b: continue
			GameState.set_relations(a, b, 0)

func _pick_traits(pool: Array, n: int) -> Array[String]:
	var out: Array[String] = []
	if pool.size() == 0: return out
	var copy := pool.duplicate()
	copy.shuffle()
	for i in range(min(n, copy.size())):
		out.append(String(copy[i]))
	return out

func _starter_unit_for(era: String) -> String:
	match era:
		"antiquity": return "levy"
		"medieval": return "men_at_arms"
		"renaissance": return "pikemen"
		"industrial": return "line_infantry"
		"modern": return "riflemen"
	return "levy"

func _grant_starter_tech(c: Country) -> void:
	var era_order := ["antiquity", "medieval", "renaissance", "industrial", "modern"]
	var idx: int = era_order.find(c.era)
	if idx < 0: idx = 0
	for tech_id in GameState.tech_tree.keys():
		var t: Dictionary = GameState.tech_tree[tech_id]
		var tera: String = String(t.get("era", "antiquity"))
		var tidx: int = era_order.find(tera)
		if tidx >= 0 and tidx < idx:
			c.researched_techs.append(tech_id)

## Province data class. Each province is a polygon on the world map.
class_name Province
extends RefCounted

enum Terrain { PLAINS, FOREST, HILLS, MOUNTAINS, DESERT, STEPPE, JUNGLE, TUNDRA, COAST, SEA }

var id: int = -1
var name: String = ""
var polygon: PackedVector2Array = PackedVector2Array()
var center: Vector2 = Vector2.ZERO
var owner_id: String = "" # Country code; "" means uncolonized
var core_of: Array[String] = [] # Countries that consider this province core
var terrain: int = Terrain.PLAINS
var development: int = 1 # 1..10, drives tax + manpower
var population: int = 1000
var culture: String = "generic"
var religion: String = "pagan"
var buildings: Array[String] = []
var garrison: int = 0
var unrest: float = 0.0
var neighbors: Array[int] = []
var is_capital: bool = false
var is_sea: bool = false # true = sea/ocean tile (only naval units can enter)
var is_coast: bool = false # land province with at least one sea neighbour
var resource: String = "" # economic good produced by this province (grain/iron/...)
# Active building project: building_id, accumulated months. Empty id = idle.
var build_id: String = ""
var build_progress_months: float = 0.0
# Active religious / cultural conversion projects (paid by owner).
var convert_religion_to: String = ""
var convert_religion_months: float = 0.0
var convert_culture_to: String = ""
var convert_culture_months: float = 0.0
## Fortification level (0 = none, 1..3 = small/medium/great fort).
## Drives siege duration and adds flat defensive bonus.
var fort_level: int = 0
## Current siege state. `siege_attacker_id` is the attacker's country id (the
## one trying to capture the province from `owner_id`). `siege_progress` is
## 0..1; reaches 1.0 → attacker flips the province. Resets if defenders retake
## the province or the attacker's stack leaves.
var siege_attacker_id: String = ""
var siege_progress: float = 0.0

func base_tax() -> float:
	return float(development) * 0.5

func base_manpower() -> float:
	return float(development) * 100.0

func terrain_name() -> String:
	match terrain:
		Terrain.PLAINS: return "Plains"
		Terrain.FOREST: return "Forest"
		Terrain.HILLS: return "Hills"
		Terrain.MOUNTAINS: return "Mountains"
		Terrain.DESERT: return "Desert"
		Terrain.STEPPE: return "Steppe"
		Terrain.JUNGLE: return "Jungle"
		Terrain.TUNDRA: return "Tundra"
		Terrain.COAST: return "Coast"
		Terrain.SEA: return "Sea"
	return "Unknown"

func combat_bonus_for_defender() -> float:
	var base: float = 0.0
	match terrain:
		Terrain.MOUNTAINS: base = 0.40
		Terrain.HILLS: base = 0.20
		Terrain.FOREST, Terrain.JUNGLE: base = 0.15
		Terrain.DESERT, Terrain.TUNDRA: base = 0.05
		_: base = 0.0
	# Each fort level adds 15% to the defender's damage roll.
	return base + 0.15 * float(fort_level)

func to_dict() -> Dictionary:
	return {
		"id": id, "name": name, "polygon": polygon, "center": center,
		"owner_id": owner_id, "core_of": core_of, "terrain": terrain,
		"development": development, "population": population, "culture": culture,
		"religion": religion, "buildings": buildings, "garrison": garrison,
		"unrest": unrest, "neighbors": neighbors, "is_capital": is_capital,
		"is_sea": is_sea, "is_coast": is_coast, "resource": resource,
		"build_id": build_id, "build_progress_months": build_progress_months,
		"convert_religion_to": convert_religion_to,
		"convert_religion_months": convert_religion_months,
		"convert_culture_to": convert_culture_to,
		"convert_culture_months": convert_culture_months,
		"fort_level": fort_level,
		"siege_attacker_id": siege_attacker_id,
		"siege_progress": siege_progress,
	}

static func from_dict(d: Dictionary) -> Province:
	var p := Province.new()
	p.id = int(d.get("id", -1))
	p.name = String(d.get("name", ""))
	p.polygon = d.get("polygon", PackedVector2Array())
	p.center = d.get("center", Vector2.ZERO)
	p.owner_id = String(d.get("owner_id", ""))
	var core: Array = d.get("core_of", [])
	p.core_of.assign(core)
	p.terrain = int(d.get("terrain", Terrain.PLAINS))
	p.development = int(d.get("development", 1))
	p.population = int(d.get("population", 1000))
	p.culture = String(d.get("culture", "generic"))
	p.religion = String(d.get("religion", "pagan"))
	var blds: Array = d.get("buildings", [])
	p.buildings.assign(blds)
	p.garrison = int(d.get("garrison", 0))
	p.unrest = float(d.get("unrest", 0.0))
	var nb: Array = d.get("neighbors", [])
	p.neighbors.assign(nb)
	p.is_capital = bool(d.get("is_capital", false))
	p.is_sea = bool(d.get("is_sea", false))
	p.is_coast = bool(d.get("is_coast", false))
	p.resource = String(d.get("resource", ""))
	p.build_id = String(d.get("build_id", ""))
	p.build_progress_months = float(d.get("build_progress_months", 0.0))
	p.convert_religion_to = String(d.get("convert_religion_to", ""))
	p.convert_religion_months = float(d.get("convert_religion_months", 0.0))
	p.convert_culture_to = String(d.get("convert_culture_to", ""))
	p.convert_culture_months = float(d.get("convert_culture_months", 0.0))
	p.fort_level = int(d.get("fort_level", 0))
	p.siege_attacker_id = String(d.get("siege_attacker_id", ""))
	p.siege_progress = float(d.get("siege_progress", 0.0))
	return p

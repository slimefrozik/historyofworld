## Province data class. Each province is a polygon on the world map.
class_name Province
extends RefCounted

enum Terrain { PLAINS, FOREST, HILLS, MOUNTAINS, DESERT, STEPPE, JUNGLE, TUNDRA, COAST }

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
	return "Unknown"

func combat_bonus_for_defender() -> float:
	match terrain:
		Terrain.MOUNTAINS: return 0.40
		Terrain.HILLS: return 0.20
		Terrain.FOREST, Terrain.JUNGLE: return 0.15
		Terrain.DESERT, Terrain.TUNDRA: return 0.05
		_: return 0.0

func to_dict() -> Dictionary:
	return {
		"id": id, "name": name, "polygon": polygon, "center": center,
		"owner_id": owner_id, "core_of": core_of, "terrain": terrain,
		"development": development, "population": population, "culture": culture,
		"religion": religion, "buildings": buildings, "garrison": garrison,
		"unrest": unrest, "neighbors": neighbors, "is_capital": is_capital,
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
	return p

## Country data class.
class_name Country
extends RefCounted

# Government / era classification
enum Government { TRIBAL, MONARCHY, REPUBLIC, EMPIRE, FEUDAL, ABSOLUTE, CONSTITUTIONAL, COMMUNIST, MODERN }

var id: String = "" # 3-letter code
var name: String = ""
var color: Color = Color.GRAY
var capital_id: int = -1
var government: int = Government.MONARCHY
var era: String = "antiquity" # antiquity / medieval / renaissance / industrial / modern
var primary_culture: String = "generic"
var state_religion: String = "pagan"
var gold: float = 100.0
var manpower_pool: float = 5000.0
var stability: float = 0.0 # -3..3
var legitimacy: float = 1.0 # 0..1
var prestige: float = 0.0 # -100..100
var research_points: float = 0.0
var culture_points: float = 0.0
var researched_techs: Array[String] = []
var current_research: String = ""
var ruler_id: int = -1
var advisor_ids: Array[int] = []
var general_ids: Array[int] = []
var unit_ids: Array[int] = []
var province_ids: Array[int] = []
var at_war_with: Array[String] = []
var allies: Array[String] = []
var truces: Dictionary = {} # country_id -> end date string
var claims: Array[int] = [] # province ids
var is_player: bool = false
var is_ai: bool = true
var is_alive: bool = true

func to_dict() -> Dictionary:
	return {
		"id": id, "name": name, "color": [color.r, color.g, color.b],
		"capital_id": capital_id, "government": government, "era": era,
		"primary_culture": primary_culture, "state_religion": state_religion,
		"gold": gold, "manpower_pool": manpower_pool,
		"stability": stability, "legitimacy": legitimacy, "prestige": prestige,
		"research_points": research_points, "culture_points": culture_points,
		"researched_techs": researched_techs, "current_research": current_research,
		"ruler_id": ruler_id, "advisor_ids": advisor_ids, "general_ids": general_ids,
		"unit_ids": unit_ids, "province_ids": province_ids,
		"at_war_with": at_war_with, "allies": allies, "truces": truces,
		"claims": claims, "is_player": is_player, "is_ai": is_ai, "is_alive": is_alive,
	}

static func from_dict(d: Dictionary) -> Country:
	var c := Country.new()
	c.id = String(d.get("id", ""))
	c.name = String(d.get("name", ""))
	var col: Array = d.get("color", [0.5, 0.5, 0.5])
	c.color = Color(col[0], col[1], col[2])
	c.capital_id = int(d.get("capital_id", -1))
	c.government = int(d.get("government", Government.MONARCHY))
	c.era = String(d.get("era", "antiquity"))
	c.primary_culture = String(d.get("primary_culture", "generic"))
	c.state_religion = String(d.get("state_religion", "pagan"))
	c.gold = float(d.get("gold", 100.0))
	c.manpower_pool = float(d.get("manpower_pool", 5000.0))
	c.stability = float(d.get("stability", 0.0))
	c.legitimacy = float(d.get("legitimacy", 1.0))
	c.prestige = float(d.get("prestige", 0.0))
	c.research_points = float(d.get("research_points", 0.0))
	c.culture_points = float(d.get("culture_points", 0.0))
	c.researched_techs.assign(d.get("researched_techs", []))
	c.current_research = String(d.get("current_research", ""))
	c.ruler_id = int(d.get("ruler_id", -1))
	c.advisor_ids.assign(d.get("advisor_ids", []))
	c.general_ids.assign(d.get("general_ids", []))
	c.unit_ids.assign(d.get("unit_ids", []))
	c.province_ids.assign(d.get("province_ids", []))
	c.at_war_with.assign(d.get("at_war_with", []))
	c.allies.assign(d.get("allies", []))
	c.truces = d.get("truces", {})
	c.claims.assign(d.get("claims", []))
	c.is_player = bool(d.get("is_player", false))
	c.is_ai = bool(d.get("is_ai", true))
	c.is_alive = bool(d.get("is_alive", true))
	return c

## A character (ruler / advisor / general / agent) with traits.
class_name Character
extends RefCounted

enum Role { RULER, ADVISOR, GENERAL, SPY, DIPLOMAT }

var id: int = -1
var name: String = ""
var country_id: String = ""
var role: int = Role.ADVISOR
var age: int = 30
# Stats 0..6
var martial: int = 2
var diplomacy: int = 2
var stewardship: int = 2
var intrigue: int = 2
var learning: int = 2
var traits: Array[String] = []
var loyalty: float = 1.0 # 0..1
var alive: bool = true

func role_name() -> String:
	match role:
		Role.RULER: return "Ruler"
		Role.ADVISOR: return "Advisor"
		Role.GENERAL: return "General"
		Role.SPY: return "Spy"
		Role.DIPLOMAT: return "Diplomat"
	return "?"

func power_level() -> int:
	# Sum of stats + bonus from role
	var role_bonus := 0
	if role == Role.RULER:
		role_bonus = 6
	elif role == Role.ADVISOR or role == Role.GENERAL:
		role_bonus = 2
	return martial + diplomacy + stewardship + intrigue + learning + role_bonus

func to_dict() -> Dictionary:
	return {
		"id": id, "name": name, "country_id": country_id, "role": role, "age": age,
		"martial": martial, "diplomacy": diplomacy, "stewardship": stewardship,
		"intrigue": intrigue, "learning": learning, "traits": traits,
		"loyalty": loyalty, "alive": alive,
	}

static func from_dict(d: Dictionary) -> Character:
	var c := Character.new()
	c.id = int(d.get("id", -1))
	c.name = String(d.get("name", ""))
	c.country_id = String(d.get("country_id", ""))
	c.role = int(d.get("role", Role.ADVISOR))
	c.age = int(d.get("age", 30))
	c.martial = int(d.get("martial", 2))
	c.diplomacy = int(d.get("diplomacy", 2))
	c.stewardship = int(d.get("stewardship", 2))
	c.intrigue = int(d.get("intrigue", 2))
	c.learning = int(d.get("learning", 2))
	c.traits.assign(d.get("traits", []))
	c.loyalty = float(d.get("loyalty", 1.0))
	c.alive = bool(d.get("alive", true))
	return c

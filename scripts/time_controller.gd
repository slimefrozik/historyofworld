## Drives in-game time. Triggers daily/monthly/yearly callbacks.
extends Node

signal day_tick
signal month_tick
signal year_tick

const SECONDS_PER_DAY := [9999.0, 1.5, 0.6, 0.25, 0.10, 0.04] # speed 0..5 ; 0 = paused
var accum: float = 0.0

func _process(delta: float) -> void:
	if GameState.paused:
		return
	if GameState.countries.is_empty():
		return
	var sp: int = clamp(GameState.speed, 1, 5)
	accum += delta
	while accum >= SECONDS_PER_DAY[sp]:
		accum -= SECONDS_PER_DAY[sp]
		_advance_one_day()

func _advance_one_day() -> void:
	GameState.day += 1
	day_tick.emit()
	if GameState.day > 30:
		GameState.day = 1
		GameState.month += 1
		_on_month()
		month_tick.emit()
		if GameState.month > 12:
			GameState.month = 1
			GameState.year += 1
			_on_year()
			year_tick.emit()
	GameState.date_changed.emit(GameState.year, GameState.month, GameState.day)

func _on_month() -> void:
	# Economy + research + culture monthly tick.
	for cid in GameState.countries.keys():
		var c: Country = GameState.countries[cid]
		if not c.is_alive:
			continue
		var income: float = 0.0
		var research: float = 0.0
		var culture: float = 0.0
		var manpower_recover: float = 0.0
		var tax_mod: float = 1.0 + _tech_modifier(c, "tax")
		var research_mod: float = 1.0 + _tech_modifier(c, "research_speed")
		var culture_mod: float = 1.0 + _tech_modifier(c, "culture_speed")
		var manpower_mod: float = 1.0 + _tech_modifier(c, "manpower")
		# Stewardship from ruler
		var ruler: Character = GameState.characters.get(c.ruler_id)
		if ruler != null:
			tax_mod += 0.02 * ruler.stewardship
			research_mod += 0.015 * ruler.learning
			manpower_mod += 0.015 * ruler.martial
		# Religious and cultural unity (% of own provinces matching state). Higher
		# unity = lower unrest tendency + small bonuses to tax/manpower.
		var match_rel: int = 0
		var match_cul: int = 0
		var land_count: int = 0
		for pid in c.province_ids:
			var pp: Province = GameState.provinces[pid]
			if pp == null or pp.is_sea: continue
			land_count += 1
			if pp.religion == c.state_religion: match_rel += 1
			if pp.culture == c.primary_culture: match_cul += 1
		var rel_unity: float = 1.0 if land_count == 0 else float(match_rel) / float(land_count)
		var cul_unity: float = 1.0 if land_count == 0 else float(match_cul) / float(land_count)
		tax_mod += 0.10 * (rel_unity - 0.5)
		manpower_mod += 0.10 * (cul_unity - 0.5)
		for pid in c.province_ids:
			var p: Province = GameState.provinces[pid]
			if p == null:
				continue
			if p.is_sea:
				continue
			# Building stat multipliers stack across all completed buildings.
			var ptax: float = 1.0
			var pman: float = 1.0
			var pres: float = 1.0
			var pcul: float = 1.0
			var ptrade: float = 1.0
			for b_id in p.buildings:
				var bdef: Dictionary = GameState.buildings_db.get(b_id, {})
				ptax *= float(bdef.get("tax_mult", 1.0))
				pman *= float(bdef.get("manpower_mult", 1.0))
				pres *= float(bdef.get("research_mult", 1.0))
				pcul *= float(bdef.get("culture_mult", 1.0))
				ptrade *= float(bdef.get("trade_mult", 1.0))
			# Mismatched culture/religion bumps unrest a little, dampens tax.
			var mismatch_pen: float = 1.0
			if p.religion != c.state_religion: mismatch_pen *= 0.85
			if p.culture != c.primary_culture: mismatch_pen *= 0.90
			income += p.base_tax() * tax_mod * ptax * mismatch_pen
			research += 0.5 * p.development * research_mod * pres
			culture += 0.3 * p.development * culture_mod * pcul
			manpower_recover += 30.0 * p.development * manpower_mod * pman
			# Trade: a market or harbour generates extra gold per resource owned.
			var has_market: bool = p.buildings.has("market") or p.buildings.has("harbour")
			if has_market and p.resource != "":
				income += 1.5 * ptrade
			# Process active building.
			if p.build_id != "":
				p.build_progress_months += 1.0
				var bd: Dictionary = GameState.buildings_db.get(p.build_id, {})
				var need: float = float(bd.get("build_months", 1))
				if p.build_progress_months >= need:
					p.buildings.append(p.build_id)
					GameState.log_event("[%s] %s built in %s." % [c.name, String(bd.get("name_key", p.build_id)), p.name], Color(0.7, 0.9, 1.0))
					p.build_id = ""
					p.build_progress_months = 0.0
			# Religious conversion project.
			if p.convert_religion_to != "" and p.convert_religion_months > 0.0:
				var speed: float = 1.0
				if p.buildings.has("temple"): speed *= 1.5
				p.convert_religion_months -= speed
				if p.convert_religion_months <= 0.0:
					p.religion = p.convert_religion_to
					GameState.log_event("[%s] %s converted to %s." % [c.name, p.name, p.religion], Color(0.85, 0.7, 1.0))
					p.convert_religion_to = ""
					p.convert_religion_months = 0.0
			# Cultural assimilation (slow, no upkeep — flag-only).
			if p.convert_culture_to != "" and p.convert_culture_months > 0.0:
				p.convert_culture_months -= 1.0
				if p.convert_culture_months <= 0.0:
					p.culture = p.convert_culture_to
					GameState.log_event("[%s] %s assimilated to %s culture." % [c.name, p.name, p.culture], Color(0.7, 0.95, 0.95))
					p.convert_culture_to = ""
					p.convert_culture_months = 0.0
			# Auto-creep: very slow drift toward owner culture in unconverted provinces.
			elif p.culture != c.primary_culture and GameState.rng.randf() < 0.005:
				p.convert_culture_to = c.primary_culture
				p.convert_culture_months = 60.0
			# Unrest from mismatched religion/culture (small per-month tick).
			if p.religion != c.state_religion: p.unrest = min(p.unrest + 0.02, 10.0)
			if p.culture != c.primary_culture: p.unrest = min(p.unrest + 0.01, 10.0)
		# Upkeep
		var upkeep: float = 0.0
		for uid in c.unit_ids:
			var u: ArmyUnit = GameState.units.get(uid)
			if u == null: continue
			var ut: Dictionary = GameState.unit_types.get(u.type_id, {})
			upkeep += float(ut.get("upkeep", 0.5))
		c.gold += income - upkeep
		c.research_points += research
		c.culture_points += culture
		c.manpower_pool = min(c.manpower_pool + manpower_recover, 100000.0)
		# Auto-progress current research
		if c.current_research != "" and c.researched_techs.has(c.current_research) == false:
			var tdef: Dictionary = GameState.tech_tree.get(c.current_research, {})
			var cost: float = float(tdef.get("cost", 100))
			if c.research_points >= cost:
				c.research_points -= cost
				c.researched_techs.append(c.current_research)
				GameState.log_event("[%s] %s researched %s." % [c.id, c.name, String(tdef.get("name", c.current_research))], Color(0.6, 0.85, 1.0))
				c.current_research = ""
		GameState.country_state_changed.emit(cid)

func _on_year() -> void:
	# Yearly: relations decay toward 0, characters age.
	for a in GameState.countries.keys():
		var ca: Country = GameState.countries[a]
		if not ca.is_alive: continue
		ca.stability = clamp(ca.stability + 0.1, -3.0, 3.0)
		for b in GameState.countries.keys():
			if a == b: continue
			var v: int = GameState.relations_score(a, b)
			if v > 0:
				v = max(0, v - 1)
			elif v < 0:
				v = min(0, v + 1)
			GameState.set_relations(a, b, v)
	for ch in GameState.characters.values():
		if ch.alive:
			ch.age += 1
			if ch.age > 60 and GameState.rng.randf() < 0.10 + 0.005 * (ch.age - 60):
				ch.alive = false
				_on_character_death(ch)
	GameState.log_event("Year %d begins." % GameState.year, Color(0.9, 0.9, 0.5))

func _on_character_death(ch: Character) -> void:
	var c: Country = GameState.countries.get(ch.country_id)
	if c == null:
		return
	if ch.role == Character.Role.RULER:
		# New ruler: heir with random traits.
		var heir := Character.new()
		var pool: Array = GameState.names_db.get("ruler_names_male", ["Ruler"])
		heir.name = String(pool.pick_random()) + " II"
		heir.country_id = c.id
		heir.role = Character.Role.RULER
		heir.age = GameState.rng.randi_range(20, 35)
		heir.martial = GameState.rng.randi_range(0, 5)
		heir.diplomacy = GameState.rng.randi_range(0, 5)
		heir.stewardship = GameState.rng.randi_range(0, 5)
		heir.intrigue = GameState.rng.randi_range(0, 5)
		heir.learning = GameState.rng.randi_range(0, 5)
		var trait_keys: Array = GameState.traits_db.keys()
		var traits: Array[String] = []
		trait_keys.shuffle()
		for i in range(min(2, trait_keys.size())):
			traits.append(String(trait_keys[i]))
		heir.traits = traits
		c.ruler_id = GameState.add_character(heir)
		c.legitimacy = max(0.5, c.legitimacy - 0.2)
		c.stability = max(-3.0, c.stability - 0.5)
		GameState.log_event("[%s] %s passes; %s ascends." % [c.id, ch.name, heir.name], Color(0.95, 0.7, 0.7))
	else:
		# Drop from country lists.
		c.advisor_ids.erase(ch.id)
		c.general_ids.erase(ch.id)

func _tech_modifier(c: Country, key: String) -> float:
	var sum: float = 0.0
	for tid in c.researched_techs:
		var t: Dictionary = GameState.tech_tree.get(tid, {})
		var eff: Dictionary = t.get("effects", {})
		if eff.has(key):
			sum += float(eff[key])
	return sum

## AI for non-player countries. Lightweight tactical/strategic decisions.
extends Node

func _ready() -> void:
	TimeCtl.month_tick.connect(_on_month)

func _on_month() -> void:
	for cid in GameState.countries.keys():
		var c: Country = GameState.countries[cid]
		if not c.is_alive or c.is_player:
			continue
		_ai_run(c)

func _ai_run(c: Country) -> void:
	# 1. Pick research if none
	if c.current_research == "":
		_ai_pick_research(c)
	# 2. Recruit units if rich and undermanned
	if c.gold > 250.0 and c.unit_ids.size() < clamp(c.province_ids.size() / 6, 2, 8):
		_ai_recruit(c)
	# 3. Move units toward enemies if at war, otherwise patrol
	_ai_move_units(c)
	# 4. Diplomacy: improve relations with neighbours, occasionally declare war on weaker rivals
	_ai_diplomacy(c)

func _ai_pick_research(c: Country) -> void:
	var available: Array = []
	for tid in GameState.tech_tree.keys():
		if c.researched_techs.has(tid): continue
		var t: Dictionary = GameState.tech_tree[tid]
		var prereqs: Array = t.get("prereq", [])
		var ok := true
		for pr in prereqs:
			if not c.researched_techs.has(pr):
				ok = false
				break
		if ok:
			available.append(tid)
	if available.is_empty(): return
	available.shuffle()
	c.current_research = String(available[0])

func _ai_recruit(c: Country) -> void:
	# Find latest unlocked unit.
	var best_type := "levy"
	for uid in GameState.unit_types.keys():
		var ut: Dictionary = GameState.unit_types[uid]
		var req := String(ut.get("tech", ""))
		if req == "" or c.researched_techs.has(req):
			best_type = uid
	var ut: Dictionary = GameState.unit_types[best_type]
	var cg: float = float(ut.get("cost_gold", 30))
	var cm: float = float(ut.get("cost_manpower", 1000))
	if c.gold < cg or c.manpower_pool < cm:
		return
	c.gold -= cg
	c.manpower_pool -= cm
	var u := ArmyUnit.new()
	u.owner_id = c.id
	u.type_id = best_type
	u.name = "%s Army" % c.name
	u.province_id = c.capital_id
	u.strength = 5000
	u.max_strength = 5000
	GameState.add_unit(u)

func _ai_move_units(c: Country) -> void:
	for uid in c.unit_ids.duplicate():
		var u: ArmyUnit = GameState.units.get(uid)
		if u == null: continue
		if u.orders == "move" and u.dest_province_id != -1:
			continue
		# At war: try to march into a neighbouring enemy province.
		var current: Province = GameState.provinces[u.province_id]
		if current == null: continue
		var moved: bool = false
		if c.at_war_with.size() > 0:
			for nid in current.neighbors:
				var np: Province = GameState.provinces[nid]
				if np == null: continue
				if np.is_sea: continue
				if np.owner_id != "" and c.at_war_with.has(np.owner_id):
					_order_unit_move(u, nid)
					moved = true
					break
		if moved:
			continue
		# Else: idle / move toward capital occasionally
		if GameState.rng.randf() < 0.05 and u.province_id != c.capital_id:
			if current.neighbors.size() > 0:
				var step: int = current.neighbors[0]
				_order_unit_move(u, step)

func _order_unit_move(u: ArmyUnit, dest_id: int) -> void:
	u.dest_province_id = dest_id
	u.orders = "move"
	u.move_progress = 0.0

func _ai_diplomacy(c: Country) -> void:
	if GameState.rng.randf() < 0.20:
		# Improve relations with one random country
		var others := GameState.countries.keys().filter(func(k): return k != c.id and GameState.countries[k].is_alive)
		if others.is_empty(): return
		var target: String = String(others[GameState.rng.randi_range(0, others.size() - 1)])
		GameState.change_relations(c.id, target, 5)
	# Random declare war chance vs weak neighbours.
	if GameState.rng.randf() < 0.02 and c.gold > 300.0 and c.unit_ids.size() >= 2:
		var weak_neighbours := []
		for pid in c.province_ids:
			var p: Province = GameState.provinces[pid]
			for n in p.neighbors:
				var np: Province = GameState.provinces[n]
				if np != null and np.owner_id != "" and np.owner_id != c.id and not c.at_war_with.has(np.owner_id) and not c.allies.has(np.owner_id):
					weak_neighbours.append(np.owner_id)
		if weak_neighbours.is_empty(): return
		var target: String = String(weak_neighbours[GameState.rng.randi_range(0, weak_neighbours.size() - 1)])
		var t: Country = GameState.countries[target]
		if t.unit_ids.size() < c.unit_ids.size() and GameState.rng.randf() < 0.5:
			declare_war(c.id, target)

func declare_war(attacker: String, defender: String) -> void:
	var ca: Country = GameState.countries.get(attacker)
	var cd: Country = GameState.countries.get(defender)
	if ca == null or cd == null: return
	if ca.at_war_with.has(defender): return
	if ca.allies.has(defender): return
	ca.at_war_with.append(defender)
	cd.at_war_with.append(attacker)
	GameState.set_relations(attacker, defender, -150)
	ca.stability = max(-3.0, ca.stability - 0.5)
	cd.stability = max(-3.0, cd.stability - 1.0)
	GameState.log_event("[WAR] %s declared war on %s!" % [ca.name, cd.name], Color(1.0, 0.4, 0.4))

func make_peace(a: String, b: String) -> void:
	var ca: Country = GameState.countries.get(a)
	var cb: Country = GameState.countries.get(b)
	if ca == null or cb == null: return
	ca.at_war_with.erase(b)
	cb.at_war_with.erase(a)
	GameState.change_relations(a, b, 30)
	GameState.log_event("[PEACE] %s and %s signed a treaty." % [ca.name, cb.name], Color(0.7, 1.0, 0.7))

func form_alliance(a: String, b: String) -> void:
	var ca: Country = GameState.countries.get(a)
	var cb: Country = GameState.countries.get(b)
	if ca == null or cb == null: return
	if ca.at_war_with.has(b): return
	if not ca.allies.has(b):
		ca.allies.append(b)
	if not cb.allies.has(a):
		cb.allies.append(a)
	GameState.change_relations(a, b, 50)
	GameState.log_event("[ALLY] %s and %s formed an alliance." % [ca.name, cb.name], Color(0.6, 0.9, 1.0))

func break_alliance(a: String, b: String) -> void:
	var ca: Country = GameState.countries.get(a)
	var cb: Country = GameState.countries.get(b)
	if ca == null or cb == null: return
	ca.allies.erase(b)
	cb.allies.erase(a)
	GameState.change_relations(a, b, -40)
	GameState.log_event("[ALLY-] %s broke alliance with %s." % [ca.name, cb.name], Color(1.0, 0.7, 0.4))

func send_gift(from_id: String, to_id: String, amount: float) -> bool:
	var f: Country = GameState.countries.get(from_id)
	var t: Country = GameState.countries.get(to_id)
	if f == null or t == null or f.gold < amount: return false
	f.gold -= amount
	t.gold += amount
	GameState.change_relations(from_id, to_id, int(amount / 25.0))
	return true

func improve_relations(from_id: String, to_id: String) -> bool:
	var f: Country = GameState.countries.get(from_id)
	if f == null or f.gold < 30.0: return false
	f.gold -= 30.0
	GameState.change_relations(from_id, to_id, 12)
	return true

func fabricate_claim(from_id: String, target_province: int) -> bool:
	var f: Country = GameState.countries.get(from_id)
	var p: Province = GameState.provinces[target_province] if target_province >= 0 else null
	if f == null or p == null or f.gold < 80.0: return false
	f.gold -= 80.0
	if not f.claims.has(target_province):
		f.claims.append(target_province)
	GameState.log_event("[INTRIGUE] %s fabricated claim on %s." % [f.name, p.name], Color(0.95, 0.7, 1.0))
	GameState.change_relations(from_id, p.owner_id, -20)
	return true

func send_spy(from_id: String, to_id: String) -> bool:
	var f: Country = GameState.countries.get(from_id)
	var t: Country = GameState.countries.get(to_id)
	if f == null or t == null or f.gold < 60.0: return false
	f.gold -= 60.0
	# Steal a tech if possible
	var stealable: Array = []
	for tid in t.researched_techs:
		if not f.researched_techs.has(tid):
			stealable.append(tid)
	if stealable.is_empty():
		GameState.log_event("[INTRIGUE] %s spy returned with nothing useful." % f.name, Color(0.85, 0.85, 0.5))
		GameState.change_relations(from_id, to_id, -5)
		return true
	stealable.shuffle()
	f.researched_techs.append(String(stealable[0]))
	GameState.log_event("[INTRIGUE] %s stole tech %s from %s." % [f.name, String(stealable[0]), t.name], Color(0.95, 0.7, 1.0))
	GameState.change_relations(from_id, to_id, -25)
	return true

func attempt_assassination(from_id: String, to_id: String) -> bool:
	var f: Country = GameState.countries.get(from_id)
	var t: Country = GameState.countries.get(to_id)
	if f == null or t == null or f.gold < 150.0: return false
	f.gold -= 150.0
	var f_ruler: Character = GameState.characters.get(f.ruler_id)
	var t_ruler: Character = GameState.characters.get(t.ruler_id)
	if t_ruler == null: return false
	var f_int: int = f_ruler.intrigue if f_ruler != null else 2
	var t_int: int = t_ruler.intrigue
	var roll: float = GameState.rng.randf()
	var chance: float = clamp(0.15 + 0.05 * float(f_int - t_int), 0.05, 0.6)
	if roll < chance:
		t_ruler.alive = false
		# trigger handled by yearly tick on next pass (instant): create a new heir now
		var heir := Character.new()
		var pool: Array = GameState.names_db.get("ruler_names_male", ["Ruler"])
		heir.name = String(pool.pick_random()) + " (Successor)"
		heir.country_id = t.id
		heir.role = Character.Role.RULER
		heir.age = GameState.rng.randi_range(20, 40)
		heir.martial = GameState.rng.randi_range(0, 4)
		heir.diplomacy = GameState.rng.randi_range(0, 4)
		heir.stewardship = GameState.rng.randi_range(0, 4)
		heir.intrigue = GameState.rng.randi_range(0, 4)
		heir.learning = GameState.rng.randi_range(0, 4)
		t.ruler_id = GameState.add_character(heir)
		t.stability = max(-3.0, t.stability - 1.0)
		t.legitimacy = max(0.4, t.legitimacy - 0.3)
		GameState.log_event("[INTRIGUE] %s's ruler was assassinated! %s ascends." % [t.name, heir.name], Color(0.95, 0.4, 0.95))
		GameState.change_relations(from_id, to_id, -60)
		return true
	GameState.log_event("[INTRIGUE] Assassination attempt against %s failed." % t.name, Color(0.85, 0.85, 0.5))
	GameState.change_relations(from_id, to_id, -10)
	return false

## Tick-driven unit movement & battle resolution. Attached to Game scene.
class_name MovementBattle
extends Node

const MOVE_DAYS_PER_HEX: float = 12.0

func _ready() -> void:
	TimeCtl.day_tick.connect(_on_day)

func _on_day() -> void:
	# Process moves
	for uid in GameState.units.keys():
		var u: ArmyUnit = GameState.units[uid]
		if u == null: continue
		if u.orders == "move" and u.dest_province_id != -1:
			u.move_progress += 1.0 / MOVE_DAYS_PER_HEX
			if u.move_progress >= 1.0:
				_arrive(u)

	# Cleanup dead countries (no provinces and no units)
	for cid in GameState.countries.keys():
		var c: Country = GameState.countries[cid]
		if c.is_alive and c.province_ids.is_empty() and c.unit_ids.is_empty():
			c.is_alive = false
			GameState.log_event("[FALL] %s has been wiped from history." % c.name, Color(1.0, 0.3, 0.3))

func _arrive(u: ArmyUnit) -> void:
	var dest: Province = GameState.provinces[u.dest_province_id]
	if dest == null:
		u.orders = "idle"
		u.dest_province_id = -1
		u.move_progress = 0.0
		return
	# Battle if there are enemy units in dest
	var defenders: Array[int] = []
	var c: Country = GameState.countries.get(u.owner_id)
	for ouid in GameState.units.keys():
		var ou: ArmyUnit = GameState.units[ouid]
		if ou.id == u.id: continue
		if ou.province_id != dest.id: continue
		if ou.owner_id == u.owner_id: continue
		# enemy if at war
		if c != null and c.at_war_with.has(ou.owner_id):
			defenders.append(ou.id)
	if defenders.size() > 0:
		_resolve_battle(u, defenders, dest)
		# Survivor stays, winner takes province if no defenders left
		if GameState.units.has(u.id):
			u.province_id = dest.id
			u.dest_province_id = -1
			u.move_progress = 0.0
			u.orders = "idle"
			_attempt_capture(u, dest)
	else:
		u.province_id = dest.id
		u.dest_province_id = -1
		u.move_progress = 0.0
		u.orders = "idle"
		_attempt_capture(u, dest)

func _resolve_battle(attacker: ArmyUnit, defenders: Array[int], dest: Province) -> void:
	# Sum side strengths weighted by unit type stats + general bonuses + terrain.
	var atk_pow: float = _unit_combat_power(attacker, false)
	var def_pow: float = 0.0
	for did in defenders:
		var du: ArmyUnit = GameState.units[did]
		def_pow += _unit_combat_power(du, true) * (1.0 + dest.combat_bonus_for_defender())
	# Garrison contributes to defender side as well
	if dest.garrison > 0 and dest.owner_id != attacker.owner_id:
		def_pow += float(dest.garrison) * 0.5
	# Roll outcome
	var atk_roll: float = atk_pow * GameState.rng.randf_range(0.85, 1.20)
	var def_roll: float = def_pow * GameState.rng.randf_range(0.85, 1.20)
	var total: float = max(atk_roll + def_roll, 1.0)
	# Casualties proportional to opponent share
	var atk_loss: float = clamp(def_roll / total, 0.10, 0.85)
	var def_loss: float = clamp(atk_roll / total, 0.10, 0.85)

	var atk_country: Country = GameState.countries.get(attacker.owner_id)
	var def_country: Country = GameState.countries.get(GameState.units[defenders[0]].owner_id) if defenders.size() > 0 else null

	attacker.strength = max(0, int(attacker.strength * (1.0 - atk_loss)))
	attacker.morale = max(0.05, attacker.morale - 0.15 * atk_loss)
	for did in defenders:
		var du: ArmyUnit = GameState.units[did]
		du.strength = max(0, int(du.strength * (1.0 - def_loss)))
		du.morale = max(0.05, du.morale - 0.15 * def_loss)

	var att_name: String = atk_country.name if atk_country != null else attacker.owner_id
	var def_name: String = def_country.name if def_country != null else "Defenders"
	if atk_roll > def_roll:
		GameState.log_event("[BATTLE] %s defeated %s at %s." % [att_name, def_name, dest.name], Color(0.95, 0.5, 0.4))
		# Eliminate destroyed defender stacks
		for did in defenders:
			var du: ArmyUnit = GameState.units.get(did)
			if du != null and du.strength <= 200:
				GameState.remove_unit(did)
	else:
		GameState.log_event("[BATTLE] %s repulsed %s at %s." % [def_name, att_name, dest.name], Color(0.95, 0.5, 0.4))
		if attacker.strength <= 200:
			GameState.remove_unit(attacker.id)
			# Roll back move
			return
		# Repulsed: bounce back to source
		var nbs: Array = dest.neighbors
		if nbs.size() > 0:
			attacker.province_id = int(nbs[0])
		attacker.dest_province_id = -1
		attacker.orders = "idle"
		attacker.move_progress = 0.0

func _attempt_capture(u: ArmyUnit, dest: Province) -> void:
	if dest.owner_id == u.owner_id: return
	if dest.owner_id == "":
		# Colonize uncolonized province
		dest.owner_id = u.owner_id
		var c: Country = GameState.countries.get(u.owner_id)
		if c != null and not c.province_ids.has(dest.id):
			c.province_ids.append(dest.id)
		GameState.log_event("[OCC] %s claimed %s." % [u.owner_id, dest.name], Color(0.7, 0.9, 1.0))
		return
	var prev_owner: Country = GameState.countries.get(dest.owner_id)
	var c: Country = GameState.countries.get(u.owner_id)
	if c == null: return
	if not c.at_war_with.has(dest.owner_id):
		# Not at war - cannot capture
		return
	# Transfer province
	if prev_owner != null:
		prev_owner.province_ids.erase(dest.id)
	dest.owner_id = u.owner_id
	dest.unrest = 4.0 # fresh occupation
	if not c.province_ids.has(dest.id):
		c.province_ids.append(dest.id)
	c.prestige = clamp(c.prestige + 5.0, -100.0, 100.0)
	if prev_owner != null:
		prev_owner.prestige = clamp(prev_owner.prestige - 5.0, -100.0, 100.0)
		# If conquering capital, severe stability hit + maybe collapse
		if dest.is_capital:
			prev_owner.stability = max(-3.0, prev_owner.stability - 1.5)
			GameState.log_event("[CAPITAL!] %s seized %s's capital %s!" % [c.name, prev_owner.name, dest.name], Color(1.0, 0.5, 0.5))
			# move capital to a remaining province if any
			if prev_owner.province_ids.size() > 0:
				prev_owner.capital_id = prev_owner.province_ids[0]
				GameState.provinces[prev_owner.capital_id].is_capital = true
			dest.is_capital = false
	GameState.log_event("[OCC] %s captured %s from %s." % [c.name, dest.name, prev_owner.name if prev_owner else "?"], Color(0.95, 0.7, 0.4))

func _unit_combat_power(u: ArmyUnit, is_defender: bool) -> float:
	var ut: Dictionary = GameState.unit_types.get(u.type_id, {})
	var atk: float = float(ut.get("attack", 5))
	var def: float = float(ut.get("defense", 5))
	var disc: float = float(ut.get("discipline", 0.7))
	var stat: float = def if is_defender else atk
	var p: float = stat * disc * (float(u.strength) / 1000.0) * u.morale
	# General bonus
	var gen: Character = GameState.characters.get(u.general_id)
	if gen == null:
		# pick from country generals
		var c: Country = GameState.countries.get(u.owner_id)
		if c != null and c.general_ids.size() > 0:
			gen = GameState.characters.get(c.general_ids[0])
	if gen != null:
		p *= 1.0 + 0.05 * gen.martial
		if gen.traits.has("brilliant_strategist"):
			p *= 1.10
		if gen.traits.has("craven"):
			p *= 0.90
	return p

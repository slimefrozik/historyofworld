## Army unit (a stack of soldiers stationed/marching on the map).
class_name ArmyUnit
extends RefCounted

var id: int = -1
var owner_id: String = ""
var type_id: String = "levy" # references unit_types data
var name: String = ""
var province_id: int = -1
var dest_province_id: int = -1
var move_progress: float = 0.0 # 0..1 along edge to dest
var strength: int = 1000
var max_strength: int = 1000
var morale: float = 1.0
var general_id: int = -1
var path: Array[int] = []
var orders: String = "idle" # idle, move, attack, garrison

func to_dict() -> Dictionary:
	return {
		"id": id, "owner_id": owner_id, "type_id": type_id, "name": name,
		"province_id": province_id, "dest_province_id": dest_province_id,
		"move_progress": move_progress, "strength": strength, "max_strength": max_strength,
		"morale": morale, "general_id": general_id, "path": path, "orders": orders,
	}

static func from_dict(d: Dictionary) -> ArmyUnit:
	var u := ArmyUnit.new()
	u.id = int(d.get("id", -1))
	u.owner_id = String(d.get("owner_id", ""))
	u.type_id = String(d.get("type_id", "levy"))
	u.name = String(d.get("name", ""))
	u.province_id = int(d.get("province_id", -1))
	u.dest_province_id = int(d.get("dest_province_id", -1))
	u.move_progress = float(d.get("move_progress", 0.0))
	u.strength = int(d.get("strength", 1000))
	u.max_strength = int(d.get("max_strength", 1000))
	u.morale = float(d.get("morale", 1.0))
	u.general_id = int(d.get("general_id", -1))
	u.path.assign(d.get("path", []))
	u.orders = String(d.get("orders", "idle"))
	return u

class_name EquipCalc
extends RefCounted
## 装备词条汇总：把一组装备 id 的主/副词条累加成 Unit.equip_bonus 用的字典。
## 词条键与 Unit.recompute() 一致：hp / mp / atk / matk / def / spd / crit。

static func bonus_of(equip_ids: Array) -> Dictionary:
	var b: Dictionary = {}
	for id in equip_ids:
		var row: Dictionary = DataManager.get_equipment(String(id))
		if row.is_empty():
			continue
		_add(b, String(row.get("main_stat", "none")), row.get("main_value", 0))
		_add(b, String(row.get("sub_stat", "none")), row.get("sub_value", 0))
	return b


## 便捷方法：把一组装备穿到角色单位上并重算属性
static func equip(unit: Unit, equip_ids: Array) -> Unit:
	unit.equip_bonus = bonus_of(equip_ids)
	unit.recompute()
	return unit


static func _add(b: Dictionary, stat: String, val) -> void:
	if stat == "" or stat == "none":
		return
	b[stat] = float(b.get(stat, 0.0)) + float(val)

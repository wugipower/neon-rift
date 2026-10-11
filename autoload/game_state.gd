extends Node
## GameState（全局单例）：一局游戏的持久状态——队伍、金钱、背包、装备、
## 剧情标记、节点进度。菜单/据点/地图/战斗都读写它。可无头测试。
##
## 队伍成员结构：{"id":String, "level":int, "exp":int, "equipment":Array[String]}
## 说明：每场战斗都用 build_party_units() 以满状态重建 Unit，
##       因此队伍生命在战斗之间自动回满（据点即休整点）。

const START_LEVEL := 3
const START_GOLD := 150

var started: bool = false
var party: Array = []
var gold: int = 0
var items: Dictionary = {}            # item_id -> 数量
var owned_equips: Array = []          # 已拥有的装备 id
var flags: Dictionary = {}            # 剧情标记 -> true
var completed: Array = []             # 已完成节点 id
var current_node: String = ""         # 主线前沿节点

# 进入战斗前由地图设置，战斗场景读取
var pending_node: String = ""
var pending_enemies: Array = []


# ---------------- 开局 / 存档 ----------------

func new_game() -> void:
	party.clear()
	for cid in ["lin", "cang", "miao"]:
		party.append({"id": cid, "level": START_LEVEL, "exp": 0, "equipment": []})
	gold = START_GOLD
	items = {"i_potion_small": 2}
	owned_equips = []
	flags = {}
	completed = []
	current_node = String(DataManager.node_order[0]) if DataManager.node_order.size() > 0 else ""
	pending_node = ""
	pending_enemies = []
	started = true


func to_dict() -> Dictionary:
	return {
		"party": party.duplicate(true),
		"gold": gold,
		"items": items.duplicate(true),
		"owned_equips": owned_equips.duplicate(true),
		"flags": flags.duplicate(true),
		"completed": completed.duplicate(true),
		"current_node": current_node,
	}


func from_dict(d: Dictionary) -> void:
	party.clear()
	for m in d.get("party", []):
		var eq: Array = []
		for e in m.get("equipment", []):
			eq.append(String(e))
		party.append({
			"id": String(m.get("id", "")),
			"level": int(m.get("level", 1)),
			"exp": int(m.get("exp", 0)),
			"equipment": eq,
		})
	gold = int(d.get("gold", 0))
	items.clear()
	var raw_items = d.get("items", {})
	for k in raw_items:
		items[String(k)] = int(raw_items[k])
	owned_equips.clear()
	for e in d.get("owned_equips", []):
		owned_equips.append(String(e))
	flags.clear()
	var raw_flags = d.get("flags", {})
	for k in raw_flags:
		flags[String(k)] = true
	completed.clear()
	for c in d.get("completed", []):
		completed.append(String(c))
	current_node = String(d.get("current_node", ""))
	pending_node = ""
	pending_enemies = []
	started = party.size() > 0


func save_game() -> bool:
	return SaveGame.write(to_dict())


func load_game() -> bool:
	var d := SaveGame.read()
	if d.is_empty():
		return false
	from_dict(d)
	return started


func has_save() -> bool:
	return SaveGame.exists()


# ---------------- 队伍 / 单位构建 ----------------

func build_party_units() -> Array:
	var units: Array = []
	for m in party:
		var row: Dictionary = DataManager.get_character(String(m["id"]))
		if row.is_empty():
			continue
		var u := Unit.from_character(row, int(m["level"]))
		var eq: Array = []
		for e in m.get("equipment", []):
			eq.append(String(e))
		EquipCalc.equip(u, eq)   # 重算属性并回满血/蓝
		units.append(u)
	return units


func build_enemy_units(enemy_ids: Array) -> Array:
	var units: Array = []
	for eid in enemy_ids:
		var row: Dictionary = DataManager.get_enemy(String(eid))
		if row.is_empty():
			continue
		units.append(Unit.from_enemy(row))
	return units


func party_summary() -> Array:
	var out: Array = []
	for m in party:
		var row: Dictionary = DataManager.get_character(String(m["id"]))
		out.append({
			"id": String(m["id"]),
			"name": String(row.get("name", m["id"])),
			"element": String(row.get("element", "无")),
			"level": int(m["level"]),
			"exp": int(m["exp"]),
			"exp_next": DataManager.get_exp_to_next(int(m["level"])),
			"equipment": m.get("equipment", []),
		})
	return out


# ---------------- 战斗奖励 / 升级 ----------------

## 战斗胜利后结算：经验(全队共享)、金钱、掉落，并处理升级。返回汇总字典。
func apply_battle_reward(enemy_ids: Array) -> Dictionary:
	var total_exp: int = 0
	var total_gold: int = 0
	var dropped: Array = []
	for eid in enemy_ids:
		var row: Dictionary = DataManager.get_enemy(String(eid))
		if row.is_empty():
			continue
		total_exp += int(row.get("exp_reward", 0))
		total_gold += int(row.get("gold_reward", 0))
		for it in DataManager.roll_drops(String(row.get("drop_id", ""))):
			add_item(String(it), 1)
			dropped.append(String(it))
	gold += total_gold

	var levelups: Array = []
	for m in party:
		var r: Dictionary = Progression.add_exp(int(m["level"]), int(m["exp"]), total_exp)
		if bool(r["leveled"]):
			levelups.append({"id": String(m["id"]), "level": int(r["level"])})
		m["level"] = int(r["level"])
		m["exp"] = int(r["exp"])
	return {"exp": total_exp, "gold": total_gold, "drops": dropped, "levelups": levelups}


# ---------------- 背包 / 商店 / 装备 ----------------

func add_item(item_id: String, count: int = 1) -> void:
	if item_id == "":
		return
	items[item_id] = int(items.get(item_id, 0)) + count


func item_count(item_id: String) -> int:
	return int(items.get(item_id, 0))


func price_of(kind: String, ref_id: String) -> int:
	if kind == "item":
		return int(DataManager.get_item(ref_id).get("price", 0))
	if kind == "equip":
		return int(DataManager.get_equipment(ref_id).get("price", 0))
	return 0


## 购买；余额不足返回 false
func buy(kind: String, ref_id: String) -> bool:
	var price: int = price_of(kind, ref_id)
	if price <= 0 or gold < price:
		return false
	gold -= price
	if kind == "item":
		add_item(ref_id, 1)
	else:
		if not owned_equips.has(ref_id):
			owned_equips.append(ref_id)
	return true


## 给角色穿装备：先从全队卸下同一件，再穿到目标；按槽位替换旧装备。
func equip_to(char_id: String, equip_id: String) -> bool:
	if not owned_equips.has(equip_id):
		return false
	var slot: String = String(DataManager.get_equipment(equip_id).get("slot", ""))
	# 从所有成员身上移除这件（避免一件装备被两人同时穿）
	for m in party:
		var kept: Array = []
		for e in m.get("equipment", []):
			if String(e) != equip_id:
				kept.append(String(e))
		m["equipment"] = kept
	# 目标角色按槽位替换
	for m in party:
		if String(m["id"]) == char_id:
			var neweq: Array = []
			for e in m.get("equipment", []):
				if String(DataManager.get_equipment(String(e)).get("slot", "")) != slot:
					neweq.append(String(e))
			neweq.append(equip_id)
			m["equipment"] = neweq
			return true
	return false


# ---------------- 节点进度 ----------------

func next_of(node_id: String) -> Array:
	var node: Dictionary = DataManager.get_node_data(node_id)
	var raw: String = String(node.get("next", ""))
	var out: Array = []
	for part in raw.split("|"):
		if part.strip_edges() != "":
			out.append(part.strip_edges())
	return out


func is_completed(node_id: String) -> bool:
	return completed.has(node_id)


## 一个节点当前是否可进入：是主线前沿，或是某个已完成节点的后续，且自身未完成
func is_node_open(node_id: String) -> bool:
	if is_completed(node_id):
		return false
	if node_id == current_node:
		return true
	for cid in completed:
		if next_of(String(cid)).has(node_id):
			return true
	return false


## 完成节点：记录、置剧情标记、推进主线前沿
func complete_node(node_id: String) -> void:
	if not completed.has(node_id):
		completed.append(node_id)
	var node: Dictionary = DataManager.get_node_data(node_id)
	var flag: String = String(node.get("flag", ""))
	if flag != "":
		flags[flag] = true
	if node_id == current_node:
		var nx: Array = next_of(node_id)
		current_node = String(nx[0]) if nx.size() > 0 else ""


func has_flag(flag: String) -> bool:
	return flags.get(flag, false)


func is_finished() -> bool:
	return has_flag("finished")


## 设置即将进入的战斗（地图在切场景前调用）
func set_pending_battle(node_id: String) -> void:
	pending_node = node_id
	pending_enemies = []
	var node: Dictionary = DataManager.get_node_data(node_id)
	for part in String(node.get("enemies", "")).split("|"):
		if part.strip_edges() != "":
			pending_enemies.append(part.strip_edges())

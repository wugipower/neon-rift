extends Node
## DataManager（全局单例 / Autoload）
## 游戏启动时把 data/ 下所有 CSV 读入内存字典，供全项目查询。
## 目的：数值全部来自表，改平衡只改 CSV，不改代码。

const DATA_DIR := "res://data/"

# id -> 行字典
var characters: Dictionary = {}
var skills: Dictionary = {}
var enemies: Dictionary = {}
var equipment: Dictionary = {}
var items: Dictionary = {}
# status_id -> {name, kind, value, desc}
var status_effects: Dictionary = {}
# node_id -> 行字典（节点图）
var nodes: Dictionary = {}
# 节点在表中的先后顺序（用于线性推进参考）
var node_order: Array = []
# dialogue_id -> Array[{line:int, speaker:String, text:String}]（已按 line 排序）
var dialogues: Dictionary = {}
# shop_id -> Array[{kind:String, ref_id:String}]
var shops: Dictionary = {}
# level(int) -> {exp_to_next, exp_total}
var levels: Dictionary = {}
# enemy_id -> Array[{skill_id, weight, condition}]
var enemy_ai: Dictionary = {}
# drop_id -> Array[{item_id, chance}]
var drops: Dictionary = {}
# "攻击元素|防守元素" -> 系数(float)
var elements: Dictionary = {}


func _ready() -> void:
	load_all()


func load_all() -> void:
	# 单键表：以 id 建索引
	characters = _index_by_id(_load_csv(DATA_DIR + "characters.csv"), "id")
	skills = _index_by_id(_load_csv(DATA_DIR + "skills.csv"), "id")
	enemies = _index_by_id(_load_csv(DATA_DIR + "enemies.csv"), "id")
	equipment = _index_by_id(_load_csv(DATA_DIR + "equipment.csv"), "id")
	items = _index_by_id(_load_csv(DATA_DIR + "items.csv"), "id")
	status_effects = _index_by_id(_load_csv(DATA_DIR + "status_effects.csv"), "id")

	# 等级表：以 level 建索引
	for row in _load_csv(DATA_DIR + "levels.csv"):
		levels[int(row["level"])] = {
			"exp_to_next": int(row["exp_to_next"]),
			"exp_total": int(row["exp_total"]),
		}

	# 敌人 AI：按 enemy_id 分组
	enemy_ai.clear()
	for row in _load_csv(DATA_DIR + "enemy_ai.csv"):
		var eid: String = row["enemy_id"]
		if not enemy_ai.has(eid):
			enemy_ai[eid] = []
		enemy_ai[eid].append({
			"skill_id": row["skill_id"],
			"weight": float(row["weight"]),
			"condition": row["condition"],
		})

	# 掉落表：按 drop_id 分组
	drops.clear()
	for row in _load_csv(DATA_DIR + "drops.csv"):
		var did: String = row["drop_id"]
		if not drops.has(did):
			drops[did] = []
		drops[did].append({
			"item_id": row["item_id"],
			"chance": float(row["chance"]),
		})

	# 元素克制：以 "攻|守" 建索引
	elements.clear()
	for row in _load_csv(DATA_DIR + "elements.csv"):
		var key: String = row["attacker_element"] + "|" + row["defender_element"]
		elements[key] = float(row["multiplier"])

	# 节点图：id 索引 + 顺序表
	nodes = _index_by_id(_load_csv(DATA_DIR + "nodes.csv"), "id")
	node_order.clear()
	for row in _load_csv(DATA_DIR + "nodes.csv"):
		if String(row.get("id", "")) != "":
			node_order.append(String(row["id"]))

	# 对话：按 id 分组，组内按 line 升序
	dialogues.clear()
	for row in _load_csv(DATA_DIR + "dialogues.csv"):
		var did: String = row["id"]
		if not dialogues.has(did):
			dialogues[did] = []
		dialogues[did].append({
			"line": int(row["line"]),
			"speaker": row["speaker"],
			"text": row["text"],
		})
	for did2 in dialogues:
		dialogues[did2].sort_custom(func(a, b): return int(a["line"]) < int(b["line"]))

	# 商店：按 shop_id 分组
	shops.clear()
	for row in _load_csv(DATA_DIR + "shops.csv"):
		var sid: String = row["shop_id"]
		if not shops.has(sid):
			shops[sid] = []
		shops[sid].append({"kind": row["ref_kind"], "ref_id": row["ref_id"]})

	print("[DataManager] 加载完成  角色%d 技能%d 敌人%d 装备%d 消耗品%d 状态%d 等级%d AI组%d 掉落组%d 元素%d 节点%d 对话%d 商店%d" % [
		characters.size(), skills.size(), enemies.size(), equipment.size(),
		items.size(), status_effects.size(), levels.size(), enemy_ai.size(), drops.size(),
		elements.size(), nodes.size(), dialogues.size(), shops.size(),
	])


# ---------- 查询接口 ----------

func get_character(id: String) -> Dictionary:
	return characters.get(id, {})

func get_skill(id: String) -> Dictionary:
	return skills.get(id, {})

func get_enemy(id: String) -> Dictionary:
	return enemies.get(id, {})

func get_equipment(id: String) -> Dictionary:
	return equipment.get(id, {})

func get_item(id: String) -> Dictionary:
	return items.get(id, {})

## 状态效果定义：{name, kind, value, desc}；不存在返回空字典
func get_status(id: String) -> Dictionary:
	return status_effects.get(id, {})

func get_enemy_ai(enemy_id: String) -> Array:
	return enemy_ai.get(enemy_id, [])

func get_drops(drop_id: String) -> Array:
	return drops.get(drop_id, [])

## 节点行字典（含 chapter/name/type/enemies/dialogue/next/flag/x/y）
func get_node_data(id: String) -> Dictionary:
	return nodes.get(id, {})

## 对话：返回按 line 排好序的 Array[{speaker,text}]
func get_dialogue(id: String) -> Array:
	return dialogues.get(id, [])

## 商店货架：Array[{kind, ref_id}]
func get_shop(shop_id: String) -> Array:
	return shops.get(shop_id, [])

func get_exp_to_next(level: int) -> int:
	if levels.has(level):
		return int(levels[level]["exp_to_next"])
	return 0


## 元素克制系数：无属性/同属性恒为 1.0，其余查表，缺省 1.0
func get_element_multiplier(atk_element: String, def_element: String) -> float:
	if atk_element == "无" or def_element == "无":
		return 1.0
	if atk_element == def_element:
		return 1.0
	return float(elements.get(atk_element + "|" + def_element, 1.0))


## 根据掉落表 roll 出实际掉落的物品 id 列表
func roll_drops(drop_id: String) -> Array:
	var result: Array = []
	for entry in get_drops(drop_id):
		if randf() <= float(entry["chance"]):
			result.append(entry["item_id"])
	return result


# ---------- 内部工具 ----------

## 读取一个 CSV，返回「表头->值」字典组成的数组
func _load_csv(path: String) -> Array:
	var rows: Array = []
	if not FileAccess.file_exists(path):
		push_error("[DataManager] CSV 文件不存在: " + path)
		return rows
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("[DataManager] 无法打开: " + path)
		return rows
	var header: PackedStringArray = f.get_csv_line()
	while not f.eof_reached():
		var line: PackedStringArray = f.get_csv_line()
		# 跳过空行 / 读到文件末尾返回的空数组
		if line.size() == 0:
			continue
		if line.size() == 1 and line[0].strip_edges() == "":
			continue
		var row := {}
		for i in header.size():
			row[header[i]] = line[i] if i < line.size() else ""
		rows.append(row)
	f.close()
	return rows


## 把行数组按指定键建索引成字典
func _index_by_id(rows: Array, key: String) -> Dictionary:
	var dict := {}
	for row in rows:
		if row.has(key) and String(row[key]) != "":
			dict[row[key]] = row
	return dict

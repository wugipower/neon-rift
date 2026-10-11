class_name Unit
extends RefCounted
## 一个战斗单位（角色或敌人）的运行时数据。
## 角色：属性由一级属性 + 等级派生（走 StatFormula）。
## 敌人：属性直接读 CSV 固定值（便于手工精调每场战斗）。

var uid: String = ""
var display_name: String = ""
var element: String = "无"
var is_enemy: bool = false
var level: int = 1

# 一级属性（角色成长用）
var vit: float = 0.0
var strength: float = 0.0
var intellect: float = 0.0
var agility: float = 0.0

# 二级/最终战斗属性
var hp_max: int = 1
var mp_max: int = 0
var atk: float = 0.0
var matk: float = 0.0
var def: float = 0.0
var spd: float = 0.0
var crit: float = 0.0
var eva: float = 0.0

# 当前值
var hp: int = 1
var mp: int = 0

# 装备加成（P5 接入；此处预留，派生时叠加）
var equip_bonus: Dictionary = {}


## 从 characters.csv 的一行 + 等级，构建玩家角色单位
static func from_character(row: Dictionary, lvl: int) -> Unit:
	var u := Unit.new()
	u.uid = row.get("id", "")
	u.display_name = row.get("name", "")
	u.element = row.get("element", "无")
	u.is_enemy = false
	u.level = lvl
	u.vit = StatFormula.primary_at_level(float(row.get("base_vit", 0)), float(row.get("grow_vit", 0)), lvl)
	u.strength = StatFormula.primary_at_level(float(row.get("base_str", 0)), float(row.get("grow_str", 0)), lvl)
	u.intellect = StatFormula.primary_at_level(float(row.get("base_int", 0)), float(row.get("grow_int", 0)), lvl)
	u.agility = StatFormula.primary_at_level(float(row.get("base_agi", 0)), float(row.get("grow_agi", 0)), lvl)
	u.recompute()
	return u


## 从 enemies.csv 的一行，构建敌人单位（固定属性）
static func from_enemy(row: Dictionary) -> Unit:
	var u := Unit.new()
	u.uid = row.get("id", "")
	u.display_name = row.get("name", "")
	u.element = row.get("element", "无")
	u.is_enemy = true
	u.level = int(row.get("level", 1))
	u.hp_max = int(row.get("hp", 1))
	u.mp_max = int(row.get("mp", 0))
	u.atk = float(row.get("atk", 0))
	u.matk = float(row.get("matk", 0))
	u.def = float(row.get("def", 0))
	u.spd = float(row.get("spd", 0))
	u.crit = float(row.get("crit", 0))
	u.eva = 0.0
	u.hp = u.hp_max
	u.mp = u.mp_max
	return u


## 重新派生角色的二级属性（升级或换装备后调用）
func recompute() -> void:
	var d: Dictionary = StatFormula.derive(vit, strength, intellect, agility, level)
	hp_max = int(d["hp_max"]) + int(equip_bonus.get("hp", 0))
	mp_max = int(d["mp_max"]) + int(equip_bonus.get("mp", 0))
	atk = float(d["atk"]) + float(equip_bonus.get("atk", 0))
	matk = float(d["matk"]) + float(equip_bonus.get("matk", 0))
	def = float(d["def"]) + float(equip_bonus.get("def", 0))
	spd = float(d["spd"]) + float(equip_bonus.get("spd", 0))
	crit = float(d["crit"]) + float(equip_bonus.get("crit", 0))
	eva = float(d["eva"])
	hp = hp_max
	mp = mp_max


func is_alive() -> bool:
	return hp > 0

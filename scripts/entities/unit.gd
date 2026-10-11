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

# 状态效果（P5）：激活中的 StatusEffect 列表 + 护盾池
var statuses: Array = []
var shield: int = 0


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


# ---------- P5：状态效果 ----------

## 累加某类状态的数值（同类可叠加，如两层灼烧）
func _sum_kind(kind: String) -> float:
	var total: float = 0.0
	for s in statuses:
		if s.kind == kind:
			total += s.value
	return total


## 有效战斗属性 = 基础派生值 * (1 + 状态修正)
func eff_atk() -> float:
	return atk * (1.0 + _sum_kind("atk_pct"))

func eff_matk() -> float:
	return matk * (1.0 + _sum_kind("atk_pct"))

func eff_def() -> float:
	return def * (1.0 + _sum_kind("def_pct"))

func eff_spd() -> float:
	return spd * (1.0 + _sum_kind("spd_pct"))


## 施加一个状态；同类已存在则刷新为较长回合数。返回是否成功施加。
func apply_status(status_id: String, turns: int) -> bool:
	if status_id == "" or status_id == "none":
		return false
	if DataManager.get_status(status_id).is_empty():
		return false
	for s in statuses:
		if s.id == status_id:
			s.turns_left = maxi(s.turns_left, maxi(1, turns))
			return true
	var s := StatusEffect.create(status_id, turns, hp_max)
	if s == null:
		return false
	if s.kind == "shield_pct":
		shield += s.shield_amount
	statuses.append(s)
	return true


## 回合开始：先结算持续伤害(DoT)/持续治疗(HoT)。返回 {"dot":int,"hot":int}
func on_turn_start() -> Dictionary:
	var info := {"dot": 0, "hot": 0}
	var dot: float = _sum_kind("dot_pct")
	if dot > 0.0 and is_alive():
		var dmg: int = maxi(1, int(round(hp_max * dot)))
		hp = maxi(0, hp - dmg)
		info["dot"] = dmg
	var hot: float = _sum_kind("hot_pct")
	if hot > 0.0 and is_alive():
		var heal: int = int(round(hp_max * hot))
		hp = mini(hp_max, hp + heal)
		info["hot"] = heal
	return info


## 回合结束前递减所有状态回合数，移除到期状态。返回到期状态名列表。
func tick_durations() -> Array:
	var expired: Array = []
	var keep: Array = []
	for s in statuses:
		s.turns_left -= 1
		if s.turns_left <= 0:
			if s.kind == "shield_pct":
				shield = maxi(0, shield - s.shield_amount)
			expired.append(s.effect_name)
		else:
			keep.append(s)
	statuses = keep
	return expired


## 感电判定：是否因感电跳过本次行动
func roll_skip() -> bool:
	var c: float = _sum_kind("skip_chance")
	return c > 0.0 and randf() < c


## 承受伤害：先扣护盾再扣血。返回 {"absorbed":int,"hp_lost":int,"died":bool}
func take_damage(amount: int) -> Dictionary:
	var to_shield: int = mini(shield, amount)
	shield -= to_shield
	var to_hp: int = amount - to_shield
	hp = maxi(0, hp - to_hp)
	return {"absorbed": to_shield, "hp_lost": to_hp, "died": hp <= 0}


## 当前状态名列表（供 UI 显示）
func status_names() -> Array:
	var out: Array = []
	for s in statuses:
		out.append("%s(%d)" % [s.effect_name, s.turns_left])
	return out


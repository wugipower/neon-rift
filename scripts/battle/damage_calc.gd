class_name DamageCalc
extends RefCounted
## 伤害/治疗计算器（对应 docs/数值设计.md「伤害公式」）。
## 纯静态逻辑，不依赖场景，便于单元测试。

const CRIT_MULT := 1.5      # 暴击倍率
const MIN_HIT_CHANCE := 50.0  # 最低命中率(%)


## 普通攻击：视作 power=1.0 的物理技能，元素取攻击者自身元素
static func basic_attack(actor: Unit) -> Dictionary:
	return {
		"id": "basic", "name": "攻击",
		"element": actor.element,
		"damage_type": "physical", "power": 1.0,
	}


## 计算一次技能结算。返回事件字典：
## hit / damage / crit / element_mult / mitigation / is_heal / raw
static func compute(attacker: Unit, defender: Unit, skill: Dictionary) -> Dictionary:
	var dtype: String = skill.get("damage_type", "physical")
	var power: float = float(skill.get("power", 1.0))
	var elem: String = skill.get("element", "无")

	# 命中判定：命中率 = clamp(100 - 守方闪避, 50, 100)
	var hit_chance: float = clampf(100.0 - defender.eva, MIN_HIT_CHANCE, 100.0)
	if randf() * 100.0 >= hit_chance:
		return {"hit": false, "damage": 0, "crit": false, "element_mult": 1.0,
				"mitigation": 0.0, "is_heal": false, "raw": 0.0}

	# 治疗：治疗量 = power * MATK，不受减伤影响
	if dtype == "heal":
		var amount: int = int(round(power * attacker.matk))
		return {"hit": true, "damage": amount, "crit": false, "element_mult": 1.0,
				"mitigation": 0.0, "is_heal": true, "raw": float(amount)}

	# 伤害：护甲递减减伤
	var atk_stat: float = attacker.atk if dtype == "physical" else attacker.matk
	var k: float = 100.0 + 10.0 * float(attacker.level)
	var mitigation: float = defender.def / (defender.def + k)
	var element_mult: float = DataManager.get_element_multiplier(elem, defender.element)
	var variance: float = randf_range(0.95, 1.05)
	var is_crit: bool = randf() * 100.0 < attacker.crit
	var crit_mult: float = CRIT_MULT if is_crit else 1.0

	var raw: float = power * atk_stat * (1.0 - mitigation) * element_mult * variance * crit_mult
	var damage: int = maxi(1, int(round(raw)))
	return {"hit": true, "damage": damage, "crit": is_crit, "element_mult": element_mult,
			"mitigation": mitigation, "is_heal": false, "raw": raw}

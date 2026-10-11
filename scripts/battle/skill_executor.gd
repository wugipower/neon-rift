class_name SkillExecutor
extends RefCounted
## 技能结算器（纯逻辑）：扣蓝 → 选目标 → 逐个结算伤害/治疗 → 施加状态。
## 目标选择规则（无 UI 时的默认，可被 explicit_target 覆盖）：
##   enemy_one  → 首个存活敌方 ; ally_one → 血量百分比最低的己方（含自身）
##   enemy_all / ally_all → 全体 ; self → 施法者

static func can_cast(caster: Unit, skill: Dictionary) -> bool:
	return caster.mp >= int(skill.get("mp_cost", 0))


## 结算一次施法。返回 {"skill","caster","targets","events","cost"}
static func cast(caster: Unit, skill: Dictionary, allies: Array, foes: Array,
		explicit_target: Unit = null) -> Dictionary:
	var cost: int = int(skill.get("mp_cost", 0))
	caster.mp = maxi(0, caster.mp - cost)

	var dtype: String = skill.get("damage_type", "physical")
	var targets: Array = resolve_targets(caster, skill, allies, foes, explicit_target)

	var events: Array = []
	for t in targets:
		if t == null:
			continue
		events.append(_apply_one(caster, t, skill, dtype))

	return {"skill": skill, "caster": caster, "targets": targets,
			"events": events, "cost": cost}


## 选出技能作用的目标列表
static func resolve_targets(caster: Unit, skill: Dictionary, allies: Array, foes: Array,
		explicit_target: Unit = null) -> Array:
	var tgt: String = skill.get("target", "enemy_one")
	match tgt:
		"self":
			return [caster]
		"enemy_all":
			return _alive(foes)
		"ally_all":
			return _alive(allies)
		"enemy_one":
			if explicit_target != null and explicit_target.is_alive():
				return [explicit_target]
			var f: Array = _alive(foes)
			return [f[0]] if f.size() > 0 else []
		"ally_one":
			if explicit_target != null and explicit_target.is_alive():
				return [explicit_target]
			var low: Unit = _lowest_hp_ally(_alive(allies))
			return [low] if low != null else []
	return []


## 对单个目标结算：伤害 / 治疗 / 纯增益，并处理附带的状态效果
static func _apply_one(caster: Unit, target: Unit, skill: Dictionary, dtype: String) -> Dictionary:
	var ev: Dictionary = {"target": target}

	if dtype == "buff" or dtype == "debuff":
		# 纯状态技能：无伤害，直接按概率施加
		ev["damage"] = 0
		ev["is_heal"] = false
		ev["applied"] = _try_apply_status(caster, target, skill)
		return ev

	var result: Dictionary = DamageCalc.compute(caster, target, skill)
	ev["result"] = result
	if not result.get("hit", false):
		ev["damage"] = 0
		ev["is_heal"] = false
		ev["applied"] = false
		return ev

	if result.get("is_heal", false):
		var heal: int = int(result["damage"])
		target.hp = mini(target.hp_max, target.hp + heal)
		ev["damage"] = heal
		ev["is_heal"] = true
		ev["applied"] = _try_apply_status(caster, target, skill)
		return ev

	# 伤害：先扣护盾再扣血
	var dealt: Dictionary = target.take_damage(int(result["damage"]))
	ev["damage"] = int(result["damage"])
	ev["absorbed"] = dealt["absorbed"]
	ev["died"] = dealt["died"]
	ev["is_heal"] = false
	# 目标死亡则不再施加状态
	ev["applied"] = false if dealt["died"] else _try_apply_status(caster, target, skill)
	return ev


static func _try_apply_status(caster: Unit, target: Unit, skill: Dictionary) -> bool:
	var eff: String = skill.get("effect", "none")
	if eff == "" or eff == "none":
		return false
	var turns: int = int(skill.get("effect_turns", 0))
	if turns <= 0:
		return false
	var chance: float = float(skill.get("effect_chance", 0.0))
	if randf() > chance:
		return false
	return target.apply_status(eff, turns)


static func _alive(units: Array) -> Array:
	var out: Array = []
	for u in units:
		if u != null and u.is_alive():
			out.append(u)
	return out


static func _lowest_hp_ally(units: Array) -> Unit:
	var best: Unit = null
	var best_ratio: float = 1e9
	for u in units:
		var ratio: float = float(u.hp) / float(maxi(1, u.hp_max))
		if ratio < best_ratio:
			best_ratio = ratio
			best = u
	return best

class_name EnemyAI
extends RefCounted
## 敌人行动决策（对应 docs/数值设计.md「AI 决策流程」）：
##   1. 从 enemy_ai.csv 取该敌人的技能条目
##   2. 过滤出 condition 满足的候选
##   3. 按 weight 加权随机选一个技能返回
## 无可选项时退回普攻。Boss 多阶段即靠 hp_below_50 / hp_below_30 条件解锁新技能实现。

static func choose_skill(enemy: Unit, allies: Array) -> Dictionary:
	var rows: Array = DataManager.get_enemy_ai(enemy.uid)
	if rows.is_empty():
		return DamageCalc.basic_attack(enemy)

	var hp_ratio: float = float(enemy.hp) / float(maxi(1, enemy.hp_max))
	var candidates: Array = []
	for r in rows:
		if _cond_ok(String(r["condition"]), enemy, hp_ratio, allies):
			candidates.append(r)
	if candidates.is_empty():
		return DamageCalc.basic_attack(enemy)

	var total: float = 0.0
	for c in candidates:
		total += float(c["weight"])
	var roll: float = randf() * total
	var acc: float = 0.0
	for c in candidates:
		acc += float(c["weight"])
		if roll <= acc:
			var sk: Dictionary = DataManager.get_skill(String(c["skill_id"]))
			if not sk.is_empty():
				return sk
	# 兜底：返回最后一个候选
	var last: Dictionary = DataManager.get_skill(String(candidates[candidates.size() - 1]["skill_id"]))
	return last if not last.is_empty() else DamageCalc.basic_attack(enemy)


static func _cond_ok(cond: String, enemy: Unit, hp_ratio: float, allies: Array) -> bool:
	match cond:
		"always":
			return true
		"hp_below_50":
			return hp_ratio < 0.5
		"hp_below_30":
			return hp_ratio < 0.3
		"ally_hp_below_50":
			for a in allies:
				if a != enemy and a != null and a.is_alive():
					if float(a.hp) / float(maxi(1, a.hp_max)) < 0.5:
						return true
			return false
	return true

class_name Progression
extends RefCounted
## 经验与升级（跨战斗持久，独立于单场战斗的 Unit 运行时数据）。
## 升级所需经验读 levels.csv（曲线 floor(50*Lv^1.6)）。

## 给某个角色增加经验，处理连升多级。
## 传入当前 level / exp，返回 {"level","exp","leveled","gained_levels"}
static func add_exp(level: int, exp: int, gain: int) -> Dictionary:
	exp += gain
	var start_level: int = level
	while true:
		var need: int = DataManager.get_exp_to_next(level)
		if need <= 0:
			break   # 已满级（表里没有下一级）
		if exp >= need:
			exp -= need
			level += 1
		else:
			break
	return {
		"level": level,
		"exp": exp,
		"leveled": level > start_level,
		"gained_levels": level - start_level,
	}

class_name StatFormula
extends RefCounted
## 属性派生公式集中处（对应 docs/数值设计.md「核心公式」）。
## 改数值口径只改这里，全局生效 —— 数据驱动的一部分。


## 由一级属性(体质/力量/灵能/敏捷)与等级，派生出战斗用二级属性。
## 返回 Dictionary：hp_max,mp_max(int) / atk,matk,def,spd,crit,eva(float)
static func derive(vit: float, strength: float, intellect: float, agility: float, level: int) -> Dictionary:
	var hp_max: int = int(floor(100.0 + vit * 12.0 + level * 5.0))
	var mp_max: int = int(floor(30.0 + intellect * 6.0 + level * 2.0))
	var atk: float = 8.0 + strength * 2.0
	var matk: float = 8.0 + intellect * 2.0
	var def: float = 5.0 + vit * 1.0 + level * 0.5
	var spd: float = 8.0 + agility * 1.5
	var crit: float = minf(50.0, 5.0 + agility * 0.3)   # 暴击率(%)，上限50
	var eva: float = minf(25.0, 3.0 + agility * 0.2)    # 闪避率(%)，上限25
	return {
		"hp_max": hp_max, "mp_max": mp_max,
		"atk": atk, "matk": matk, "def": def,
		"spd": spd, "crit": crit, "eva": eva,
	}


## 一级属性随等级成长：base + grow * (level - 1)
static func primary_at_level(base: float, grow: float, level: int) -> float:
	return base + grow * float(level - 1)

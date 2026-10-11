class_name TurnQueue
extends RefCounted
## 速度行动条：按 SPD 从高到低排出本轮行动顺序。
## 可加少量随机扰动(jitter)避免同速单位每轮顺序完全固定。


static func build_order(units: Array, jitter: bool = true) -> Array:
	var keyed: Array = []
	for u in units:
		var key: float = float(u.eff_spd()) + (randf_range(0.0, 2.0) if jitter else 0.0)
		keyed.append({"u": u, "k": key})
	# 按 key 降序
	keyed.sort_custom(func(a, b): return a["k"] > b["k"])
	var out: Array = []
	for entry in keyed:
		out.append(entry["u"])
	return out

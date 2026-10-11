class_name StatusEffect
extends RefCounted
## 一个「已激活」的状态效果实例（挂在 Unit.statuses 上）。
## 静态定义（kind/value）来自 data/status_effects.csv，本类只保存运行时剩余回合。

var id: String = ""
var effect_name: String = ""
var kind: String = ""        # skip_chance / spd_pct / dot_pct / atk_pct / def_pct / hot_pct / shield_pct
var value: float = 0.0       # 数值含义由 kind 决定（见 status_effects.csv）
var turns_left: int = 0
var shield_amount: int = 0   # 仅 kind=="shield_pct" 时记录授予的护盾量，用于到期时精确扣除


## 从 DataManager 的状态定义 + 持续回合构建一个激活实例
static func create(status_id: String, turns: int, owner_max_hp: int) -> StatusEffect:
	var def: Dictionary = DataManager.get_status(status_id)
	if def.is_empty():
		return null
	var s := StatusEffect.new()
	s.id = status_id
	s.effect_name = def.get("name", status_id)
	s.kind = def.get("kind", "")
	s.value = float(def.get("value", 0.0))
	s.turns_left = maxi(1, turns)
	if s.kind == "shield_pct":
		s.shield_amount = int(round(owner_max_hp * s.value))
	return s

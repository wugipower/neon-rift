extends Control
## P3 图形化验证：角色属性面板
## 从 DataManager 读 CSV，用 StatFormula/Unit 实时计算，三张角色卡并排显示。
## 拖动等级滑块可看到属性随等级成长 —— 直观验证「数据驱动 + 属性派生」。

const CHAR_IDS := ["lin", "cang", "miao"]

# 元素配色（可视化区分）
const ELEMENT_COLOR := {
	"电": Color(1.0, 0.85, 0.25),
	"冰": Color(0.45, 0.85, 1.0),
	"水": Color(0.35, 0.55, 1.0),
	"火": Color(1.0, 0.45, 0.3),
	"无": Color(0.7, 0.7, 0.75),
}

# 要显示的属性行：键 -> 中文标签
const STAT_ROWS := [
	["hp_max", "生命 HP"],
	["mp_max", "能量 MP"],
	["atk", "物攻 ATK"],
	["matk", "异攻 MATK"],
	["def", "防御 DEF"],
	["spd", "速度 SPD"],
	["crit", "暴击 CRT%"],
	["eva", "闪避 EVA%"],
]

var _level_spin: SpinBox
var _cards := {}   # char_id -> { "title":Label, "meta":Label, "stats":{ key: Label } }


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	_refresh_all(int(_level_spin.value))


func _build_ui() -> void:
	# 背景
	var bg := ColorRect.new()
	bg.color = Color(0.07, 0.08, 0.13)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# 外层留白
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 28)
	add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 18)
	margin.add_child(vbox)

	# 标题
	var title := Label.new()
	title.text = "《霓虹裂隙》角色属性面板 · P3 数据驱动验证"
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(0.85, 0.95, 1.0))
	vbox.add_child(title)

	# 等级控制条
	var level_bar := HBoxContainer.new()
	level_bar.add_theme_constant_override("separation", 12)
	vbox.add_child(level_bar)

	var lv_label := Label.new()
	lv_label.text = "等级 Lv"
	lv_label.add_theme_font_size_override("font_size", 20)
	level_bar.add_child(lv_label)

	_level_spin = SpinBox.new()
	_level_spin.min_value = 1
	_level_spin.max_value = 20
	_level_spin.value = 1
	_level_spin.add_theme_font_size_override("font_size", 20)
	_level_spin.value_changed.connect(_on_level_changed)
	level_bar.add_child(_level_spin)

	var hint := Label.new()
	hint.text = "← 改等级，看属性实时成长（数据来自 data/characters.csv + 派生公式）"
	hint.add_theme_font_size_override("font_size", 15)
	hint.add_theme_color_override("font_color", Color(0.55, 0.6, 0.7))
	level_bar.add_child(hint)

	# 三张角色卡
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(row)
	for cid in CHAR_IDS:
		row.add_child(_make_card(cid))


func _make_card(char_id: String) -> Control:
	var data: Dictionary = DataManager.get_character(char_id)
	var ecol: Color = ELEMENT_COLOR.get(data.get("element", "无"), Color(0.7, 0.7, 0.75))

	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.12, 0.14, 0.21)
	sb.border_color = ecol
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(16)
	panel.add_theme_stylebox_override("panel", sb)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	panel.add_child(vbox)

	# 名字
	var name_label := Label.new()
	name_label.text = data.get("name", "?")
	name_label.add_theme_font_size_override("font_size", 26)
	name_label.add_theme_color_override("font_color", ecol)
	vbox.add_child(name_label)

	# 定位/元素
	var meta_label := Label.new()
	meta_label.text = "%s · %s属性" % [data.get("role", ""), data.get("element", "无")]
	meta_label.add_theme_font_size_override("font_size", 15)
	meta_label.add_theme_color_override("font_color", Color(0.6, 0.65, 0.75))
	vbox.add_child(meta_label)

	# 分隔
	vbox.add_child(HSeparator.new())

	# 属性行
	var stat_labels := {}
	for entry in STAT_ROWS:
		var key: String = entry[0]
		var row := HBoxContainer.new()
		vbox.add_child(row)
		var k := Label.new()
		k.text = entry[1]
		k.add_theme_font_size_override("font_size", 17)
		k.add_theme_color_override("font_color", Color(0.7, 0.75, 0.85))
		k.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(k)
		var v := Label.new()
		v.text = "-"
		v.add_theme_font_size_override("font_size", 17)
		v.add_theme_color_override("font_color", Color(1, 1, 1))
		row.add_child(v)
		stat_labels[key] = v

	_cards[char_id] = {"stats": stat_labels, "meta": meta_label}
	return panel


func _on_level_changed(value: float) -> void:
	_refresh_all(int(value))


func _refresh_all(level: int) -> void:
	for cid in CHAR_IDS:
		var u: Unit = Unit.from_character(DataManager.get_character(cid), level)
		var labels: Dictionary = _cards[cid]["stats"]
		for entry in STAT_ROWS:
			var key: String = entry[0]
			var val = u.get(key)
			var text: String
			if key == "hp_max" or key == "mp_max":
				text = str(int(val))
			else:
				text = "%.1f" % float(val)
			labels[key].text = text

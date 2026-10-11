extends Control
## 据点（事务所）：查看队伍 / 商店买卖 / 装备穿戴 / 存档 / 出发。

var _info: Label
var _party_box: VBoxContainer
var _gold_label: Label
var _shop_panel: Control
var _shop_list: VBoxContainer
var _owned_list: VBoxContainer


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0.07, 0.07, 0.13)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var title := Label.new()
	title.text = "裂隙事务所（据点）"
	title.position = Vector2(30, 16)
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(0.85, 0.95, 1.0))
	add_child(title)

	_gold_label = Label.new()
	_gold_label.position = Vector2(30, 52)
	_gold_label.add_theme_font_size_override("font_size", 18)
	_gold_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5))
	add_child(_gold_label)

	# 队伍面板
	var party_title := Label.new()
	party_title.text = "队伍"
	party_title.position = Vector2(30, 90)
	party_title.add_theme_font_size_override("font_size", 17)
	party_title.add_theme_color_override("font_color", Color(0.7, 0.8, 0.9))
	add_child(party_title)

	_party_box = VBoxContainer.new()
	_party_box.position = Vector2(30, 118)
	_party_box.size = Vector2(600, 300)
	_party_box.add_theme_constant_override("separation", 10)
	add_child(_party_box)

	# 功能按钮
	_btn("商店", Vector2(700, 90), _toggle_shop)
	_btn("存档", Vector2(830, 90), _on_save)
	_btn("出发 →地图", Vector2(960, 90), func(): SceneLoader.goto_map())
	_btn("主菜单", Vector2(1120, 90), func(): SceneLoader.goto_menu())

	_info = Label.new()
	_info.position = Vector2(700, 150)
	_info.size = Vector2(540, 40)
	_info.add_theme_font_size_override("font_size", 16)
	_info.add_theme_color_override("font_color", Color(0.6, 0.9, 0.65))
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_info)

	_build_shop_panel()
	_refresh()


func _btn(text: String, pos: Vector2, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.position = pos
	b.size = Vector2(120, 44)
	b.add_theme_font_size_override("font_size", 15)
	b.pressed.connect(cb)
	add_child(b)
	return b


func _refresh() -> void:
	_gold_label.text = "金钱：%d G" % GameState.gold
	for c in _party_box.get_children():
		c.queue_free()
	for m in GameState.party_summary():
		var eq_names: Array = []
		for eid in m["equipment"]:
			eq_names.append(String(DataManager.get_equipment(String(eid)).get("name", eid)))
		var eq_text: String = "、".join(eq_names) if eq_names.size() > 0 else "无"
		var lbl := Label.new()
		lbl.text = "%s  Lv%d·%s　经验 %d/%d　装备：%s" % [
			m["name"], m["level"], m["element"], m["exp"], m["exp_next"], eq_text]
		lbl.add_theme_font_size_override("font_size", 16)
		lbl.add_theme_color_override("font_color", Color(0.88, 0.9, 1.0))
		_party_box.add_child(lbl)
	_refresh_shop()


# ---------------- 商店 ----------------

func _build_shop_panel() -> void:
	_shop_panel = Panel.new()
	_shop_panel.position = Vector2(700, 200)
	_shop_panel.size = Vector2(540, 470)
	_shop_panel.visible = false
	add_child(_shop_panel)

	var head := Label.new()
	head.text = "商店（点击购买；装备可在下方穿给角色）"
	head.position = Vector2(16, 10)
	head.size = Vector2(510, 24)
	head.add_theme_font_size_override("font_size", 15)
	head.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5))
	_shop_panel.add_child(head)

	var scroll := ScrollContainer.new()
	scroll.position = Vector2(12, 40)
	scroll.size = Vector2(516, 420)
	_shop_panel.add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 6)
	scroll.add_child(vbox)

	_shop_list = VBoxContainer.new()
	_shop_list.add_theme_constant_override("separation", 4)
	vbox.add_child(_shop_list)

	var owned_head := Label.new()
	owned_head.text = "—— 已拥有装备 ——"
	owned_head.add_theme_font_size_override("font_size", 14)
	owned_head.add_theme_color_override("font_color", Color(0.7, 0.8, 0.9))
	vbox.add_child(owned_head)

	_owned_list = VBoxContainer.new()
	_owned_list.add_theme_constant_override("separation", 4)
	vbox.add_child(_owned_list)


func _toggle_shop() -> void:
	_shop_panel.visible = not _shop_panel.visible
	_refresh_shop()


func _refresh_shop() -> void:
	if _shop_list == null:
		return
	for c in _shop_list.get_children():
		c.queue_free()
	for c2 in _owned_list.get_children():
		c2.queue_free()

	for entry in DataManager.get_shop("hub"):
		var kind: String = String(entry["kind"])
		var ref_id: String = String(entry["ref_id"])
		var row: Dictionary = DataManager.get_item(ref_id) if kind == "item" else DataManager.get_equipment(ref_id)
		var pname: String = String(row.get("name", ref_id))
		var price: int = GameState.price_of(kind, ref_id)
		var hbox := HBoxContainer.new()
		var lbl := Label.new()
		lbl.text = "%s　%d G" % [pname, price]
		lbl.size = Vector2(360, 30)
		lbl.add_theme_font_size_override("font_size", 15)
		hbox.add_child(lbl)
		var buy := Button.new()
		buy.text = "购买"
		buy.add_theme_font_size_override("font_size", 14)
		buy.disabled = GameState.gold < price
		buy.pressed.connect(_buy.bind(kind, ref_id))
		hbox.add_child(buy)
		_shop_list.add_child(hbox)

	# 已拥有装备 → 穿给谁
	for eid in GameState.owned_equips:
		var erow: Dictionary = DataManager.get_equipment(String(eid))
		var hbox2 := HBoxContainer.new()
		var lbl2 := Label.new()
		var wearer: String = _wearer_of(String(eid))
		lbl2.text = "%s(%s)%s" % [erow.get("name", eid), erow.get("slot", ""), ("　→ " + wearer) if wearer != "" else ""]
		lbl2.size = Vector2(230, 30)
		lbl2.add_theme_font_size_override("font_size", 14)
		hbox2.add_child(lbl2)
		for m in GameState.party_summary():
			var eb := Button.new()
			eb.text = String(m["name"])
			eb.add_theme_font_size_override("font_size", 13)
			eb.pressed.connect(_equip.bind(String(m["id"]), String(eid)))
			hbox2.add_child(eb)
		_owned_list.add_child(hbox2)


func _wearer_of(equip_id: String) -> String:
	for m in GameState.party:
		if m.get("equipment", []).has(equip_id):
			return String(DataManager.get_character(String(m["id"])).get("name", m["id"]))
	return ""


func _buy(kind: String, ref_id: String) -> void:
	if GameState.buy(kind, ref_id):
		var row: Dictionary = DataManager.get_item(ref_id) if kind == "item" else DataManager.get_equipment(ref_id)
		_info.text = "购买成功：%s" % row.get("name", ref_id)
	else:
		_info.text = "金钱不足！"
	_refresh()


func _equip(char_id: String, equip_id: String) -> void:
	if GameState.equip_to(char_id, equip_id):
		var cname: String = String(DataManager.get_character(char_id).get("name", char_id))
		_info.text = "已装备给 %s" % cname
	_refresh()


func _on_save() -> void:
	if GameState.save_game():
		_info.text = "已存档（战斗胜利也会自动存档）"
	else:
		_info.text = "存档失败"

class_name NeonTheme
extends RefCounted
## P7 统一霓虹暗色 UI 主题：所有场景的按钮/面板/标签经这里上色，保证观感一致。
## 设计语言：深蓝黑底 + 青色描边（主操作品红描边）+ 圆角 + 悬停发光。

const COL_BG := Color(0.05, 0.06, 0.10)
const COL_PANEL := Color(0.09, 0.11, 0.18)
const COL_PANEL_HI := Color(0.13, 0.16, 0.26)
const COL_ACCENT := Color(0.35, 0.95, 1.0)      # 青：信息/描边
const COL_ACCENT2 := Color(1.0, 0.45, 0.75)     # 品红：主操作
const COL_TEXT := Color(0.88, 0.93, 1.0)
const COL_DIM := Color(0.62, 0.68, 0.80)
const COL_GOLD := Color(1.0, 0.85, 0.45)
const COL_GOOD := Color(0.45, 0.95, 0.55)
const COL_BAD := Color(1.0, 0.4, 0.35)


static func _box(bg: Color, border: Color, width: int = 2) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(width)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	return sb


## 按钮：默认青描边；primary（主操作）品红描边 + 更亮底色
static func style_button(b: Button, primary: bool = false) -> void:
	var edge: Color = COL_ACCENT2 if primary else COL_ACCENT
	b.add_theme_stylebox_override("normal", _box(COL_PANEL, edge))
	b.add_theme_stylebox_override("hover", _box(COL_PANEL_HI, edge.lightened(0.25)))
	b.add_theme_stylebox_override("pressed", _box(COL_PANEL_HI.darkened(0.2), edge))
	b.add_theme_stylebox_override("disabled", _box(COL_PANEL.darkened(0.4), Color(0.3, 0.33, 0.42), 1))
	b.add_theme_color_override("font_color", COL_TEXT)
	b.add_theme_color_override("font_hover_color", Color(1, 1, 1))
	b.add_theme_color_override("font_disabled_color", COL_DIM.darkened(0.3))
	if b.get_theme_font_size("font_size") < 15:
		b.add_theme_font_size_override("font_size", 15)


static func style_panel(p: Panel) -> void:
	var sb := _box(COL_PANEL, COL_ACCENT, 1)
	sb.set_corner_radius_all(10)
	p.add_theme_stylebox_override("panel", sb)


static func style_label(l: Label, size: int = 16, color: Color = COL_TEXT) -> void:
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)


## 整树套用：按钮/面板统一风格，深色底 ColorRect 统一为 COL_BG（标签颜色各场景自定，不覆盖）
static func apply_tree(root: Node) -> void:
	for c in root.get_children():
		if c is Button:
			style_button(c)
		elif c is Panel:
			style_panel(c)
		elif c is ColorRect and c.color.a > 0.9 and c.color.get_luminance() < 0.15:
			c.color = COL_BG
		apply_tree(c)


static func load_tex(path: String) -> Texture2D:
	if not ResourceLoader.exists(path):
		return null
	return load(path)


## P7：全屏背景图（压暗、不拦鼠标），插到 at_index 层（底色之上、UI 之下）
static func add_bg_image(root: Control, path: String, alpha: float = 0.35, at_index: int = 1) -> void:
	var tex: Texture2D = load_tex(path)
	if tex == null:
		return
	var tr := TextureRect.new()
	tr.texture = tex
	tr.set_anchors_preset(Control.PRESET_FULL_RECT)
	tr.set_offsets_preset(Control.PRESET_FULL_RECT)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	tr.modulate = Color(1, 1, 1, alpha)
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(tr)
	root.move_child(tr, at_index)

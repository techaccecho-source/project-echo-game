extends CanvasLayer
class_name JournalUI
## The reader for recovered blog fragments ("[J]").
##
## Built entirely in code and parented to the EchoLog autoload rather than to a
## level or shell, because the game runs two different roots — the standalone
## Level 1 world and the persistent shell (game.tscn) — and the journal has to
## exist in both. Same reason SceneManager builds its own fade overlay.

const BG_DIM := Color(0.02, 0.02, 0.03, 0.78)
const PANEL_BG := Color("14110e")
const PANEL_EDGE := Color("3a3129")
const LIST_BG := Color("0e0c0a")
const INK := Color("e6dac4")
const INK_DIM := Color("8b7f6b")
const INK_LOCKED := Color("4b443b")
const ACCENT := Color("c9883c")

var is_open: bool = false

var _rows: Array[Fragment] = []
var _list: ItemList
var _count: Label
var _entry_label: Label
var _title: Label
var _meta: Label
var _text: RichTextLabel
var _footer: Label
var _empty: Label
var _reader: Control


func _ready() -> void:
	layer = 60
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	visible = false
	EchoLog.changed.connect(refresh)


# --- construction -----------------------------------------------------------

func _flat(bg: Color, edge: Color, edge_px: int = 2, radius: int = 2) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = edge
	sb.set_border_width_all(edge_px)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	return sb


func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


func _rule(color: Color, h: int = 2) -> ColorRect:
	var r := ColorRect.new()
	r.color = color
	r.custom_minimum_size = Vector2(0, h)
	return r


func _build() -> void:
	var dim := ColorRect.new()
	dim.color = BG_DIM
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _flat(PANEL_BG, PANEL_EDGE, 2, 3))
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(1180, 780)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	dim.add_child(panel)

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 26)
	panel.add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 14)
	margin.add_child(root)

	# header
	var header := HBoxContainer.new()
	root.add_child(header)
	var h_title := _label("THE ECHO LOG", 34, INK)
	h_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(h_title)
	_count = _label("", 20, ACCENT)
	_count.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	header.add_child(_count)
	root.add_child(_rule(PANEL_EDGE))

	# body: index on the left, page on the right
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 24)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(body)

	var list_pane := PanelContainer.new()
	list_pane.add_theme_stylebox_override("panel", _flat(LIST_BG, PANEL_EDGE, 1, 2))
	list_pane.custom_minimum_size = Vector2(340, 0)
	body.add_child(list_pane)

	_list = ItemList.new()
	_list.add_theme_font_size_override("font_size", 20)
	_list.add_theme_color_override("font_color", INK_DIM)
	_list.add_theme_color_override("font_selected_color", INK)
	_list.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	_list.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	_list.add_theme_stylebox_override("selected", _flat(Color("2a2118"), ACCENT, 0, 2))
	_list.add_theme_stylebox_override("selected_focus", _flat(Color("2a2118"), ACCENT, 0, 2))
	_list.auto_height = false
	_list.item_selected.connect(_on_selected)
	list_pane.add_child(_list)

	_reader = VBoxContainer.new()
	_reader.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	(_reader as VBoxContainer).add_theme_constant_override("separation", 6)
	body.add_child(_reader)

	_entry_label = _label("", 18, ACCENT)
	_reader.add_child(_entry_label)
	_title = _label("", 30, INK)
	_reader.add_child(_title)
	_meta = _label("", 17, INK_DIM)
	_reader.add_child(_meta)
	_reader.add_child(_rule(PANEL_EDGE, 1))

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_reader.add_child(scroll)

	var page := VBoxContainer.new()
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.add_theme_constant_override("separation", 16)
	scroll.add_child(page)

	_text = RichTextLabel.new()
	_text.bbcode_enabled = true
	_text.fit_content = true
	_text.scroll_active = false
	_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_text.add_theme_font_size_override("normal_font_size", 21)
	_text.add_theme_font_size_override("italics_font_size", 21)
	_text.add_theme_color_override("default_color", INK)
	page.add_child(_text)

	_footer = _label("", 17, INK_LOCKED)
	_footer.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_footer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.add_child(_footer)

	# shown instead of the reader when nothing has been recovered yet
	_empty = _label("Nothing recovered yet.\nCedric left pages behind. Look for them.",
			22, INK_LOCKED)
	_empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_empty.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_empty.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_empty.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(_empty)

	root.add_child(_rule(PANEL_EDGE, 1))
	root.add_child(_label("[J] or [Esc] to close        ↑ ↓ to turn pages", 17, INK_LOCKED))


# --- contents ---------------------------------------------------------------

func refresh() -> void:
	var keep := _list.get_selected_items()
	var keep_idx := keep[0] if keep.size() > 0 else -1

	_rows = EchoLog.fragments
	_list.clear()
	var found := 0
	for i in _rows.size():
		var f := _rows[i]
		if EchoLog.has_fragment(f.id):
			found += 1
			_list.add_item("%d.  %s" % [i + 1, f.title])
		else:
			_list.add_item("%d.  ▓▓▓▓▓▓▓▓" % (i + 1))
			_list.set_item_disabled(i, true)
			_list.set_item_custom_fg_color(i, INK_LOCKED)

	_count.text = "%d / %d RECOVERED" % [found, _rows.size()]
	var has_any := found > 0
	_list.visible = has_any
	_list.get_parent().visible = has_any
	_reader.visible = has_any
	_empty.visible = not has_any
	if not has_any:
		return

	if keep_idx >= 0 and keep_idx < _rows.size() and EchoLog.has_fragment(_rows[keep_idx].id):
		_select(keep_idx)
	else:
		_select(_first_found())


func _first_found() -> int:
	for i in _rows.size():
		if EchoLog.has_fragment(_rows[i].id):
			return i
	return -1


func _select(index: int) -> void:
	if index < 0 or index >= _rows.size():
		return
	_list.select(index)
	_show(_rows[index])


func _on_selected(index: int) -> void:
	_show(_rows[index])


func _show(f: Fragment) -> void:
	_entry_label.text = f.entry_label
	_entry_label.visible = f.entry_label != ""
	_title.text = f.title
	var meta := "Case %02d" % f.level if f.level > 0 else ""
	if f.found_at != "":
		meta += ("  ·  " if meta != "" else "") + "recovered from " + f.found_at
	_meta.text = meta
	_text.text = f.body
	_footer.text = f.footer
	_footer.visible = f.footer != ""


# --- open / close -----------------------------------------------------------

func open(focus_id: String = "") -> void:
	refresh()
	if focus_id != "":
		for i in _rows.size():
			if _rows[i].id == focus_id:
				_select(i)
				break
	visible = true
	is_open = true
	_list.grab_focus()
	_set_world_input(false)


func close() -> void:
	visible = false
	is_open = false
	_set_world_input(true)


func toggle() -> void:
	if is_open:
		close()
	else:
		open()


## Stop the world reacting while the journal is up: the player would otherwise
## keep walking, and InteractionManager would fire on [E] behind the panel.
func _set_world_input(enabled: bool) -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player:
		if enabled and player.has_method("enable_movement"):
			player.enable_movement()
		elif not enabled and player.has_method("disable_movement"):
			player.disable_movement()
	if InteractionManager:
		InteractionManager.can_interact = enabled


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("journal"):
		toggle()
		get_viewport().set_input_as_handled()
	elif is_open and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()

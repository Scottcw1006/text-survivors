class_name MetaMenu
extends Control
## 局外升級畫面（選角畫面進來）：一圈「框」字的面板，一行一個項目，用 token 升級。
## 鍵盤：W S 選、Space / Enter 升級、Backspace 全部重置、Esc 或 U 返回。
## 手機：點一行選它、再點一次升級；點「重置」退回全部 token（要點兩次確認）；點「返回」離開。

const CELL := 20.0
const COLS := 46
const ROW_H := 50.0
const COLOR_ON := Color.WHITE
const COLOR_DIM := Color(1, 1, 1, 0.45)
const COLOR_PICK := Color(1.0, 0.85, 0.4)
const COLOR_MAX := Color(0.5, 0.9, 0.5)

var font: Font
var cursor := 0
var who := "人"                 # 現在選的角色（穿只有人有、廣只有刀有）
var touch_mode := false
var flash := ""                 # 剛剛的提示（買到了 / token 不夠）
var _row_rects: Array[Rect2] = []
var _back_rect := Rect2()
var _reset_rect := Rect2()
var reset_armed := false        # 重置要按兩次：第一次只是提醒


func items() -> Array:
	return Meta.ITEMS.filter(func(it: Dictionary) -> bool: return not it.has("who") or it.who == who)


func open(character_glyph: String, is_touch: bool) -> void:
	who = character_glyph
	touch_mode = is_touch
	cursor = 0
	flash = ""
	visible = true
	queue_redraw()


func row_at(pos: Vector2) -> int:
	for i in _row_rects.size():
		if _row_rects[i].has_point(pos):
			return i
	return -1


func back_at(pos: Vector2) -> bool:
	return _back_rect.has_point(pos)


func reset_at(pos: Vector2) -> bool:
	return _reset_rect.has_point(pos)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.9))
	var list := items()
	var w := COLS * CELL
	var h := 150.0 + list.size() * ROW_H + 110.0
	var k := minf(1.3 if size.x >= 2000.0 else 1.0, size.y / (h + 110.0))   # 下面還有一行提示
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(k, k))
	var view := size / k
	var rows := int(ceil(h / CELL))
	var o := (view - Vector2(w, rows * CELL + 50.0)) / 2.0
	draw_rect(Rect2(o, Vector2(w, rows * CELL)), Color.BLACK)
	for cx in COLS:
		for cy in rows:
			if cx == 0 or cy == 0 or cx == COLS - 1 or cy == rows - 1:
				_text("框", o + Vector2((cx + 0.5) * CELL, (cy + 0.5) * CELL), 17, COLOR_DIM, true)
	var mid := o.x + w / 2.0
	_text("局外升級", Vector2(mid, o.y + 52.0), 44, COLOR_ON, true)
	_text("token　%d" % Meta.tokens, Vector2(mid, o.y + 100.0), 33, COLOR_PICK, true)

	_row_rects.clear()
	var y := o.y + 160.0
	for i in list.size():
		var it: Dictionary = list[i]
		var on := i == cursor
		var c := COLOR_PICK if on else COLOR_ON
		var lv := Meta.level(it.id)
		var cost := Meta.next_cost(it)
		var r := Rect2(Vector2(o.x + CELL * 1.5, y - ROW_H / 2.0 + 2.0), Vector2(w - CELL * 3.0, ROW_H - 4.0))
		if on:
			draw_rect(r, Color(1, 1, 1, 0.08))
		_row_rects.append(_scaled(r, k))
		_text(it.icon, Vector2(o.x + 70.0, y), 33, c, true)
		_text(it.name, Vector2(o.x + 110.0, y), 33, c, false)
		var bar := "■".repeat(lv) + "□".repeat(it.max - lv)
		_text(bar, Vector2(o.x + w * 0.62, y), 33, COLOR_MAX if cost < 0 else c, true)
		var price := "滿級" if cost < 0 else ("%d token" % cost)
		var pc := COLOR_MAX if cost < 0 else (c if Meta.tokens >= cost else Color(1, 0.4, 0.4, 0.8))
		_text(price, Vector2(o.x + w - 120.0, y), 33, pc, true)
		y += ROW_H

	# 重置、返回按鈕
	var bw := 200.0
	var rr := Rect2(Vector2(mid - bw - 20.0, y + 10.0), Vector2(bw, 56.0))
	var rc := Color(1, 0.45, 0.4) if reset_armed else COLOR_DIM
	draw_rect(rr, rc, false, 2.0)
	_text("確定重置？" if reset_armed else "全部重置", rr.get_center(), 33, Color(1, 0.6, 0.55) if reset_armed else COLOR_ON, true)
	_reset_rect = _scaled(rr, k)
	var br := Rect2(Vector2(mid + 20.0, y + 10.0), Vector2(bw, 56.0))
	draw_rect(br, COLOR_DIM, false, 2.0)
	_text("返回", br.get_center(), 33, COLOR_ON, true)
	_back_rect = _scaled(br, k)

	var hint := "點一下選擇，再點一次升級" if touch_mode else "W S 選擇　Space / Enter 升級　Backspace 全部重置　Esc 返回"
	if flash != "":
		hint = flash
	_text(hint, Vector2(mid, o.y + rows * CELL + 34.0), 22, COLOR_PICK if flash != "" else COLOR_DIM, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _scaled(r: Rect2, k: float) -> Rect2:
	return Rect2(r.position * k, r.size * k)


func _text(text: String, pos: Vector2, font_size: int, color: Color, centered: bool) -> void:
	var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var y := pos.y + font.get_ascent(font_size) - font.get_height(font_size) / 2.0
	var x := pos.x - tw / 2.0 if centered else pos.x
	draw_string(font, Vector2(x, y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

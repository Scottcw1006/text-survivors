class_name UpgradeCards
extends Control
## 卡片畫面（選角、升級、寶箱、結算共用）：幾張用「框」字圍起來的卡片。
## 選中的卡片框是亮的、往上浮一點；沒選中的變暗。cursor = -1 時全部都亮（結算用，不能選）。
## 畫面放不下時（手機模式畫面比較小）整個畫面會等比例縮小到放得下。

const CELL := 20.0                 # 框字的間距
const BORDER_CHAR := "框"
const BORDER_SIZE := 17
const COLS := 15                   # 卡片寬幾個框字
const ROWS := 23                   # 卡片高幾個框字
const PAD := 20.0                  # 內容往下移多少（卡片比原本大一圈，內容跟著置中）
const GAP := 40.0                  # 卡片之間的距離
const LIFT := 12.0                 # 選中的卡片往上浮多少
const DESC_SIZE := 22
const DESC_LINE := 26.0            # 說明文字的行高（估算能放幾行用）
const COLOR_ON := Color.WHITE
const COLOR_OFF := Color(1, 1, 1, 0.35)
const COLOR_DIM := Color(0, 0, 0, 0.8)
# 教學卡（選角畫面下面那排操作說明）：比較小、比較淡，不能選
const TIP_COLS := 14
const TIP_ROWS := 11
const TIP_GAP := 60.0              # 角色卡和教學卡之間的距離
const COLOR_TIP := Color(1, 1, 1, 0.7)

var font: Font
var title := ""
var subtitle := ""                 # 標題下面的一行小字（結算用）
var hint := ""
var cards: Array = []              # [{icon, name, sub, desc}]，sub 可以是空字串
var cursor := 0
var tips: Array = []               # [{name, key, desc}]，選角時才有
var card_rects: Array[Rect2] = []  # 每張卡片畫在哪（手機點卡片用）
var subtitle_rect := Rect2()       # 標題下那行小字的範圍（選角時點它切換操作模式）
var button := ""                   # 卡片下面的按鈕文字（結算的「再來一局」），空字串 = 沒有按鈕
var button_rect := Rect2()


func show_cards(t: String, c: Array, selected: int, h: String, sub_title := "", tip_cards := [], button_text := "") -> void:
	title = t
	button = button_text
	tips = tip_cards
	subtitle = sub_title
	cards = c
	cursor = selected
	hint = h
	visible = true
	queue_redraw()


## 卡片排成幾欄（卡片太多就換行，每行放得下幾張就放幾張），以及卡片＋教學卡的總高度
func _layout(width: float) -> Vector3:
	var card_w := COLS * CELL
	var card_h := ROWS * CELL
	var per_row := maxi(1, int((width - 80.0 + GAP) / (card_w + GAP)))
	var rows := ceili(float(cards.size()) / per_row)
	var cards_h := rows * card_h + (rows - 1) * GAP
	var total_h := cards_h
	if not tips.is_empty():
		total_h += TIP_GAP + TIP_ROWS * CELL
	return Vector3(per_row, cards_h, total_h)


## 上面標題、下面提示／按鈕要佔多少高度
func _extra_h() -> float:
	var top := 130.0 if subtitle != "" else 90.0
	var bottom := 80.0
	if button != "":
		bottom = 170.0 if hint != "" else 130.0
	return top + bottom


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), COLOR_DIM)
	# 放不下就整個縮小（手機模式畫面只有一半大）
	var k := 1.0
	while k > 0.3:
		var lay := _layout(size.x / k)
		var tips_w := tips.size() * TIP_COLS * CELL + (tips.size() - 1) * GAP
		if lay.z + _extra_h() <= size.y / k and tips_w + 40.0 <= size.x / k:
			break
		k -= 0.05
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(k, k))
	var view := size / k   # 縮小後，用這個大小排版
	var card_w := COLS * CELL
	var card_h := ROWS * CELL
	var n := cards.size()
	var lay := _layout(view.x)
	var per_row := int(lay.x)
	var cards_h := lay.y
	var total_h := lay.z
	var tip_w := TIP_COLS * CELL
	var tip_h := TIP_ROWS * CELL
	var top := 130.0 if subtitle != "" else 90.0
	var y0 := (view.y - total_h - _extra_h()) / 2.0 + top

	if subtitle != "":
		_text(title, Vector2(view.x / 2.0, y0 - 100.0), 44, COLOR_ON)
		_text(subtitle, Vector2(view.x / 2.0, y0 - 48.0), 33, COLOR_ON)
		var sw := font.get_string_size(subtitle, HORIZONTAL_ALIGNMENT_LEFT, -1, 33).x
		subtitle_rect = _scaled(Rect2(view.x / 2.0 - sw / 2.0 - 20.0, y0 - 48.0 - 30.0, sw + 40.0, 60.0), k)
	else:
		subtitle_rect = Rect2()
		_text(title, Vector2(view.x / 2.0, y0 - 56.0), 44, COLOR_ON)

	card_rects.clear()
	for i in n:
		var on := cursor < 0 or i == cursor
		var color := COLOR_ON if on else COLOR_OFF
		var lifted := cursor >= 0 and i == cursor
		var row := i / per_row
		var in_row := mini(per_row, n - row * per_row)
		var x0 := (view.x - (in_row * card_w + (in_row - 1) * GAP)) / 2.0
		var origin := Vector2(x0 + (i % per_row) * (card_w + GAP), y0 + row * (card_h + GAP) - (LIFT if lifted else 0.0))
		var mid := origin.x + card_w / 2.0

		card_rects.append(_scaled(Rect2(origin, Vector2(card_w, card_h)), k))
		# 卡片底色塗黑，後面的牆才不會透出來
		draw_rect(Rect2(origin, Vector2(card_w, card_h)), Color.BLACK)

		var c: Dictionary = cards[i]
		_frame(origin, COLS, ROWS, color)

		_text(c.icon, Vector2(mid, origin.y + PAD + 92.0), 66, color)
		_text(c.name, Vector2(mid, origin.y + PAD + 172.0), 33, color)
		var desc_top := PAD + 206.0
		if c.sub != "":
			_text(c.sub, Vector2(mid, origin.y + PAD + 212.0), 22, color)
			desc_top = PAD + 246.0
		# 說明文字在框內自動換行，行數依剩下的高度決定
		var inner_w := (COLS - 4) * CELL - 8.0
		var max_lines := int((card_h - CELL * 2.0 - 8.0 - desc_top) / DESC_LINE)
		var desc_pos := Vector2(origin.x + CELL * 2.0 + 4.0, origin.y + desc_top + font.get_ascent(DESC_SIZE))
		draw_multiline_string(font, desc_pos, c.desc, HORIZONTAL_ALIGNMENT_CENTER, inner_w, DESC_SIZE, max_lines, color)

	# 教學卡：一排在角色卡下面
	var tx0 := (view.x - (tips.size() * tip_w + (tips.size() - 1) * GAP)) / 2.0
	for i in tips.size():
		var tip: Dictionary = tips[i]
		var o := Vector2(tx0 + i * (tip_w + GAP), y0 + cards_h + TIP_GAP)
		var tmid := o.x + tip_w / 2.0
		draw_rect(Rect2(o, Vector2(tip_w, tip_h)), Color.BLACK)
		_frame(o, TIP_COLS, TIP_ROWS, COLOR_TIP)
		_text(tip.name, Vector2(tmid, o.y + 48.0), 33, COLOR_ON)
		_text(tip.key, Vector2(tmid, o.y + 88.0), 22, Color(1.0, 0.85, 0.4))
		var lines := int((tip_h - CELL - 8.0 - 112.0) / DESC_LINE)
		var p := Vector2(o.x + CELL + 4.0, o.y + 112.0 + font.get_ascent(DESC_SIZE))
		draw_multiline_string(font, p, tip.desc, HORIZONTAL_ALIGNMENT_CENTER, (TIP_COLS - 2) * CELL - 8.0, DESC_SIZE, lines, COLOR_TIP)

	if button == "":
		button_rect = Rect2()
		_text(hint, Vector2(view.x / 2.0, y0 + total_h + 50.0), 33, COLOR_ON)
	else:
		# 按鈕：一圈框字圍起來的大字，點它才會動作（避免手指誤觸直接跳過）
		var bw := font.get_string_size(button, HORIZONTAL_ALIGNMENT_LEFT, -1, 44).x
		var bcols := ceili(bw / CELL) + 4
		var brows := 5
		var bo := Vector2(view.x / 2.0 - bcols * CELL / 2.0, y0 + total_h + 30.0)
		draw_rect(Rect2(bo, Vector2(bcols, brows) * CELL), Color.BLACK)
		_frame(bo, bcols, brows, COLOR_ON)
		_text(button, bo + Vector2(bcols, brows) * CELL / 2.0, 44, COLOR_ON)
		button_rect = _scaled(Rect2(bo, Vector2(bcols, brows) * CELL), k)
		if hint != "":
			_text(hint, Vector2(view.x / 2.0, bo.y + brows * CELL + 30.0), 22, COLOR_TIP)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _scaled(r: Rect2, k: float) -> Rect2:
	return Rect2(r.position * k, r.size * k)


## 點到第幾張卡片，沒點到回傳 -1
func card_at(pos: Vector2) -> int:
	for i in card_rects.size():
		if card_rects[i].grow(LIFT).has_point(pos):
			return i
	return -1


## 用一圈「框」字畫出 cols × rows 的外框
func _frame(origin: Vector2, cols: int, rows: int, color: Color) -> void:
	for cx in cols:
		for cy in rows:
			if cx == 0 or cy == 0 or cx == cols - 1 or cy == rows - 1:
				_text(BORDER_CHAR, origin + Vector2((cx + 0.5) * CELL, (cy + 0.5) * CELL), BORDER_SIZE, color)


## 以 center 為中心畫一行字
func _text(text: String, center: Vector2, font_size: int, color: Color) -> void:
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var y := center.y + font.get_ascent(font_size) - font.get_height(font_size) / 2.0
	draw_string(font, Vector2(center.x - w / 2.0, y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

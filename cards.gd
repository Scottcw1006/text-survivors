class_name UpgradeCards
extends Control
## 卡片畫面（選角、升級、寶箱、結算共用）：幾張用「框」字圍起來的卡片。
## 選中的卡片框是亮的、往上浮一點；沒選中的變暗。cursor = -1 時全部都亮（結算用，不能選）。

const CELL := 20.0                 # 框字的間距
const BORDER_CHAR := "框"
const BORDER_SIZE := 17
const COLS := 13                   # 卡片寬幾個框字
const ROWS := 21                   # 卡片高幾個框字
const GAP := 40.0                  # 卡片之間的距離
const LIFT := 12.0                 # 選中的卡片往上浮多少
const DESC_SIZE := 22
const DESC_LINE := 26.0            # 說明文字的行高（估算能放幾行用）
const COLOR_ON := Color.WHITE
const COLOR_OFF := Color(1, 1, 1, 0.35)
const COLOR_DIM := Color(0, 0, 0, 0.8)

var font: Font
var title := ""
var subtitle := ""                 # 標題下面的一行小字（結算用）
var hint := ""
var cards: Array = []              # [{icon, name, sub, desc}]，sub 可以是空字串
var cursor := 0


func show_cards(t: String, c: Array, selected: int, h: String, sub_title := "") -> void:
	title = t
	subtitle = sub_title
	cards = c
	cursor = selected
	hint = h
	visible = true
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), COLOR_DIM)
	var card_w := COLS * CELL
	var card_h := ROWS * CELL
	var n := cards.size()
	# 卡片太多（結算）就換行，每行最多放得下幾張就放幾張
	var per_row := maxi(1, int((size.x - 80.0 + GAP) / (card_w + GAP)))
	var rows := ceili(float(n) / per_row)
	var total_h := rows * card_h + (rows - 1) * GAP
	var y0 := (size.y - total_h) / 2.0 + 20.0

	if subtitle != "":
		_text(title, Vector2(size.x / 2.0, y0 - 100.0), 44, COLOR_ON)
		_text(subtitle, Vector2(size.x / 2.0, y0 - 48.0), 33, COLOR_ON)
	else:
		_text(title, Vector2(size.x / 2.0, y0 - 56.0), 44, COLOR_ON)

	for i in n:
		var on := cursor < 0 or i == cursor
		var color := COLOR_ON if on else COLOR_OFF
		var lifted := cursor >= 0 and i == cursor
		var row := i / per_row
		var in_row := mini(per_row, n - row * per_row)
		var x0 := (size.x - (in_row * card_w + (in_row - 1) * GAP)) / 2.0
		var origin := Vector2(x0 + (i % per_row) * (card_w + GAP), y0 + row * (card_h + GAP) - (LIFT if lifted else 0.0))
		var mid := origin.x + card_w / 2.0

		# 卡片底色塗黑，後面的牆才不會透出來
		draw_rect(Rect2(origin, Vector2(card_w, card_h)), Color.BLACK)

		# 外框：一圈「框」字
		for cx in COLS:
			for cy in ROWS:
				if cx == 0 or cy == 0 or cx == COLS - 1 or cy == ROWS - 1:
					_text(BORDER_CHAR, origin + Vector2((cx + 0.5) * CELL, (cy + 0.5) * CELL), BORDER_SIZE, color)

		var c: Dictionary = cards[i]
		_text(c.icon, Vector2(mid, origin.y + 92.0), 66, color)
		_text(c.name, Vector2(mid, origin.y + 172.0), 33, color)
		var desc_top := 206.0
		if c.sub != "":
			_text(c.sub, Vector2(mid, origin.y + 212.0), 22, color)
			desc_top = 246.0
		# 說明文字在框內自動換行，行數依剩下的高度決定
		var inner_w := (COLS - 2) * CELL - 8.0
		var max_lines := int((card_h - CELL - 8.0 - desc_top) / DESC_LINE)
		var desc_pos := Vector2(origin.x + CELL + 4.0, origin.y + desc_top + font.get_ascent(DESC_SIZE))
		draw_multiline_string(font, desc_pos, c.desc, HORIZONTAL_ALIGNMENT_CENTER, inner_w, DESC_SIZE, max_lines, color)

	_text(hint, Vector2(size.x / 2.0, y0 + total_h + 50.0), 33, COLOR_ON)


## 以 center 為中心畫一行字
func _text(text: String, center: Vector2, font_size: int, color: Color) -> void:
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var y := center.y + font.get_ascent(font_size) - font.get_height(font_size) / 2.0
	draw_string(font, Vector2(center.x - w / 2.0, y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

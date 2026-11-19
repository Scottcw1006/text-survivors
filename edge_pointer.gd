class_name EdgePointer
extends Node2D
## 畫面邊緣的方向提示（寶箱、王、補血愛心在畫面外時）：
## 靠邊一個大三角形指向目標，往畫面內一點是粗體的字（或愛心）。
## position 放在三角形的中心，dir 是往目標的方向。

const TRI_LEN := 64.0           # 三角形從底邊到尖端多長
const TRI_HALF := 42.0          # 三角形底邊的一半寬
const GAP := 18.0               # 三角形和字之間的距離
const FONT_SIZE := 66

var text := ""
var color := Color.WHITE
var dir := Vector2.RIGHT
var heart := false              # 畫愛心而不是字


func _process(_delta: float) -> void:
	# 慢慢一明一暗，比較顯眼
	modulate.a = 0.75 + 0.25 * sin(Time.get_ticks_msec() / 1000.0 * TAU * 0.8)


func _draw() -> void:
	var d := dir.normalized()
	var side := d.orthogonal()
	# 大三角形：尖端朝目標
	var tip := d * TRI_LEN * 0.6
	var base := -d * TRI_LEN * 0.4
	var pts := PackedVector2Array([tip, base + side * TRI_HALF, base - side * TRI_HALF])
	draw_colored_polygon(pts, Color(0, 0, 0, 0.6))   # 先畫一圈黑底，在亮的背景上也看得到
	var inner := PackedVector2Array([tip - d * 4.0, base + side * (TRI_HALF - 5.0) + d * 3.0, base - side * (TRI_HALF - 5.0) + d * 3.0])
	draw_colored_polygon(inner, color)

	# 字（或愛心）放在三角形往畫面裡面一點的地方
	var font := Glyph.font
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x if not heart else 40.0
	var reach := TRI_LEN * 0.4 + GAP + maxf(w, 60.0) / 2.0 * (absf(d.x) + absf(d.y) * 0.6)
	var c := -d * reach
	if heart:
		_draw_heart(c)
		return
	var ascent := font.get_ascent(FONT_SIZE)
	var h := font.get_height(FONT_SIZE)
	var p := Vector2(c.x - w / 2.0, c.y + ascent - h / 2.0)
	# 粗體：黑色外框 + 同一個字往右偏 2 像素再畫一次
	draw_string_outline(font, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, 12, Color(0, 0, 0, 0.85))
	draw_string_outline(font, p + Vector2(2, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, 12, Color(0, 0, 0, 0.85))
	draw_string(font, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, color)
	draw_string(font, p + Vector2(2, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, color)


## 愛心（跟補血道具同一個形狀，放大一點）
func _draw_heart(center: Vector2) -> void:
	var px := 6.0
	var shape: Array = HeartPickup.SHAPE
	var w: int = shape[0].length()
	var hh := shape.size()
	var o := center - Vector2(w, hh) * px / 2.0
	for y in hh:
		for x in w:
			if shape[y][x] == "X":
				draw_rect(Rect2(o + Vector2(x, y) * px - Vector2(2, 2), Vector2(px + 4, px + 4)), Color(0, 0, 0, 0.7))
	for y in hh:
		for x in w:
			if shape[y][x] == "X":
				draw_rect(Rect2(o + Vector2(x, y) * px, Vector2(px, px)), color)

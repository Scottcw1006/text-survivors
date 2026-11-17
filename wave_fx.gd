class_name WaveFx
extends Node2D
## 刀的斬擊波：一個「斬」字，跟著飛行方向轉。大斬擊波是兩倍大的字。

const CHAR := "斬"
const FONT_SIZE := 33
const BIG_SIZE := 66           # 大斬擊波：一般的兩倍（11 的倍數，像素字才銳利）
const COLOR := Color(0.85, 0.95, 1.0)

var font_size := FONT_SIZE


func _draw() -> void:
	var font := Glyph.font
	var s := font.get_string_size(CHAR, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var ascent := font.get_ascent(font_size)
	draw_string(font, Vector2(-s.x / 2.0, ascent - s.y / 2.0), CHAR,
			HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, COLOR)

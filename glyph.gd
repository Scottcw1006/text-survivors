class_name Glyph
extends Node2D
## 畫面上的每個角色（人、敵、子彈）都是一個置中繪製的文字。

static var font: Font

var text := ""
var font_size := 32
var color := Color.WHITE
var offset := Vector2.ZERO       # 只影響畫的位置，不影響碰撞（例如開槍後座力）


func setup(t: String, size: int, c: Color) -> Glyph:
	text = t
	font_size = size
	color = c
	return self


func set_text(t: String) -> void:
	text = t
	queue_redraw()


func _draw() -> void:
	var s := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var ascent := font.get_ascent(font_size)
	# 讓文字中心對齊節點位置
	draw_string(font, offset + Vector2(-s.x / 2.0, ascent - s.y / 2.0), text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

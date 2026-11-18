class_name HeartPickup
extends Node2D
## 補血道具：一顆像素畫的愛心（字型裡沒有 ♥，所以用小方塊畫），會輕輕地一縮一放。

const PIXEL := 5.0
const COLOR := Color(1.0, 0.35, 0.45)
const SHAPE := [
	".XX.XX.",
	"XXXXXXX",
	"XXXXXXX",
	".XXXXX.",
	"..XXX..",
	"...X...",
]

var t := randf() * TAU
var pulse := true    # 邊緣提示用的那顆不用跳


func _process(delta: float) -> void:
	if not pulse:
		return
	t += delta * 4.0
	var s := 1.0 + 0.08 * sin(t)
	scale = Vector2(s, s)


func _draw() -> void:
	var w := SHAPE[0].length()
	var h := SHAPE.size()
	var o := -Vector2(w, h) * PIXEL / 2.0
	for y in h:
		for x in w:
			if SHAPE[y][x] == "X":
				draw_rect(Rect2(o + Vector2(x, y) * PIXEL, Vector2(PIXEL, PIXEL)), COLOR)
	# 左上一點反光，比較像愛心
	draw_rect(Rect2(o + Vector2(1, 1) * PIXEL, Vector2(PIXEL, PIXEL)), Color(1, 0.8, 0.85))

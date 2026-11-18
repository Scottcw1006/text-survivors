class_name PauseMenu
extends Control
## 暫停畫面：一個「框」字圍起來的面板，裡面有音樂、音效音量和「繼續」。
## 鍵盤：W S 選、A D 調整、Space / Enter 在「繼續」上確定、Esc 直接繼續。
## 手機：點 ◀ ▶ 調整音量，點「繼續」回到遊戲。

const CELL := 20.0
const COLS := 26
const ROWS := 19
const ROW_NAMES := ["音樂", "音效", "繼續"]
const COLOR_ON := Color.WHITE
const COLOR_DIM := Color(1, 1, 1, 0.45)
const COLOR_PICK := Color(1.0, 0.85, 0.4)

var font: Font
var cursor := 0
var touch_mode := false
var _rects := {}   # "music-" / "music+" / "sfx-" / "sfx+" / "resume" -> Rect2（螢幕座標）


func open(is_touch: bool) -> void:
	touch_mode = is_touch
	cursor = 2 if is_touch else 0
	visible = true
	queue_redraw()


## 點到哪個按鈕，沒點到回傳空字串
func button_at(pos: Vector2) -> String:
	for key: String in _rects:
		if (_rects[key] as Rect2).has_point(pos):
			return key
	return ""


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.75))
	_rects.clear()
	# 電腦畫面很大，面板放大一點
	var k := 1.5 if size.x >= 2000.0 else 1.0
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(k, k))
	var view := size / k
	var w := COLS * CELL
	var h := ROWS * CELL
	var o := (view - Vector2(w, h)) / 2.0
	draw_rect(Rect2(o, Vector2(w, h)), Color.BLACK)
	for cx in COLS:
		for cy in ROWS:
			if cx == 0 or cy == 0 or cx == COLS - 1 or cy == ROWS - 1:
				_text("框", o + Vector2((cx + 0.5) * CELL, (cy + 0.5) * CELL), 17, COLOR_DIM)
	var mid := o.x + w / 2.0
	_text("暫停", Vector2(mid, o.y + 60.0), 44, COLOR_ON)

	var levels := [GameAudio.music_level, GameAudio.sfx_level]
	var keys := ["music", "sfx"]
	for row in 2:
		var y := o.y + 140.0 + row * 70.0
		var on := row == cursor
		var c := COLOR_PICK if on else COLOR_ON
		_text(ROW_NAMES[row], Vector2(o.x + 80.0, y), 33, c)
		var minus := Vector2(o.x + 150.0, y)
		var plus := Vector2(o.x + w - 60.0, y)
		_text("◀", minus, 33, c)
		_text("▶", plus, 33, c)
		var lv: int = levels[row]
		var bar := "■".repeat(lv) + "□".repeat(GameAudio.VOLUME_STEPS - lv)
		_text(bar, Vector2((minus.x + plus.x) / 2.0, y), 22, c)
		_rects[keys[row] + "-"] = _scaled(Rect2(minus - Vector2(36, 32), Vector2(72, 64)), k)
		_rects[keys[row] + "+"] = _scaled(Rect2(plus - Vector2(36, 32), Vector2(72, 64)), k)

	# 繼續：一個小框按鈕
	var by := o.y + 300.0
	var on_resume := cursor == 2
	var bw := 140.0
	var br := Rect2(Vector2(mid - bw / 2.0, by - 30.0), Vector2(bw, 60.0))
	draw_rect(br, Color(1, 1, 1, 0.12) if on_resume else Color.BLACK)
	draw_rect(br, COLOR_PICK if on_resume else COLOR_DIM, false, 2.0)
	_text("繼續", Vector2(mid, by), 33, COLOR_PICK if on_resume else COLOR_ON)
	_rects["resume"] = _scaled(br, k)

	var hint := "點 ◀ ▶ 調整音量" if touch_mode else "W S 選擇　A D 調整　Esc 繼續"
	_text(hint, Vector2(mid, o.y + h + 36.0), 22, COLOR_DIM)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _scaled(r: Rect2, k: float) -> Rect2:
	return Rect2(r.position * k, r.size * k)


func _text(text: String, center: Vector2, font_size: int, color: Color) -> void:
	var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var y := center.y + font.get_ascent(font_size) - font.get_height(font_size) / 2.0
	draw_string(font, Vector2(center.x - tw / 2.0, y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

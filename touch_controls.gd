class_name TouchControls
extends Control
## 手機觸控操作（選角時選「手機」模式才有虛擬搖桿和按鍵）：
## - 遊戲中：手指在螢幕上拖曳 = 虛擬搖桿（從按下的地方開始算方向）
## - 右下角兩顆虛擬按鍵：「技」= Shift，「天」= 滑鼠左鍵；右上角「停」= Esc 暫停
## - 選單：點卡片選它，再點一次已選的卡片 = 確定；結算畫面點「再來一局」按鈕
##   （選單用滑鼠點也可以，電腦模式也能用）
## 按鍵都是送出 InputEventAction，所以遊戲邏輯跟鍵盤共用同一套。

const STICK_RADIUS := 90.0         # 搖桿拖多遠算全速
const STICK_DEAD := 0.15           # 太小的晃動不算
const SKILL_RADIUS := 75.0
const SMITE_RADIUS := 58.0
const PAUSE_RADIUS := 34.0
const COLOR_LINE := Color(1, 1, 1, 0.35)
const COLOR_GLYPH := Color(1, 1, 1, 0.8)
const COLOR_OFF := Color(1, 1, 1, 0.2)
const MOUSE_FINGER := -100         # 滑鼠當成一根編號特別的手指

var main: Node                     # main.gd，用來問現在的狀態
var font: Font
var move := Vector2.ZERO           # 搖桿方向，長度 0~1

var _stick_finger := -1
var _stick_origin := Vector2.ZERO
var _stick_pos := Vector2.ZERO
var _button_fingers := {}          # 手指 index -> 它按下的 action（放開時要放掉同一個）


func skill_center() -> Vector2:
	return Vector2(size.x - 115.0, size.y - 115.0)


func pause_center() -> Vector2:
	return Vector2(size.x - 60.0, 150.0)


func smite_center() -> Vector2:
	return Vector2(size.x - 275.0, size.y - 75.0)


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		if t.pressed:
			_touch_down(t.index, t.position)
		else:
			_touch_up(t.index)
	elif event is InputEventMouseButton:
		# 滑鼠只用來點選單；遊戲中左鍵是天罰，交給原本的按鍵設定
		var m := event as InputEventMouseButton
		if m.button_index != MOUSE_BUTTON_LEFT:
			return
		if m.pressed and not main.is_playing():
			_menu_tap(MOUSE_FINGER, m.position)
		elif not m.pressed:
			_touch_up(MOUSE_FINGER)
	elif event is InputEventScreenDrag:
		var d := event as InputEventScreenDrag
		if d.index == _stick_finger:
			_stick_pos = d.position
			_update_stick()


func _touch_down(finger: int, pos: Vector2) -> void:
	if main.state == main.State.PAUSED:
		_press(finger, "pause")            # 暫停中：點哪裡都是繼續
		return
	if not main.is_playing():
		_menu_tap(finger, pos)
		return
	if main.is_touch:
		if pos.distance_to(pause_center()) < PAUSE_RADIUS * 1.4:
			_press(finger, "pause")
		elif pos.distance_to(skill_center()) < SKILL_RADIUS * 1.2:
			_press(finger, "skill")
		elif pos.distance_to(smite_center()) < SMITE_RADIUS * 1.2:
			_press(finger, "smite")
		elif _stick_finger < 0:
			_stick_finger = finger
			_stick_origin = pos
			_stick_pos = pos
			_update_stick()


func _menu_tap(finger: int, pos: Vector2) -> void:
	var cards: UpgradeCards = main.level_cards
	if not cards.visible:
		return
	# 選角畫面：點「操作模式」那行切換手機／電腦
	if main.state == main.State.SELECT and cards.subtitle_rect.has_point(pos):
		main.toggle_touch_mode()
		return
	if cards.cursor < 0:
		# 結算畫面：要點到「再來一局」按鈕才會重開
		if cards.button_rect.has_point(pos):
			_press(finger, "confirm")
		return
	var i := cards.card_at(pos)
	if i < 0:
		return
	if i == cards.cursor:
		_press(finger, "confirm")
	else:
		main.touch_select(i)


func _touch_up(finger: int) -> void:
	if finger == _stick_finger:
		_stick_finger = -1
		move = Vector2.ZERO
		queue_redraw()
	if _button_fingers.has(finger):
		_send(_button_fingers[finger], false)
		_button_fingers.erase(finger)
		queue_redraw()


func _press(finger: int, action: String) -> void:
	_button_fingers[finger] = action
	_send(action, true)
	queue_redraw()


func _send(action: String, pressed: bool) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = pressed
	Input.parse_input_event(ev)


func _update_stick() -> void:
	var v := (_stick_pos - _stick_origin) / STICK_RADIUS
	if v.length() > 1.0:
		v = v.normalized()
	move = v if v.length() > STICK_DEAD else Vector2.ZERO
	queue_redraw()


## 遊戲狀態改變（技能次數、天罰用掉、切換選單）時由 main 叫一次
func refresh() -> void:
	if not main.is_playing():
		_stick_finger = -1
		move = Vector2.ZERO
	queue_redraw()


func _draw() -> void:
	if not main.is_playing() or not main.is_touch:
		return

	# 搖桿：按下的地方畫一圈，手指的位置畫一個點
	if _stick_finger >= 0:
		draw_arc(_stick_origin, STICK_RADIUS, 0.0, TAU, 48, COLOR_LINE, 4.0)
		var knob := _stick_origin + move * STICK_RADIUS
		draw_circle(knob, 26.0, Color(1, 1, 1, 0.25))

	# 技：裡面寫剩幾次
	var charges: int = main.skill_charges
	var skill_on := charges > 0
	_button(skill_center(), SKILL_RADIUS, "技", skill_on, "skill")
	_text("●".repeat(charges) + "○".repeat(main.SKILL_MAX_CHARGES - charges),
			skill_center() + Vector2(0, 46), 22, COLOR_GLYPH if skill_on else COLOR_OFF)
	# 天：用掉就變暗
	_button(smite_center(), SMITE_RADIUS, "天", not main.smite_used, "smite")
	# 停：暫停（手機沒有 Esc）
	_button(pause_center(), PAUSE_RADIUS, "停", true, "pause", 33)


func _button(center: Vector2, r: float, glyph: String, on: bool, action: String, glyph_size := 44) -> void:
	var held := _button_fingers.values().has(action)
	if held:
		draw_circle(center, r, Color(1, 1, 1, 0.15))
	draw_arc(center, r, 0.0, TAU, 64, COLOR_LINE if on else COLOR_OFF, 4.0)
	_text(glyph, center, glyph_size, COLOR_GLYPH if on else COLOR_OFF)


func _text(text: String, center: Vector2, font_size: int, color: Color) -> void:
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var y := center.y + font.get_ascent(font_size) - font.get_height(font_size) / 2.0
	draw_string(font, Vector2(center.x - w / 2.0, y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

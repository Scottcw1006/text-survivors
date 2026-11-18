class_name GameAudio
extends Node
## 音樂與音效。檔案在 audio/，由 tools/gen_audio.py 產生。
## - play("hit")：播一個音效，同一個音效太密集時會略過（很多敵人同時被打不會吵成一團）
## - play_music("main")：換背景音樂（會循環）
## - 靜音：toggle_mute()，重開一局也會記得（直接靜音整個 Master bus）

const POOL_SIZE := 16
const MUSIC_DB := -12.0
## 每個音效的音量（dB）和最短間隔（秒），沒寫的就是 0 dB、不限制
const SFX_SETTINGS := {
	"shoot": [-12.0, 0.04],
	"slash": [-6.0, 0.04],
	"wave": [-9.0, 0.05],
	"hit": [-12.0, 0.06],
	"kill": [-9.0, 0.05],
	"gold": [-12.0, 0.04],
	"block": [-8.0, 0.06],
	"explode": [-4.0, 0.1],
	"ui_move": [-8.0, 0.0],
}

var _streams := {}
var _last_played := {}
var _pool: Array[AudioStreamPlayer] = []
var _next := 0
var _music: AudioStreamPlayer
var _music_name := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_pool.append(p)
	_music = AudioStreamPlayer.new()
	_music.volume_db = MUSIC_DB
	_music.finished.connect(func() -> void: _music.play())   # 播完再從頭播（保險，正常會自己循環）
	add_child(_music)


func _stream(path: String) -> AudioStream:
	if not _streams.has(path):
		_streams[path] = load(path) if ResourceLoader.exists(path) else null
	return _streams[path]


func play(sfx: String, pitch_jitter := 0.06) -> void:
	var setting: Array = SFX_SETTINGS.get(sfx, [0.0, 0.0])
	var now := Time.get_ticks_msec() / 1000.0
	if now - float(_last_played.get(sfx, -99.0)) < setting[1]:
		return
	var stream := _stream("res://audio/sfx_%s.wav" % sfx)
	if stream == null:
		return
	_last_played[sfx] = now
	var p := _pool[_next]
	_next = (_next + 1) % POOL_SIZE
	p.stream = stream
	p.volume_db = setting[0]
	p.pitch_scale = 1.0 + randf_range(-pitch_jitter, pitch_jitter)
	p.play()


func play_music(track: String) -> void:
	if track == _music_name and _music.playing:
		return
	_music_name = track
	var stream := _stream("res://audio/music_%s.wav" % track) as AudioStreamWAV
	if stream == null:
		return
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = int(stream.get_length() * stream.mix_rate)
	_music.stream = stream
	_music.play()


func stop_music() -> void:
	_music_name = ""
	_music.stop()


static func is_muted() -> bool:
	return AudioServer.is_bus_mute(0)


static func toggle_mute() -> void:
	AudioServer.set_bus_mute(0, not AudioServer.is_bus_mute(0))

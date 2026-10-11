extends Node
## P7 音频管理器（Autoload）：BGM 按场景切换循环播放，音效用播放池即播即放。
## 资源为 tools/gen_audio.py 程序化合成的 WAV（assets/audio/），零版权风险。

var _bgm: AudioStreamPlayer
var _voice: AudioStreamPlayer
var _sfx_pool: Array = []
var _current_bgm: String = ""


func _ready() -> void:
	_bgm = AudioStreamPlayer.new()
	_bgm.volume_db = -6.0
	add_child(_bgm)
	_voice = AudioStreamPlayer.new()
	_voice.volume_db = 0.0   # 语音最优先，响一点
	add_child(_voice)
	for i in 6:
		var p := AudioStreamPlayer.new()
		p.volume_db = -3.0
		add_child(p)
		_sfx_pool.append(p)


## 引擎退出/节点移除时停掉播放，避免 AudioStreamWAV 播放对象泄漏警告
func _exit_tree() -> void:
	if _bgm != null:
		_bgm.stop()
	if _voice != null:
		_voice.stop()
	for p in _sfx_pool:
		p.stop()


## track 为 assets/audio 下的文件名（不含扩展名）；"" 表示停止
func play_bgm(track: String) -> void:
	if track == _current_bgm:
		return
	_current_bgm = track
	if track == "":
		_bgm.stop()
		return
	var stream: AudioStream = _load_stream(track)
	if stream == null:
		return
	_bgm.stream = stream
	_bgm.play()


func play_sfx(track: String) -> void:
	var stream: AudioStream = _load_stream(track)
	if stream == null:
		return
	for p in _sfx_pool:
		if not p.playing:
			p.stream = stream
			p.play()
			return


## 角色语音：assets/audio/vo/vo_<uid>_<n>.wav，多条随机播一条；播放时压低 BGM
func play_voice(uid: String) -> void:
	var picks: Array = []
	for i in range(1, 5):
		var path := "res://assets/audio/vo/vo_%s_%d.wav" % [uid, i]
		if ResourceLoader.exists(path):
			picks.append(path)
	if picks.size() == 0:
		return
	var stream: AudioStream = load(picks[randi() % picks.size()])
	if stream == null:
		return
	_voice.stream = stream
	_voice.play()
	if _bgm.playing:
		_bgm.volume_db = -12.0
		_voice.finished.connect(func(): _bgm.volume_db = -6.0)


func _load_stream(track: String) -> AudioStream:
	var path := "res://assets/audio/%s.wav" % track
	if not ResourceLoader.exists(path):
		return null
	var s: AudioStream = load(path)
	if s is AudioStreamWAV and track.begins_with("bgm_"):
		# BGM 循环：整段 forward loop
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD
		s.loop_begin = 0
		s.loop_end = s.data.size() / 2   # 16bit 单声道：字节数/2 = 帧数
	return s

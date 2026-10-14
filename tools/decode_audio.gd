extends SceneTree
func _initialize():
	var stream = AudioStreamMP3.load_from_file("res://assets/audio/go-stones-source.mp3")
	if stream == null: quit(1); return
	var playback = stream.instantiate_playback()
	playback.start()
	var rate: int = int(AudioServer.get_mix_rate())
	var pcm: PackedByteArray = PackedByteArray()
	for block in range(int(ceil(stream.get_length()*rate/4096.0))):
		var samples = playback.mix_audio(1.0,4096)
		var offset: int = pcm.size()
		pcm.resize(offset+samples.size()*2)
		for i in range(samples.size()):
			pcm.encode_s16(offset+i*2,int(clampf((samples[i].x+samples[i].y)*0.5,-1,1)*32767))
	var wav: AudioStreamWAV = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.stereo = false
	wav.data = pcm
	wav.save_to_wav("res://.runtime/go-stones-decoded.wav")
	print("Decoded ",stream.get_length()," seconds at ",rate," Hz")
	quit()

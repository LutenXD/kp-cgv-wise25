#pragma once

#include <godot_cpp/classes/audio_stream_wav.hpp>
#include <godot_cpp/classes/sprite2d.hpp>

namespace godot {

class GDPiper : public Node {
	GDCLASS(GDPiper, Node)

private:
	double time_passed;

protected:
	static void _bind_methods();

public:
	GDPiper();
	~GDPiper();

	Ref<AudioStreamWAV> tts(String text, float speed, int speaker_id);
};

} // namespace godot
#include "gdpiper.h"
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/classes/audio_stream_wav.hpp>
#include <godot_cpp/variant/packed_byte_array.hpp>
#include <vector>
#include <algorithm> 
#include "piper.h"

using namespace godot;

Ref<AudioStreamWAV> make_stream_from_piper(const std::vector<float> &samples, int sample_rate);

void GDPiper::_bind_methods() {
    ClassDB::bind_method(D_METHOD("tts", "text", "speed", "speaker_id"), &GDPiper::tts);
}

GDPiper::GDPiper() {
    time_passed = 0.0;
}

GDPiper::~GDPiper() {
}

Ref<AudioStreamWAV> GDPiper::tts(String text, float speed, int speaker_id) {
    piper_synthesizer *synth = piper_create(
        "/home/frederik/uni/Master/KP/piper-voices/fransop_finetune.onnx",
        "/home/frederik/uni/Master/KP/piper-voices/fransop_finetune.onnx.json",
        "/home/frederik/uni/Master/KP/libpiper/install/espeak-ng-data/"
    );

    piper_synthesize_options options = piper_default_synthesize_options(synth);
    options.length_scale = speed;
    options.speaker_id = speaker_id;

    piper_synthesize_start(
        synth,
        text.utf8().get_data(),
        &options
    );

    std::vector<float> samples;
    piper_audio_chunk chunk;

    while (piper_synthesize_next(synth, &chunk) != PIPER_DONE) {
        samples.insert(samples.end(), chunk.samples, chunk.samples + chunk.num_samples);
    }

    uint32_t sample_rate = 22050;

    Ref<AudioStreamWAV> stream = make_stream_from_piper(samples, sample_rate);

    piper_free(synth);

    return stream;
}


Ref<AudioStreamWAV> make_stream_from_piper(const std::vector<float> &samples, int sample_rate) {
    Ref<AudioStreamWAV> stream;
    stream.instantiate();

    PackedByteArray data;
    data.resize(samples.size() * 2); // 16-bit PCM, 2 bytes per sample

    for (size_t i = 0; i < samples.size(); i++) {
        float f = std::clamp(samples[i], -1.0f, 1.0f);
        int16_t s = static_cast<int16_t>(f * 32767.0f);
        data[i * 2 + 0] = s & 0xFF;
        data[i * 2 + 1] = (s >> 8) & 0xFF;
    }

    stream->set_data(data);
    stream->set_format(AudioStreamWAV::FORMAT_16_BITS);
    stream->set_mix_rate(sample_rate);
    stream->set_stereo(false);

    return stream;
}

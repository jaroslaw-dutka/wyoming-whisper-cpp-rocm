python3 -m wyoming_whisper_cpp \
    --whisper-cpp-dir '/usr/share/wyoming-whisper-cpp/whisper.cpp' \
    --uri 'tcp://0.0.0.0:10300' \
    --data-dir /data \
    --download-dir /data \
    --model "" \
    --language "$(bashio::config 'language')" \
    --beam-size "$(bashio::config 'beam_size')" \
    --audio-context-base "$(bashio::config 'audio_context_base')" ${flags[@]}
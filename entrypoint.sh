#!/bin/sh

/app/venv/bin/python -m wyoming_whisper_cpp \
	--whisper-cpp-dir /app/whisper.cpp \
	--uri tcp://0.0.0.0:10300 \
	--data-dir /data \
	--download-dir /data \
	--model $MODEL




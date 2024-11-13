ARG UBUNTU_VERSION=24.04
ARG ROCM_VERSION=6.2

FROM rocm/dev-ubuntu-${UBUNTU_VERSION}:${ROCM_VERSION}-complete AS build

RUN apt update && \
    apt install git build-essential -y && \
    rm -rf /var/lib/apt/lists/*
RUN git clone https://github.com/ggerganov/whisper.cpp.git /whisper.cpp

WORKDIR /whisper.cpp

RUN sh ./models/download-ggml-model.sh base.en

#ARG GFX_TARGETS="gfx803 gfx900 gfx906 gfx908 gfx90a gfx1010 gfx1030 gfx1100 gfx1101 gfx1102 gfx1103"
ARG GFX_TARGETS="gfx1100"
ENV AMDGPU_TARGETS=$GFX_TARGETS
RUN make -j 8 GGML_HIPBLAS=1

RUN ldd /whisper.cpp/main | grep "/opt/rocm/lib" | awk '/=> \// { print $(NF-1) }' | while read lib; do \
        mkdir -p "/runtime/$(dirname $lib)" &&  cp "$lib" "/runtime/$lib"; \
    done

FROM ubuntu:${UBUNTU_VERSION} AS whisper

RUN apt update && \
    apt install -y --no-install-recommends libnuma1 libelf1 libgomp1 && \
    rm -rf /var/lib/apt/lists/*

COPY --from=build /opt/amdgpu /opt/amdgpu
COPY --from=build /opt/rocm/lib/rocblas/library /opt/rocm/lib/rocblas/library
COPY --from=build /runtime/opt /opt
COPY --from=build /etc/ld.so.conf.d /etc/ld.so.conf.d

RUN ldconfig

COPY --from=build /whisper.cpp /app//whisper.cpp

FROM whisper

WORKDIR /app

RUN apt update && \
    apt install -y --no-install-recommends curl python3 python3-pip python3-venv && \
    rm -rf /var/lib/apt/lists/*

COPY wyoming_whisper_cpp ./wyoming_whisper_cpp
COPY requirements.txt ./

RUN python3 -m venv venv
RUN	venv/bin/pip install -r requirements.txt

COPY run.sh run.sh

ENTRYPOINT ["/app/venv/bin/python", \
			"-m", "wyoming_whisper_cpp", \
			"--whisper-cpp-dir", "/app/whisper.cpp", \
			"--uri", "tcp://0.0.0.0:10300", \
			"--data-dir", "/data", \
			"--download-dir", "/data" \
			]
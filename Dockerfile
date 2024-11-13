ARG UBUNTU_VERSION=24.04
ARG ROCM_VERSION=6.2

FROM rocm/dev-ubuntu-${UBUNTU_VERSION}:${ROCM_VERSION}-complete AS whisper-build

#ARG GFX_TARGETS="gfx803 gfx900 gfx906 gfx908 gfx90a gfx1010 gfx1030 gfx1100 gfx1101 gfx1102 gfx1103"
ARG GFX_TARGETS="gfx1100"
ENV AMDGPU_TARGETS=$GFX_TARGETS

WORKDIR /app/whisper.cpp

RUN apt update && \
    apt install git build-essential -y && \
    rm -rf /var/lib/apt/lists/*

RUN git clone https://github.com/ggerganov/whisper.cpp.git /app/whisper.cpp

COPY ./main ./examples/main
RUN make -j8 GGML_HIPBLAS=1

RUN ldd /app/whisper.cpp/main | grep "rocm" | awk '/=> \// { print $(NF-1) }' | while read lib; do \
        mkdir -p "/runtime/$(dirname $lib)" &&  cp "$lib" "/runtime/$lib"; \
    done

#------------------------------------------------------------------------------
FROM ubuntu:${UBUNTU_VERSION} AS whisper-release

ARG ROCM_VERSION

RUN apt update && \
    apt install -y --no-install-recommends libnuma1 libelf1 libgomp1 && \
    rm -rf /var/lib/apt/lists/*

COPY --from=whisper-build /app/whisper.cpp /app/whisper.cpp
COPY --from=whisper-build /opt/amdgpu /opt/amdgpu
COPY --from=whisper-build /opt/rocm/lib/rocblas/library /opt/rocm/lib/rocblas/library
COPY --from=whisper-build /runtime/opt /opt
COPY --from=whisper-build /etc/ld.so.conf.d /etc/ld.so.conf.d

RUN ldconfig

#------------------------------------------------------------------------------
FROM whisper-release

ENV MODEL=small

WORKDIR /app

RUN apt update && \
    apt install -y --no-install-recommends curl python3 python3-pip python3-venv && \
    rm -rf /var/lib/apt/lists/*

COPY requirements.txt ./
RUN python3 -m venv venv
RUN	venv/bin/pip install -r requirements.txt

COPY wyoming_whisper_cpp ./wyoming_whisper_cpp

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
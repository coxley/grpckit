ARG debian=bookworm
ARG go=1.21
ARG libprotoc_version
ARG grpc
ARG grpc_java
ARG buf_version
ARG grpc_web

# Pure go binaries
FROM golang:$go-$debian AS build-go
ARG libprotoc_version
ARG grpc
ARG BUILDARCH

RUN apt-get update && apt-get install -y -qq unzip wget

# Pin protoc version https://github.com/kserve/rest-proxy/blob/4e55a008eb2199184ab15b9740a29f58172790b6/Dockerfile#L48-L73

RUN export ZIP=x86_64 \
    && if [ ${BUILDARCH} = "arm64" ]; then export ZIP=aarch_64; fi \
    && wget -qO protoc.zip "https://github.com/protocolbuffers/protobuf/releases/download/v${libprotoc_version}/protoc-${libprotoc_version}-linux-${ZIP}.zip" \
    && unzip protoc.zip -x readme.txt -d /usr/local \
    && chmod +x /usr/local/bin/protoc \
    && protoc --version

# Go get go-related bins
RUN go install google.golang.org/protobuf/cmd/protoc-gen-go@latest && \
    go install google.golang.org/grpc/cmd/protoc-gen-go-grpc@latest

# Gogo and Gogo Fast
RUN go install github.com/gogo/protobuf/protoc-gen-gogo@latest && \
    go install github.com/gogo/protobuf/protoc-gen-gogofast@latest && \
    go install github.com/gogo/protobuf/protoc-gen-gogoslick@latest

# Lint
RUN go install github.com/ckaznocha/protoc-gen-lint@latest

# Validations
RUN go install github.com/envoyproxy/protoc-gen-validate@latest

# Docs
RUN go install github.com/pseudomuto/protoc-gen-doc/cmd/protoc-gen-doc@latest

# Install google openapi
# https://github.com/google/gnostic/tree/master/cmd/protoc-gen-openapi
RUN go install github.com/google/gnostic/cmd/protoc-gen-openapi@latest

# Figure out if this is a naming collision
# RUN go get -u github.com/micro/protobuf/protoc-gen-go

# Omniproto
RUN go install github.com/grpckit/omniproto@latest

RUN go install github.com/GoogleCloudPlatform/protoc-gen-bq-schema@latest

# Add Ruby Sorbet types support (rbi)
RUN go install github.com/coinbase/protoc-gen-rbi@latest

# vtproto
RUN go install github.com/planetscale/vtprotobuf/cmd/protoc-gen-go-vtproto@latest

FROM build-go AS build
ARG grpc
ARG grpc_java
ARG buf_version
ARG grpc_web

# TIL docker arg variables need to be redefined in each build stage
ARG grpc
ARG grpc_java
ARG grpc_web
ARG buf_version

# Parallel cmake
ENV CMAKE_BUILD_PARALLEL_LEVEL=8

# update path for go get dependencies
ENV PATH "$PATH:/opt/bin"

RUN set -ex && apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    pkg-config \
    cmake \
    curl \
    git \
    openjdk-11-jre \
    unzip \
    libtool \
    autoconf \
    zlib1g-dev \
    libssl-dev \
    make

WORKDIR /tmp

RUN git clone --depth 1 --shallow-submodules -b v$grpc --recursive https://github.com/grpc/grpc && cd grpc
RUN mkdir -p /tmp/grpc/cmake/build
WORKDIR /tmp/grpc/cmake/build
RUN cmake ../..  \
    -DCMAKE_BUILD_TYPE=Release \
    -DgRPC_INSTALL=ON \
    -DgRPC_BUILD_TESTS=OFF \
    -DgRPC_ZLIB_PROVIDER=package \
    -DgRPC_SSL_PROVIDER=package \
    -DCMAKE_INSTALL_PREFIX=/opt && \
    make && \
    make install

WORKDIR /tmp
RUN git clone --depth 1 --shallow-submodules -b v$grpc_java --recursive https://github.com/grpc/grpc-java.git && cd grpc-java
WORKDIR /tmp/grpc-java/compiler
RUN CXXFLAGS="-I/opt/include" LDFLAGS="-L/opt/lib" ../gradlew -PskipAndroid=true java_pluginExecutable

WORKDIR /tmp

# Install Buf
RUN BIN="/usr/local/bin" && \
    BINARY_NAME="buf" && \
    curl -sSL \
    "https://github.com/bufbuild/buf/releases/download/v"$buf_version"/${BINARY_NAME}-$(uname -s)-$(uname -m)" \
    -o "${BIN}/${BINARY_NAME}" && \
    chmod +x "${BIN}/${BINARY_NAME}"

WORKDIR /tmp

# Add scala support
RUN curl -LO https://github.com/scalapb/ScalaPB/releases/download/v0.9.6/protoc-gen-scala-0.9.6-linux-x86_64.zip \
    && unzip protoc-gen-scala-0.9.6-linux-x86_64.zip \
    && chmod +x /tmp/protoc-gen-scala

# Add grpc-web support
RUN curl -sSL https://github.com/grpc/grpc-web/releases/download/${grpc_web}/protoc-gen-grpc-web-${grpc_web}-linux-x86_64 \
    -o /tmp/grpc_web_plugin && \
    chmod +x /tmp/grpc_web_plugin

FROM debian:$debian-slim AS grpckit

RUN mkdir -p /usr/share/man/man1
RUN set -ex && apt-get update && apt-get install -y --no-install-recommends \
    bash \
    ca-certificates \
    nodejs \
    npm \
    zlib1g \
    libssl1.1 \
    openjdk-11-jre

WORKDIR /workspace

# Add TypeScript support
RUN npm config set unsafe-perm true
RUN npm i -g ts-protoc-gen@0.12.0

COPY --from=build /opt/bin/ /usr/local/bin/
COPY --from=build /opt/include/ /usr/local/include/
COPY --from=build /opt/lib/ /usr/local/lib/
COPY --from=build /opt/share/ /usr/local/share/
COPY --from=build /tmp/grpc-java/compiler/build/exe/java_plugin/protoc-gen-grpc-java /usr/local/bin/
COPY --from=build /go/bin/ /usr/local/bin/
COPY --from=build /tmp/grpc_web_plugin /usr/local/bin/protoc-gen-grpc-web
COPY --from=build /usr/local/bin/buf /usr/local/bin/buf
COPY --from=build /tmp/protoc-gen-scala /usr/local/bin/

# NB(MLH) We shouldn't need to copy these to include, as protofiles should be sourced elsewhere
# COPY --from=build /go/src/github.com/envoyproxy/protoc-gen-validate/ /opt/include/github.com/envoyproxy/protoc-gen-validate/
# COPY --from=build /go/src/github.com/mwitkow/go-proto-validators/ /opt/include/github.com/mwitkow/go-proto-validators/

# protoc
FROM grpckit AS protoc
ENTRYPOINT [ "protoc" ]

# buf
FROM grpckit AS buf
ENTRYPOINT [ "buf" ]

# omnikit
FROM grpckit AS omniproto
ENTRYPOINT [ "omniproto" ]

FROM grpckit

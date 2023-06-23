VERSION 0.6

# global arguments available to all stages - explicitly kept minimal to avoid losing cache hits
ARG GO_VERSION=1.20
ARG DEBIAN_DISTRO=bullseye
ARG DOCKER_REPO=grpckit

FROM golang:$GO_VERSION-$DEBIAN_DISTRO
RUN apt-get update && apt-get install -y -qq unzip wget

ci:
  BUILD +grpckit-omniproto

protoc:
  ARG USERARCH # Earthly Arg Providing Host Architecture
  ARG LIBPROTOC_VERSION=22.2
  ARG GRPC_VERSION=1.53.0
  ARG GRPC_JAVA_VERSION=1.54.0
  ARG GRPC_WEB_VERSION=1.4.2
  ARG BUF_VERSION=1.16.0
  ARG BUILD_VERSION=1
  ARG DOCKER_REPO=grpckit

  ENV CMAKE_BUILD_PARALLEL_LEVEL=$(nproc)
  ENV PATH "$PATH:/opt/bin"

  RUN apt-get update && apt-get install -y --no-install-recommends \
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

  # Install Protoc based on architecture
  IF [ "$USERARCH" = "amd64" ]
    RUN curl --silent --retry 3 --retry-all-errors --location https://github.com/protocolbuffers/protobuf/releases/download/v${LIBPROTOC_VERSION}/protoc-${LIBPROTOC_VERSION}-linux-x86_64.zip --output protoc.zip
  ELSE IF [ "$USERARCH" = "arm64" ]
    RUN curl --silent --retry 3 --retry-all-errors --location https://github.com/protocolbuffers/protobuf/releases/download/v${LIBPROTOC_VERSION}/protoc-${LIBPROTOC_VERSION}-linux-aarch_64.zip --output protoc.zip
  ELSE
    RUN echo "unsupported architecture"
    RUN exit 1
  END

  RUN unzip protoc.zip -x readme.txt -d /usr/local \
      && chmod +x /usr/local/bin/protoc \
      && protoc --version

  WORKDIR /tmp

  # Install GRPC Libraries
  RUN git clone --depth 1 --shallow-submodules -b v${GRPC_VERSION} --recursive https://github.com/grpc/grpc && cd grpc
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

  # Install GRPC Java
  WORKDIR /tmp
  RUN git clone --depth 1 --shallow-submodules -b v${GRPC_JAVA_VERSION} --recursive https://github.com/grpc/grpc-java.git && cd grpc-java
  WORKDIR /tmp/grpc-java/compiler
  RUN CXXFLAGS="-I/opt/include" LDFLAGS="-L/opt/lib" ../gradlew -PskipAndroid=true java_pluginExecutable
  WORKDIR /tmp
  SAVE IMAGE --push --cache-from=${DOCKER_REPO}/grpckit-build:latest ${DOCKER_REPO}/grpckit-build:protoc-${GRPC_VERSION}_${BUILD_VERSION}

protobuf-go:
  FROM +protoc
  # Install Buf
  RUN BIN="/usr/local/bin" && \
      BINARY_NAME="buf" && \
      curl -sSL \
      "https://github.com/bufbuild/buf/releases/download/v${BUF_VERSION}/${BINARY_NAME}-$(uname -s)-$(uname -m)" \
      -o "${BIN}/${BINARY_NAME}" && \
      chmod +x "${BIN}/${BINARY_NAME}"
  WORKDIR /tmp

  # Add grpc-web support
  RUN curl -sSL https://github.com/grpc/grpc-web/releases/download/${GRPC_WEB_VERSION}/protoc-gen-grpc-web-${GRPC_WEB_VERSION}-linux-x86_64 \
      -o /tmp/grpc_web_plugin && \
      chmod +x /tmp/grpc_web_plugin

  # Add scala support
  RUN curl -LO https://github.com/scalapb/ScalaPB/releases/download/v0.9.6/protoc-gen-scala-0.9.6-linux-x86_64.zip \
      && unzip protoc-gen-scala-0.9.6-linux-x86_64.zip \
      && chmod +x /tmp/protoc-gen-scala

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

  # Install OpenApi
  RUN go install github.com/google/gnostic/cmd/protoc-gen-openapi@latest

  # Figure out if this is a naming collision
  # RUN go get -u github.com/micro/protobuf/protoc-gen-go

  # Omniproto
  RUN go install github.com/grpckit/omniproto@latest

  # BigQuery Schema
  RUN go install github.com/GoogleCloudPlatform/protoc-gen-bq-schema@latest

  # Add Ruby Sorbet types support (rbi)
  RUN go install github.com/coinbase/protoc-gen-rbi@latest

  SAVE ARTIFACT /opt/bin /opt/bin
  SAVE ARTIFACT /opt/include /opt/include
  SAVE ARTIFACT /opt/lib /opt/lib
  SAVE ARTIFACT /opt/share /opt/share
  SAVE ARTIFACT /tmp/grpc-java/compiler/build/exe/java_plugin/protoc-gen-grpc-java /protoc-gen-grpc-java
  SAVE ARTIFACT /go/bin /go/bin
  SAVE ARTIFACT /tmp/grpc_web_plugin /grpc_web_plugin
  SAVE ARTIFACT /usr/local/bin/buf /buf
  SAVE ARTIFACT /tmp/protoc-gen-scala /protoc-gen-scala

grpckit:
  ARG DEBIAN_DISTRO=bullseye
  FROM debian:${DEBIAN_DISTRO}-slim
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

  COPY --dir +protobuf-go/opt/bin /usr/local/
  COPY --dir +protobuf-go/opt/include /usr/local/
  COPY --dir +protobuf-go/opt/lib /usr/local/
  COPY --dir +protobuf-go/opt/share /usr/local/
  COPY --dir +protobuf-go/go/bin/ /usr/local/
  COPY +protobuf-go/protoc-gen-grpc-java /usr/local/bin/
  COPY +protobuf-go/grpc_web_plugin /usr/local/bin/protoc-gen-grpc-web
  COPY +protobuf-go/buf /usr/local/bin/buf
  COPY +protobuf-go/protoc-gen-scala /usr/local/bin/

grpckit-protoc:
  FROM +grpckit
  ARG GRPC_VERSION=1.53.0
  ARG GRPC_WEB_VERSION=1.4.2
  ARG BUILD_VERSION=1
  RUN protoc --version
  ENTRYPOINT ["protoc"]
  SAVE IMAGE --push --cache-from=${DOCKER_REPO}/protoc:latest ${DOCKER_REPO}/protoc:${GRPC_VERSION}_${BUILD_VERSION}

grpckit-buf:
  FROM +grpckit
  ARG GRPC_VERSION=1.53.0
  ARG GRPC_WEB_VERSION=1.4.2
  ARG BUILD_VERSION=1
  RUN buf --version
  ENTRYPOINT ["buf"]
  SAVE IMAGE --push --cache-from=${DOCKER_REPO}/buf:latest ${DOCKER_REPO}/buf:${GRPC_VERSION}_${BUILD_VERSION}

grpckit-omniproto:
  FROM +grpckit
  ARG GRPC_VERSION=1.53.0
  ARG GRPC_WEB_VERSION=1.4.2
  ARG BUILD_VERSION=1
  ENTRYPOINT ["omniproto"]
  SAVE IMAGE --push --cache-from=${DOCKER_REPO}/omniproto:latest ${DOCKER_REPO}/omniproto:${GRPC_VERSION}_${BUILD_VERSION}

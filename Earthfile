VERSION 0.7

# global arguments available to all stages - explicitly kept minimal to avoid losing cache hits
ARG BUILD_VERSION=2
ARG DEBIAN_DISTRO=bookworm
ARG DOCKER_REPO=grpckit
ARG GO_VERSION=1.21
ARG GRPC_JAVA_VERSION=1.54.0
ARG GRPC_VERSION=1.53.0

FROM golang:$GO_VERSION-$DEBIAN_DISTRO
RUN apt-get -qq update && apt-get -qq install -y unzip wget

build-all-omniproto:
    BUILD --platform=linux/arm64 --platform=linux/amd64 +grpckit-omniproto
build-all-protoc:
    BUILD --platform=linux/arm64 --platform=linux/amd64 +grpckit-protoc
build-all-buf:
    BUILD --platform=linux/arm64 --platform=linux/amd64 +grpckit-buf

protoc-compiler:
  # Earthly Arg Providing Target Architecture
  ARG TARGETPLATFORM
  ARG TARGETARCH
  ARG LIBPROTOC_VERSION=22.2
  ARG GRPC_VERSION=1.53.0
  ARG GRPC_JAVA_VERSION=1.54.0
  ARG DEBIAN_DISTRO=bookworm
  FROM --platform=${TARGETPLATFORM} debian:${DEBIAN_DISTRO}

  ENV CMAKE_BUILD_PARALLEL_LEVEL=$(nproc)
  ENV PATH "$PATH:/opt/bin"

  RUN apt-get -qq update >/dev.null && \
    apt-get -qq install -y --no-install-recommends \
    build-essential \
    pkg-config \
    cmake \
    curl \
    git \
    unzip \
    libtool \
    autoconf \
    zlib1g-dev \
    libssl-dev \
    make wget >/dev.null
  IF [ "$TARGETARCH" = "amd64" ]
      RUN wget http://snapshot.debian.org/archive/debian/20190501T215844Z/pool/main/g/glibc/multiarch-support_2.28-10_${TARGETARCH}.deb >/dev.null && \
          dpkg -i multiarch-support*.deb >/dev.null
  END
  RUN apt-get -qq update >/dev.null && \
      apt-get -qq install -y ca-certificates apt-transport-https >/dev.null
  RUN mkdir -p /etc/apt/keyrings && \
      wget -O - https://packages.adoptium.net/artifactory/api/gpg/key/public | tee /etc/apt/keyrings/adoptium.asc >/dev.null && \
      echo "deb [signed-by=/etc/apt/keyrings/adoptium.asc] https://packages.adoptium.net/artifactory/deb $(awk -F= '/^VERSION_CODENAME/{print$2}' /etc/os-release) main" | tee /etc/apt/sources.list.d/adoptium.list >/dev.null
  RUN apt-get -qq update >/dev.null && \
      apt-get -qq install -y temurin-17-jdk >/dev.null

  # Install Protoc based on architecture
  IF [ "$TARGETARCH" = "amd64" ]
    RUN curl --silent --retry 3 --retry-all-errors --location https://github.com/protocolbuffers/protobuf/releases/download/v${LIBPROTOC_VERSION}/protoc-${LIBPROTOC_VERSION}-linux-x86_64.zip --output protoc.zip
  ELSE IF [ "$TARGETARCH" = "arm64" ]
    RUN curl --silent --retry 3 --retry-all-errors --location https://github.com/protocolbuffers/protobuf/releases/download/v${LIBPROTOC_VERSION}/protoc-${LIBPROTOC_VERSION}-linux-aarch_64.zip --output protoc.zip
  ELSE IF [ "$TARGETARCH" = "arm" ]
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
  RUN git clone --depth 1 --shallow-submodules -b v${GRPC_VERSION} --recursive https://github.com/grpc/grpc >/dev.null && cd grpc
  RUN mkdir -p /tmp/grpc/cmake/build
  WORKDIR /tmp/grpc/cmake/build
  RUN cmake ../..  \
      -DCMAKE_BUILD_TYPE=Release \
      -DgRPC_INSTALL=ON \
      -DgRPC_BUILD_TESTS=OFF \
      -DgRPC_ZLIB_PROVIDER=package \
      -DgRPC_SSL_PROVIDER=package \
      -DCMAKE_INSTALL_PREFIX=/opt 2>&1 && \
      make && \
      make install

  # Install GRPC Java
  WORKDIR /tmp
  RUN git clone --depth 1 --shallow-submodules -b v${GRPC_JAVA_VERSION} --recursive https://github.com/grpc/grpc-java.git >/dev.null && cd grpc-java
  WORKDIR /tmp/grpc-java/compiler
  RUN cd /tmp/grpc-java/compiler && \
      CXXFLAGS="-I/opt/include" LDFLAGS="-L/opt/lib" ../gradlew -PskipAndroid=true java_pluginExecutable >/dev.null && \
      cp /tmp/grpc-java/compiler/build/exe/java_plugin/protoc-gen-grpc-java /usr/local/bin/protoc-gen-grpc-java

  SAVE ARTIFACT /opt/bin                      /opt/bin
  SAVE ARTIFACT /opt/include                  /opt/include
  SAVE ARTIFACT /opt/lib                      /opt/lib
  SAVE ARTIFACT /opt/share                    /opt/share
  SAVE ARTIFACT /usr/local/bin/protoc-gen-grpc-java /protoc-gen-grpc-java

protobuf-buf:
    ARG BUF_VERSION=1.26.1
    FROM --platform=${TARGETPLATFORM} bufbuild/buf:${BUF_VERSION}

protoc-gen-grpc-web:
  ARG GRPC_WEB_VERSION=1.4.2
  WORKDIR /tmp
  RUN curl -sSL https://github.com/grpc/grpc-web/releases/download/${GRPC_WEB_VERSION}/protoc-gen-grpc-web-${GRPC_WEB_VERSION}-linux-${TARGETARCH} >/dev.null \
      -o /usr/local/bin/protoc-gen-grpc-web && \
      chmod +x /usr/local/bin/protoc-gen-grpc-web
  SAVE ARTIFACT /usr/local/bin/protoc-gen-grpc-web /protoc-gen-grpc-web

protoc-gen-scala:
    WORKDIR /tmp
    RUN curl -LO https://github.com/scalapb/ScalaPB/releases/download/v0.9.6/protoc-gen-scala-0.9.6-linux-x86_64.zip >/dev.null && \
        unzip protoc-gen-scala-0.9.6-linux-x86_64.zip && \
        chmod +x /tmp/protoc-gen-scala && \
        mv /tmp/protoc-gen-scala /usr/local/bin//protoc-gen-scala
    SAVE ARTIFACT /usr/local/bin/protoc-gen-scala /protoc-gen-scala

protobuf-go:
  ARG GOOS
  ARG GOARCH
  ARG GO_VERSION=1.21
  ARG DEBIAN_DISTRO=bookworm
  FROM --platform=${TARGETPLATFORM} golang:$GO_VERSION-$DEBIAN_DISTRO
  WORKDIR /tmp

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

  # vtproto
  RUN go install github.com/planetscale/vtprotobuf/cmd/protoc-gen-go-vtproto@latest

  SAVE ARTIFACT /go/bin /go/bin

grpckit-build:
  ARG TARGETPLATFORM
  ARG TARGETOS
  ARG TARGETARCH
  ARG TARGETVARIANT
  ARG DEBIAN_DISTRO=bookworm
  ARG DOCKER_REPO=grpckit
  ARG GRPC_VERSION=1.53.0
  ARG BUILD_VERSION=2
  FROM --platform=${TARGETPLATFORM} debian:${DEBIAN_DISTRO}-slim
  WORKDIR /workspace
  RUN mkdir -p /usr/share/man/man1 && \
      set -ex && \
      apt-get -qq update >/dev.null && \
      apt-get -qq install -y --no-install-recommends \
      bash \
      ca-certificates \
      nodejs \
      npm \
      zlib1g >/dev.null && \
      npm i -g ts-protoc-gen@0.15.0 >/dev.null
  COPY --dir +protoc-compiler/opt/bin               /usr/local/
  COPY --dir +protoc-compiler/opt/include           /usr/local/
  COPY --dir +protoc-compiler/opt/lib               /usr/local/
  COPY --dir +protoc-compiler/opt/share             /usr/local/
  COPY --dir +protobuf-go/go/bin/                   /usr/local/
  COPY +protoc-compiler/protoc-gen-grpc-java        /usr/local/bin/
  COPY +protoc-gen-grpc-web/protoc-gen-grpc-web     /usr/local/bin/protoc-gen-grpc-web
  COPY +protoc-gen-scala/protoc-gen-scala           /usr/local/bin/
  SAVE IMAGE --push --cache-from=${DOCKER_REPO}/grpckit-build:protoc-${GRPC_VERSION}_${BUILD_VERSION}_${TARGETARCH} ${DOCKER_REPO}/grpckit-build:protoc-${GRPC_VERSION}_${BUILD_VERSION}
  SAVE IMAGE --push --cache-from=${DOCKER_REPO}/grpckit-build:protoc-${GRPC_VERSION}_${BUILD_VERSION}_${TARGETARCH} ${DOCKER_REPO}/grpckit-build:protoc-${GRPC_VERSION}_${BUILD_VERSION}_${TARGETARCH}

grpckit-protoc:
    ARG TARGETARCH
    ARG DOCKER_REPO=grpckit
    ARG GRPC_VERSION=1.53.0
    ARG BUILD_VERSION=2
    FROM ${DOCKER_REPO}/grpckit-build:protoc-${GRPC_VERSION}_${BUILD_VERSION}_${TARGETARCH}
    RUN protoc --version
    ENTRYPOINT ["protoc"]
    SAVE IMAGE --push --cache-from=${DOCKER_REPO}/protoc:latest ${DOCKER_REPO}/protoc:${GRPC_VERSION}_${BUILD_VERSION}

grpckit-buf:
    ARG TARGETARCH
    ARG DOCKER_REPO=grpckit
    ARG GRPC_VERSION=1.53.0
    ARG BUILD_VERSION=2
    FROM ${DOCKER_REPO}/grpckit-build:protoc-${GRPC_VERSION}_${BUILD_VERSION}_${TARGETARCH}
    COPY +protobuf-buf/buf /usr/local/bin/
    RUN /usr/local/bin/buf --version
    ENTRYPOINT ["/usr/local/bin/buf"]
  SAVE IMAGE --push --cache-from=${DOCKER_REPO}/buf:latest ${DOCKER_REPO}/buf:${GRPC_VERSION}_${BUILD_VERSION}

grpckit-omniproto:
    ARG TARGETARCH
    ARG DOCKER_REPO=grpckit
    ARG GRPC_VERSION=1.53.0
    ARG BUILD_VERSION=2
    FROM ${DOCKER_REPO}/grpckit-build:protoc-${GRPC_VERSION}_${BUILD_VERSION}_${TARGETARCH}
    ENTRYPOINT ["omniproto"]
    SAVE IMAGE --push --cache-from=${DOCKER_REPO}/omniproto:latest ${DOCKER_REPO}/omniproto:${GRPC_VERSION}_${BUILD_VERSION}

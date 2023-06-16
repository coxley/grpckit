#!/bin/bash -e
source ./variables.sh

for build in ${BUILDS[@]}; do
    tag=${CONTAINER}/${build}:${GRPC_VERSION}_${BUILD_VERSION}
    echo "building ${build} container with tag ${tag}"
	docker buildx build -t ${tag} \
        -f Dockerfile \
        --platform=linux/$(uname -m) \
        --cache-from ${tag} \
        --build-arg libprotoc_version=${LIBPROTOC_VERSION} \
        --build-arg grpc=${GRPC_VERSION} \
        --build-arg grpc_java=${GRPC_JAVA_VERSION} \
        --build-arg grpc_web=${GRPC_WEB_VERSION} \
        --build-arg buf_version=${BUF_VERSION} \
        --target ${build} \
        .

    if [ "${LATEST}" = true ]; then
        echo "setting ${tag} to latest"
        docker tag ${tag} ${CONTAINER}/${build}:latest
    fi
done

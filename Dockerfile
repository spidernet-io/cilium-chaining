FROM --platform=$TARGETPLATFORM quay.io/cilium/cilium-builder:0a47f410d147719a579cd3c069fd0e4a84b8b055@sha256:191db32a7cb4c5143a6fcc8a83ffd9a701925bed7523e6628dc75cbadf694858 as cilium-builder
ARG GOPROXY
ENV GOPROXY $GOPROXY
ARG CILIUM_SHA=""
LABEL cilium-sha=${CILIUM_SHA}
LABEL maintainer="maintainer@cilium.io"
WORKDIR /go/src/github.com/cilium
ARG GIT_COMMIT_VERSION
ENV GIT_COMMIT_VERSION=${GIT_COMMIT_VERSION}
ARG GIT_COMMIT_TIME
ENV GIT_COMMIT_TIME=${GIT_COMMIT_TIME}
RUN rm -rf cilium
ENV GIT_TAG=v1.12.7
ENV GIT_COMMIT=67190636f1d5a7a443ea0bda585b215e7650dd25
RUN git clone -b $GIT_TAG --depth 1 https://github.com/cilium/cilium.git && \
    cd cilium && \
    [ "`git rev-parse HEAD`" = "${GIT_COMMIT}" ]
COPY patches /patches
RUN cd cilium && git apply /patches/*.patch
ARG NOSTRIP
ARG LOCKDEBUG
ARG V
ARG LIBNETWORK_PLUGIN
#
# Please do not add any dependency updates before the 'make install' here,
# as that will mess with caching for incremental builds!
#
RUN cd cilium && make NOSTRIP=$NOSTRIP LOCKDEBUG=$LOCKDEBUG PKG_BUILD=1 V=$V LIBNETWORK_PLUGIN=$LIBNETWORK_PLUGIN \
    SKIP_DOCS=true DESTDIR=/tmp/install clean-container build-container install-container
RUN cp /tmp/install/opt/cni/bin/cilium-cni /tmp/install/usr/bin/

RUN cd /go/src/github.com/cilium/cilium/operator && make cilium-operator-generic \
    && mv cilium-operator-generic /tmp/install/usr/bin/

FROM scratch
COPY --from=cilium-builder /tmp/install/ /bin
COPY init.sh /bin

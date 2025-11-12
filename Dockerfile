ARG UBUNTU_IMAGE=ubuntu:22.04
ARG CILIUM_LLVM_IMAGE=quay.io/cilium/cilium-llvm:547db7ec9a750b8f888a506709adb41f135b952e@sha256:4d6fa0aede3556c5fb5a9c71bc6b9585475ac9b1064f516d4c45c8fb691c9d9e
ARG CILIUM_BPFTOOL_IMAGE=quay.io/cilium/cilium-bpftool:78448c1a37ff2b790d5e25c3d8b8ec3e96e6405f@sha256:99a9453a921a8de99899ef82e0822f0c03f65d97005c064e231c06247ad8597d
ARG CILIUM_IPROUTE2_IMAGE=quay.io/cilium/cilium-iproute2:3570d58349efb2d6b0342369a836998c93afd291@sha256:1abcd7a5d2117190ab2690a163ee9cd135bc9e4cf8a4df662a8f993044c79342
ARG CILIUM_IPTABLES_IMAGE=quay.io/cilium/iptables-20.04:e6f83206c57e606282056903ffd3aab0183bdaed@sha256:7ce0de449d356a5259021dc13f2b00a8bddfbea57a1c91ff8f146d455cace9e5

FROM --platform=$TARGETPLATFORM ${CILIUM_LLVM_IMAGE} as llvm-dist
FROM --platform=$TARGETPLATFORM ${CILIUM_BPFTOOL_IMAGE} as bpftool-dist
FROM --platform=$TARGETPLATFORM ${CILIUM_IPROUTE2_IMAGE} as iproute2-dist
FROM --platform=$TARGETPLATFORM ${CILIUM_IPTABLES_IMAGE} as iptables-dist

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

FROM --platform=$TARGETPLATFORM ${UBUNTU_IMAGE}
RUN apt-get update && apt-get install -y kmod libelf1 libmnl0 iptables nftables kmod curl ipset bash ethtool bridge-utils socat grep findutils jq conntrack iputils-ping && \
    apt-get purge --auto-remove && apt-get clean && rm -rf /var/lib/apt/lists/*
COPY --from=llvm-dist /usr/local/bin/clang /usr/local/bin/llc /bin/
COPY --from=bpftool-dist /usr/local /usr/local
COPY --from=iproute2-dist /usr/local /usr/local
COPY --from=iproute2-dist /usr/lib/libbpf* /usr/lib/
COPY --from=iptables-dist /iptables /iptables
COPY --from=cilium-builder /tmp/install/ /
RUN dpkg -i /iptables/*\.deb && rm -rf /iptables

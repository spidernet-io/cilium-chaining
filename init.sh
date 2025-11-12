#!/bin/sh

set -o errexit
set -o nounset

ENABLE_HUBBLE=${ENABLE_HUBBLE:-false}
ENABLE_BANDWIDTH_MANAGER=${ENABLE_BANDWIDTH_MANAGER:-false}
HUBBLE_METRICS_SERVER=${HUBBLE_METRICS_SERVER:-9091}
HUBBLE_LISTEN_ADDRESS=${HUBBLE_LISTEN_ADDRESS:-4244}

formatENV() {
  value=$1
  echo ${value} | tr -d '[:space:]' | tr '[:upper:]' '[:lower:]'
}

kernel_version() {
  # check kernel version
  KERNEL_MAJOR_VERSION=$(uname -r | awk -F . '{print $1}')
  KERNEL_MINOR_VERSION=$(uname -r | awk -F . '{print $2}')
  # kernel version equal and above 4.19

  KERNEL_VERSION=$(uname -r)
  if { [ "$KERNEL_MAJOR_VERSION" -eq 4 ] && [ "$KERNEL_MINOR_VERSION" -le 19 ] ; } || [ "$KERNEL_MAJOR_VERSION" -lt 4 ]  ; then
    printf "kernel version: %s is less than 4.19, can't start cilium daemon\n" "$KERNEL_VERSION"
    exit 1
  fi

  printf "kernel version is %s, start cilium daemon\n" "$KERNEL_VERSION"
}


copy_cni_bin() {
  rm -f /opt/cni/bin/cilium-cni.old || true
  mv /opt/cni/bin/cilium-cni /opt/cni/bin/cilium-cni.old || true
  cp -f /usr/bin/cilium-cni /opt/cni/bin
  rm -f /opt/cni/bin/cilium-cni.old || true
}

start_cilium() {

  nsenter -t 1 -m -- bash -c 'mount | grep "/sys/fs/bpf type bpf" ||
  {
    echo "Mounting BPF filesystem..."
    mount bpffs /sys/fs/bpf -t bpf
    mount -o remount rw /proc/sys
  }'

  enable_in_cluster_loadbalance=false
  policy_enforcement=default
  kube_proxy_replacement=partial
  enable_hubble=false
  enable_bandwidth_manager=false
  agent_health_port=9100

  # service loadbalance
  if [ -n "$IN_CLUSTER_LOADBALANCE" ]; then
     enable_in_cluster_loadbalance=$(formatENV $IN_CLUSTER_LOADBALANCE)
  fi
  echo "enable_in_cluster_loadbalance: $enable_in_cluster_loadbalance"

  if [ -n "$POLICY_ENFORCEMENT" ]  ; then
     policy_enforcement=$(formatENV $POLICY_ENFORCEMENT)
  fi
  echo "policy_enforcement: $policy_enforcement"

  # kube-proxy replacement
  if [ -n "$KUBE_PROXY_REPLACEMENT" ]; then
    kube_proxy_replacement=$(formatENV $KUBE_PROXY_REPLACEMENT)
  fi
  echo "kube_proxy_replacement: ${kube_proxy_replacement}"

  # bandwidth manager
  if [ -n "$ENABLE_BANDWIDTH_MANAGER" ]; then
    enable_bandwidth_manager=$(formatENV $ENABLE_BANDWIDTH_MANAGER)
  fi

  # hubble
  if [ "$ENABLE_HUBBLE" = "true" ]; then
    enable_hubble_arg="--enable-hubble=true --hubble-disable-tls=true"
  fi

  hubble_metrics_arg=""
  if [ -n "$HUBBLE_METRICS" ]; then
    hubble_metrics_arg="--hubble-metrics=${HUBBLE_METRICS}"
  fi

  if [ -n "$AGENT_HEALTH_PORT" ]; then
    agent_health_port=$(formatENV $AGENT_HEALTH_PORT)
  fi
  echo "agent_health_port: ${agent_health_port}"

  # register crd
  cilium preflight register-crd

  # start daemon
  cilium-agent --tunnel=disabled \
    --enable-ipv4-masquerade=false \
    --enable-ipv6-masquerade=false \
    --disable-envoy-version-check=true \
    --enable-local-node-route=false \
    --ipv4-range=169.254.10.0/30 \
    --ipv6-range=fe80:2400:3200:baba::/30 \
    --enable-endpoint-health-checking=false  \
    --enable-health-checking=false \
    --enable-service-topology=true  \
    --disable-cnp-status-updates=true \
    --k8s-heartbeat-timeout=0 \
    --enable-session-affinity=true \
    --install-iptables-rules=false \
    --enable-l7-proxy=false \
    --ipam=cluster-pool  \
    --enable-bandwidth-manager=${enable_bandwidth_manager} \ 
    --enable-policy=${policy_enforcement}  \
    --enable-in-cluster-loadbalance=${enable_in_cluster_loadbalance} \
    --kube-proxy-replacement=${kube_proxy_replacement} \
    --hubble-metrics-server=${HUBBLE_METRICS_SERVER} \
    --hubble-listen-address=${HUBBLE_LISTEN_ADDRESS} \
    --agent-health-port=${AGENT_HEALTH_PORT} \
    ${enable_hubble_arg} ${hubble_metrics_arg}
}

kernel_version
copy_cni_bin
start_cilium
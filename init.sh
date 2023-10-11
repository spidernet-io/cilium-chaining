#!/bin/sh

set -o errexit
set -o nounset

func formatENV() {
  value=$1
  echo -e $value | tr -d '[:space:]' | tr '[:upper:]' '[:lower:]'
}

# check kernel version
KERNEL_MAJOR_VERSION=$(uname -r | awk -F . '{print $1}')
KERNEL_MINOR_VERSION=$(uname -r | awk -F . '{print $2}')
# kernel version equal and above 4.19

if [ "$KERNEL_MAJOR_VERSION" -lt 4 ] || { [ "$KERNEL_MAJOR_VERSION" -eq 4 ] && [ "$KERNEL_MINOR_VERSION" -le 19 ]} ; then
  KERNEL_VERSION=`uname -r`
  printf "kernel version: %s is less than 4.19, can't start cilium daemon\n" "$KERNEL_VERSION"
  exit 1
fi

printf "kernel version is %s, start cilium daemon\n" "$KERNEL_VERSION"

nsenter -t 1 -m -- bash -c 'mount | grep "/sys/fs/bpf type bpf" ||
{
  echo "Mounting BPF filesystem..."
  mount bpffs /sys/fs/bpf -t bpf
}'

mount -o remount rw /proc/sys

# service loadbalance
enable_in_cluster_loadbalance=$(formatENV $IN_CLUSTER_LOADBALANCE)
enable_in_cluster_loadbalance=${enable_in_cluster_loadbalance:-false}

# policy
policy_enforcement=$(formatENV $POLICY_ENFORCEMENT)
if [ -z "$policy_enforcement" ] || [ ! grep "$policy_enforcement" <<< "default always never" ] ; then
  policy_enforcement=default
fi

# kube-proxy replacement
kube_proxy_replacement=${formatENV $KUBE_PROXY_REPLACEMENT}
if [ -z "$kube_proxy_replacement" ]; then
  kube_proxy_replacement=partial
fi

# hubble
enable_hubble=$(formatENV $ENABLE_HUBBLE)
if [ ! -z "$enable_hubble" ]; then
  hubble_args=" --enable-hubble=true --hubble-disable-tls=true "
fi

hubble_listen_address=$(formatENV $HUBBLE_LISTEN_ADDRESS)
if [ -z "$hubble_listen_address" ]; then
  hubble_listen_address=":4244"
fi
hubble_args+=" --hubble-listen-address=${hubble_listen_address} "

hubble_metrics_server=${formatENV $HUBBLE_METRICS_SERVER}
if [ -z "$hubble_metrics_server" ]; then
  hubble_metrics_server=":9091"
fi
hubble_args+=" --hubble-metrics-server=${hubble_metrics_server} "

hubble_metrics=${formatENV $HUBBLE_METRICS}
if [ ! -z "$hubble_metrics" ] ; then
  hubble_args+=" --hubble-metrics=${hubble_metrics} "
fi

# register crd
cilium preflight register-crd

# start daemon
cilium-agent --tunnel=disabled \
  --enable-ipv4-masquerade=false \
  --enable-ipv6-masquerade=false \
  --agent-health-port=9099 \
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
  --enable-policy=${policy_enforcement}  \
  --enable-in-cluster-loadbalance=${enable_in_cluster_loadbalance} \
  --kube-proxy-replacement=${kube_proxy_replacement} \
  ${hubble_args}


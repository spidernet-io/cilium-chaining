# Cilium-chaining

Cilium-chaining is a project based on [cilium](https://github.com/cilium/cilium), It runs in cni-chaining-mode and works primarily with IPvlan. It can provide some the following capabilities for [Spiderpool](https://github.com/spidernet-io/spiderpool):

- Kubernetes network policy
- Observability
- Kube-proxy replacement
- Bandwidth

This project is inspired by [terway](https://github.com/AliyunContainerService/terway), Thanks for the great works 👍.

## How to use it

You can use `kubectl` or `helm` install it. For example, refer to the following command:

Kubectl:

```shell
kubectl apply manifests/cilium-chaining.yaml -n kube-system
```

Helm:

```shell
helm install cilium-chaining charts/cilium-chaining -n kube-system
```

Note:

* You need to make sure that your node's kernel version is at least greater than **_4.19_**.
* Your cluster should be an _**underlay**_ cluster, and do **_not install_** cilium.

You will see cilium-chaining pod is running in your cluster:

```shell
kubectl  get po -n kube-system | grep cilium-chaining
cilium-chaining-24fsl                    1/1     Running     0              55s
cilium-chaining-hsct6                    1/1     Running     0              54s
```

## Build

You can use the following command to build test image on your local:

```shell
make image
```

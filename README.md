# Cilium-chaining

Cilium-chaining is a project based on [cilium](https://github.com/cilium/cilium), It runs in cni-chaining-mode and works primarily with IPvlan. It can provide some the following capabilities:

- Kubernetes network policy
- Observability
- Kube-proxy replacement
- Accelerated access to the Service
- ...

This project is inspired by [terway](https://github.com/AliyunContainerService/terway), Thanks for the great works 👍.

## How to install it

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

* You need to make sure that your node's kernel version is at least greater than 4.19.
* Your cluster should be an _**underlay**_ cluster, and do **_not install_** cilium.

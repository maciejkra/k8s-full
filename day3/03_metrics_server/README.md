# Metrics server
https://github.com/kubernetes-sigs/metrics-server

```sh
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
```

kubectl edit deployment metrics-server -n kube-system

```yml
    command:
    - /metrics-server 
    - --kubelet-preferred-address-types=InternalIP
    - --kubelet-insecure-tls
    - --secure-port=4443
    - --cert-dir=/tmp
```

# Minikube

```sh
minikube addons list
minikube addons enable metrics-server
```


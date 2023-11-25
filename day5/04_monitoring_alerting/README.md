## Install prometheus operator

```sh
kind create cluster --config ./kind.yaml --name workshop

helm upgrade --install --wait --timeout 15m \
  --namespace monitoring --create-namespace \
  --repo https://prometheus-community.github.io/helm-charts \
  kube-prometheus-stack kube-prometheus-stack --set kubeEtcd.service.targetPort=2381
```

Set up port-forward to graphana and log in

`admin`:`prom-operator`

## Install Loki via Helm
Lunch Loki:
```sh
helm upgrade --install loki grafana/loki-stack --namespace=loki --create-namespace
```

Add Loki data source under `http://loki.loki.svc.cluster.local:3100`
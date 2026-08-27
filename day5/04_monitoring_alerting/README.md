## Install prometheus operator

```sh
kind create cluster --config ./kind.yaml --name workshop

helm upgrade --install --wait --timeout 15m \
  --namespace monitoring --create-namespace \
  --repo https://prometheus-community.github.io/helm-charts \
  kube-prometheus-stack kube-prometheus-stack -f values.yaml
```

Set up port-forward to Grafana i zaloguj się jako `admin`. Hasło jest **generowane
losowo** przy instalacji (chart nie używa już `prom-operator`):

```sh
kubectl get secret -n monitoring kube-prometheus-stack-grafana \
  -o jsonpath='{.data.admin-password}' | base64 -d ; echo
```

## Install Loki + Alloy via Helm

```sh
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

# backend
helm upgrade --install loki grafana/loki \
  --namespace loki --create-namespace -f loki-values.yaml --timeout 10m

# kolektor logów
helm upgrade --install alloy grafana/alloy \
  --namespace alloy --create-namespace -f alloy-values.yaml
```

```sh
kubectl -n loki get pods    # loki-0 2/2, loki-gateway 1/1
kubectl -n alloy get pods   # po jednym Podzie na worker, 2/2
```

Dodaj w Grafanie data source typu **Loki** pod adresem:

```
http://loki-gateway.loki.svc.cluster.local/
```

Sprawdź w Grafanie → Explore → Loki, np. `{namespace="kube-system"}`.

## Linki
- [Loki Helm chart](https://grafana.com/docs/loki/latest/setup/install/helm/)
- [Grafana Alloy](https://grafana.com/docs/alloy/latest/)

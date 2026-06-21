# Zadanie — Canary (weighted routing 70:30)

Wymaga Gateway API z D2/07 (`training-gateway`, `Programmed=True`) oraz aplikacji python-api z D1/11.

Cel: rozłożyć ruch przez jeden `HTTPRoute` z `backendRefs[].weight` — **70% na python-api, 30% na nginx**.

## Część 1 — dwa backendy

1. Upewnij się, że python-api z D1/11 działa (Service `python-service`).
2. Wdróż drugi backend — nginx:
   ```sh
   kubectl apply -f solution/nginx.yaml
   ```

## Część 2 — weighted HTTPRoute 70/30

Napisz `HTTPRoute` na `training-gateway` z dwoma `backendRefs`: `python-service:80` (weight 70) i `nginx:80` (weight 30). Gotowiec: `solution/httproute-canary.yaml`.

```sh
kubectl apply -f solution/httproute-canary.yaml
kubectl describe httproute canary-demo   # Accepted=True, ResolvedRefs=True
```

## Część 3 — test rozkładu

```sh
for i in $(seq 1 100); do
  curl -s canary.127-0-0-1.nip.io/ | grep -qi nginx && echo nginx || echo python
done | sort | uniq -c
# ~70 python, ~30 nginx (±5%)
```

## Część 4 — przesuwanie ruchu

Zmień weighty (np. 50/50, potem 0/100), re-apply i ponów pomiar — zmiana jest natychmiastowa, bez restartu Podów:
```sh
kubectl patch httproute canary-demo --type=json -p='[
  {"op":"replace","path":"/spec/rules/0/backendRefs/0/weight","value":50},
  {"op":"replace","path":"/spec/rules/0/backendRefs/1/weight","value":50}
]'
```

W produkcji po każdym kroku: pauza na monitoring (error rate, latency p99); jeśli SLO spada → rollback (przywróć weight).

# Solution — 05_Canary

## Architektura

```
       Client
         │  curl canary.127-0-0-1.nip.io
         ▼
   [Envoy Gateway]  (D2/07 training-gateway)
         │
         ▼
   [HTTPRoute canary-demo]  ← weighted routing 70/30
         ├──70%──→ Service python-service ──→ python-api (D1/11)
         └──30%──→ Service nginx ──────────→ nginx
```

## Pliki
- `nginx.yaml` — Deployment + Service nginx (drugi backend, 30%)
- `httproute-canary.yaml` — HTTPRoute z `backendRefs[].weight` 70 (python) / 30 (nginx)
- python-api (70%) pochodzi z D1/11 (Service `python-service`)

Weighted HTTPRoute vs stary wzorzec (ratio replik na wspólnym Service):

| | Stare (ratio replik) | Weighted HTTPRoute |
|---|---|---|
| Sterowanie ratio | `replicas` (1% = 100 Podów) | `weight` (dowolna %) |
| Koszt zmiany | skalowanie Podów | update manifestu, Envoy ~1s, bez restartu |
| Osobna konfiguracja backendów | trudna (wspólny Service) | łatwa (osobne Service) |
| Routing po header/cookie | niemożliwy | `matches.headers` w regule |

## Apply

```sh
# Gateway training-gateway z D2/07 musi istnieć i być Programmed; python-api z D1/11 działa
kubectl apply -f nginx.yaml
kubectl apply -f httproute-canary.yaml
sleep 5   # Envoy program config
```

## Walidacja

```sh
for i in $(seq 1 100); do
  curl -s canary.127-0-0-1.nip.io/ | grep -qi nginx && echo nginx || echo python
done | sort | uniq -c
# ~70 python, ~30 nginx (±5%)
```

## Przesuwanie ruchu

```sh
# 50/50
kubectl patch httproute canary-demo --type=json -p='[
  {"op":"replace","path":"/spec/rules/0/backendRefs/0/weight","value":50},
  {"op":"replace","path":"/spec/rules/0/backendRefs/1/weight","value":50}
]'

# 100% nginx
kubectl patch httproute canary-demo --type=json -p='[
  {"op":"replace","path":"/spec/rules/0/backendRefs/0/weight","value":0},
  {"op":"replace","path":"/spec/rules/0/backendRefs/1/weight","value":100}
]'
```

W produkcji **Argo Rollouts** / **Flagger** robią to automatycznie — monitorują SLO (error rate, latency) między krokami i rolllują wstecz przy przekroczeniu progu.

## Header-based routing (preview)

Tylko ruch z nagłówkiem `x-canary-tester: true` → nginx, reszta → python:

```yaml
rules:
  - matches:
      - headers:
          - name: x-canary-tester
            value: "true"
    backendRefs:
      - name: nginx
        port: 80
  - matches:
      - path: { type: PathPrefix, value: / }
    backendRefs:
      - name: python-service
        port: 80
```

```sh
curl -H "x-canary-tester: true" canary.127-0-0-1.nip.io/   # zawsze nginx
curl canary.127-0-0-1.nip.io/                              # zawsze python
```

# Zadanie — Canary (weighted routing 70:30)

Rozłóż ruch przez jeden `HTTPRoute` z `backendRefs[].weight` — **70% na python-api, 30% na nginx**.
Wymaga `training-gateway` z D2/07 (`Programmed=True`) i python-api z D1/11.

1. Wdróż drugi backend — nginx: `kubectl apply -f solution/nginx.yaml`.
2. Napisz `HTTPRoute` na `training-gateway` (host `canary.127-0-0-1.nip.io`) z dwoma
   `backendRefs`: `python-service:80` z wagą 70 i `nginx:80` z wagą 30.
   Gotowiec: `solution/httproute-canary.yaml`.
3. Zmierz rozkład:
   ```sh
   for i in $(seq 1 100); do
     curl -s canary.127-0-0-1.nip.io/ | grep -qi nginx && echo nginx || echo python
   done | sort | uniq -c
   # ~70 python, ~30 nginx (±5%)
   ```
4. Przesuń ruch na 50/50, potem 0/100 (`kubectl patch` albo edycja i re-apply) i ponów pomiar.
   Sprawdź `RESTARTS` w `kubectl get pods` — dlaczego się nie zmieniły?

> Zadanie jest niezależne od demo z `canary-demo/` — inna nazwa HTTPRoute (`canary-task`)
> i inny hostname, więc oba mogą stać w klastrze naraz.

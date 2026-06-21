# Zadanie

Wymień Redis Deployment (z D1/11 Python+Redis) na Redis StatefulSet z dedykowanym storage przez `volumeClaimTemplates` (mount `/data`, AOF persistence).

## Kroki

1. Cleanup starego Redis z D1/11:
   ```bash
   kubectl delete deployment redis
   kubectl delete service redis-service 2>/dev/null || true
   ```

2. Wdróż `redis.statefulset.yaml` — Pod powinien nazywać się `redis-0` (nie losowy hash):
   ```bash
   kubectl apply -f redis.statefulset.yaml
   kubectl get pod -l app=redis
   # redis-0    1/1   Running
   ```

3. Zweryfikuj, że Python (z D1/11) nadal się łączy:
   ```bash
   kubectl logs deploy/python --tail=20
   # brak errorów connection refused
   ```

4. Wykonaj kilka `POST` na `/api/v1/info` (licznik), potem `kubectl delete pod redis-0`. Po odtworzeniu Poda licznik przetrwa — dzięki AOF + PVC.

5. Skala-up do 3 replik — obserwuj sekwencyjne powstawanie Podów:
   ```bash
   kubectl scale sts/redis --replicas=3
   kubectl get pods -l app=redis -w
   ```

6. Wypisz PVC po skalowaniu (`kubectl get pvc`). Przy `kubectl scale --replicas=1` PVC pozostają (default `Retain`).

## Bazowe demo (pierwszy StatefulSet)

`nginx.statefulset.yaml` to prostszy przykład — repliki nginx z dedykowanym storage per Pod. Różnice vs Deployment:
- Pody startują sekwencyjnie (`nginx-0` → Ready → `nginx-1` → …)
- Pod ma stałe imię (po `delete pod` wraca z tym samym numerem)
- Z innego Poda: `curl nginx-1.<headless-service>` — DNS per Pod
- `kubectl scale --replicas=N` usuwa Pod z najwyższym ordinal

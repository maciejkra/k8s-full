# Zadanie

Przepisz Redisa z D1/11 z `Deployment` na `StatefulSet`.

1. Skasuj `Deployment` redis z D1/11. Service zostaw — python ma się dalej łączyć bez zmian.
2. Napisz `StatefulSet` redis: obraz `redis:alpine`, te same labelki co w selektorze Service'u
   redisa, storage per Pod przez `volumeClaimTemplates` zamontowany w `/data`.
3. Sprawdź, że Pod nazywa się `redis-0` (nie losowy hash) i że python nadal działa:
   ```sh
   kubectl get pod -l app=redis
   curl <ip>:<port>/api/v1/info
   ```
4. Zrób kilka `POST` na `/api/v1/info`, skasuj Poda (`kubectl delete pod redis-0`)
   i sprawdź licznik po jego powrocie.

Rozwiązanie: `solution/redis.statefulset.yaml`.

EXTRA:
* Przeskaluj do 3 replik i zobacz, w jakiej kolejności powstają Pody.
* Zejdź z powrotem do 1 repliki — co się stało z PVC?

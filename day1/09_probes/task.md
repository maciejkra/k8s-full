# Zadanie

Dodaj `readiness` i `liveness` probe do Pod-a python:

1. `readiness` — sprawdza port TCP.
2. `liveness` — sprawdza endpoint `/healthz` przez HTTP.
3. Po poprawnej konfiguracji aplikacja powinna restartować się co ~30 sekund i przez cały czas pozostawać `Ready`.
4. Sprawdź events w `describe pod` — jakie wpisy się pojawiły?

```sh
kubectl describe pods <podname>
```

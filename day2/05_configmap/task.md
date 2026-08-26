# Zadanie

Aplikacja python z D1/11 ma konfigurację wpisaną na sztywno w `env` deploymentu.
Przenieś ją do ConfigMap — trzy wartości: `REDIS_HOST`, `REDIS_PORT`, `LOG_LEVEL`.

1. Utwórz ConfigMap `python-config` z tymi trzema kluczami (`REDIS_HOST` — nazwa Service
   redisa z D1/11, `REDIS_PORT` — `6379`, `LOG_LEVEL` — `DEBUG`).
2. Usuń `env` z deploymentu python i podepnij ConfigMap przez `envFrom`.
3. Sprawdź — aplikacja wypisuje wszystkie trzy w logach przy starcie:
   ```sh
   kubectl logs deploy/python | head -5
   # LOG_LEVEL has value DEBUG
   # REDIS_HOST has value ...
   # REDIS_PORT has value 6379
   ```
4. Zmień `LOG_LEVEL` na `INFO` w ConfigMap. Czy Pod zobaczy zmianę bez restartu?

## Linki
- [ConfigMap docs](https://kubernetes.io/docs/concepts/configuration/configmap/)
- [Reloader](https://github.com/stakater/Reloader)

# Zadanie

ConfigMap = key-value store K8s dla nie-sekretnej konfiguracji. Dwa sposoby konsumpcji w Pod: env vars (statyczne) i volume mount (auto-refresh ~60s).

## Część 1 — utwórz ConfigMapy (z katalogu `creation/`)

```sh
cd creation
kubectl create configmap configuration --from-file=./
kubectl create configmap fromenv --from-env-file=env-file-example
kubectl get configmap/configuration -o yaml
cd ..
```

1. Sprawdź, że każdy plik z `creation/` trafił jako osobny `data.<filename>` key w `configuration`.
2. Sprawdź `fromenv` — każda linia `KEY=VALUE` z `env-file-example` to osobny key.

## Część 2 — ConfigMap jako env vars

```sh
kubectl apply -f pod-config.yaml
kubectl logs configmap-pod
kubectl logs configmap-pod | grep line
```

1. Pod `configmap-pod` bierze `SERVICE_B` przez `configMapKeyRef` (key `service.json`) oraz wszystkie klucze z `fromenv` przez `envFrom`.
2. Potwierdź, że `line=2` z `fromenv` widać w env.

## Część 3 — ConfigMap zamontowany jako pliki

```sh
kubectl apply -f pod-config-volume.yaml
kubectl logs configmap-volume-pod
```

1. Pod co 5s wypisuje `/etc/config/service-b.config` (zamontowany z `configuration`).

## Część 4 — auto-update zamontowanego ConfigMap

```sh
kubectl edit configmap configuration
# zmień wartość service-b.config
kubectl logs -f configmap-volume-pod
```

1. Poczekaj ~60s i obserwuj, że plik w mountcie zmienił się BEZ restartu Pod-a.

## Bonus — sposoby tworzenia ConfigMap

```sh
kubectl create configmap test-config --from-file=s.json=service.json
kubectl get configmap/test-config -o yaml
```

Custom key (`s.json`) wskazujący na jeden plik. Pełny przegląd metod tworzenia: `creation/README.md`.

## Zadanie własne — ConfigMap dla aplikacji python (D1/11)

Aplikacja python z D1/11 ma konfigurację wpisaną na sztywno w `env` deploymentu (`REDIS_HOST`, `LOG_LEVEL`). Przenieś ją do ConfigMap.

1. Utwórz ConfigMap z konfiguracją aplikacji:
   ```sh
   kubectl create configmap python-config \
     --from-literal=REDIS_HOST=redis-service \
     --from-literal=LOG_LEVEL=INFO
   ```
2. Zmień deployment python tak, by brał te wartości z ConfigMap zamiast z literałów `env` — przez `envFrom`:
   ```yaml
   envFrom:
     - configMapRef:
         name: python-config
   ```
3. Zaaplikuj i potwierdź, że Pod widzi zmienne z ConfigMap:
   ```sh
   kubectl rollout status deploy/python
   kubectl exec deploy/python -- printenv REDIS_HOST LOG_LEVEL
   ```
4. Zmień `LOG_LEVEL` w ConfigMap na `DEBUG`. Czy `envFrom` zaktualizuje się bez restartu Poda? (Nie — env to snapshot; wymagany rollout restart.)

## Linki
- [ConfigMap docs](https://kubernetes.io/docs/concepts/configuration/configmap/)
- [Configure a Pod to Use a ConfigMap](https://kubernetes.io/docs/tasks/configure-pod-container/configure-pod-configmap/)
- [Reloader](https://github.com/stakater/Reloader)

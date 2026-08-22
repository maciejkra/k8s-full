# Zadanie

Wystaw aplikację python-api (z D1/11) przez Gateway API pod adresem `api.127-0-0-1.nip.io`.

Prereq: Envoy Gateway zainstalowany dla Twojego runtime — patrz `README.md` → „Setup Envoy Gateway".

1. Upewnij się, że istnieje Gateway z listenerem HTTP:80:
   ```sh
   kubectl apply -f gateway-http.yaml
   kubectl wait --for=condition=Programmed gateway/training-gateway --timeout=2m
   ```
2. Napisz `HTTPRoute`, który dla hosta `api.127-0-0-1.nip.io` kieruje **cały** ruch
   (każda ścieżka) na Service `python-service` (port **80** — Service port, nie containerPort 5002).
3. Zaaplikuj i przetestuj:
   ```sh
   kubectl apply -f <twoj-httproute>.yaml
   kubectl describe httproute <nazwa>   # Accepted=True, ResolvedRefs=True
   curl http://api.127-0-0-1.nip.io/api/v1/info
   ```

## Zadanie z gwiazdką

Dodaj do swojego HTTPRoute filter, tak aby **każda** ścieżka (cokolwiek wpiszesz) była zawsze przepisywana na `/api/v1/info`:

```sh
curl http://api.127-0-0-1.nip.io/             # → odpowiedź z /api/v1/info
curl http://api.127-0-0-1.nip.io/cokolwiek    # → to samo
curl http://api.127-0-0-1.nip.io/foo/bar/baz  # → to samo
```

Podpowiedź: filter `URLRewrite` z `path.type: ReplaceFullPath` (nie `ReplacePrefixMatch` — ten zostawia resztę ścieżki):
```yaml
filters:
  - type: URLRewrite
    urlRewrite:
      path:
        type: ReplaceFullPath
        replaceFullPath: /api/v1/info
```

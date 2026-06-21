# Solution — 04_vault

## Trzy wzorce — kiedy który
- CSI volume — aplikacja czyta secret z pliku (`/mnt/secrets-store/db-password`); rotacja odświeża plik bez restartu.
- CSI + sync do K8s Secret — legacy aplikacja czyta env (`DB_PASSWORD` przez `secretKeyRef`).
- Agent Injector — sidecar renderuje plik z template (`/vault/secrets/database-config.txt`); najbardziej elastyczny, dokłada init + sidecar.

## CSI vs Injector — rotacja
- CSI volume odświeża plik okresowo, bez restartu Poda.
- Env z synca do Secret nie zmieni się w procesie bez restartu Poda.
- Injector odnawia lease w sidecarze i re-renderuje plik.

## `bound_service_account_namespaces`
- SA są per-namespace, więc role wiąże się z parą (nazwa SA, namespace). Sam `bound_service_account_names` byłby wyciekiem multi-tenant.

## Walidacja
```sh
kubectl -n vault get pods
kubectl exec webapp -- cat /mnt/secrets-store/db-password
kubectl exec webapp-env -- sh -c 'echo $DB_PASSWORD'
kubectl exec webapp-inject -c webapp -- cat /vault/secrets/database-config.txt
```

## Wyjaśnienia
- KV v2 dodaje prefiks `data/` — policy i `secretPath` używają `secret/data/db-pass`, nie `secret/db-pass`.

## Cross-link
- 02_psa_security — Vault w dev mode nie spełnia `enforce: restricted`; dla prod hardenuj values.
- 03_Admission_Controllers — Injector działa przez MutatingWebhook.

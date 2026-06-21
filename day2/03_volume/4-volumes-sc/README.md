# 4 — StorageClass (dynamic provisioning)

## Cel
Użyć StorageClass do dynamicznego tworzenia PV — bez ręcznego pre-provisioningu.

## Prereqs
- Działający cluster (k3d/kind)

## Uruchomienie
```sh
kubectl get sc
kubectl apply -f sc.yaml
kubectl apply -f pvc.yaml
kubectl get pvc
kubectl get pv
```

Szczegóły i wyjaśnienia: zobacz `../task.md` i `../solution.md`.

## Linki
- [Storage Classes](https://kubernetes.io/docs/concepts/storage/storage-classes/)
- [Dynamic Volume Provisioning](https://kubernetes.io/docs/concepts/storage/dynamic-provisioning/)

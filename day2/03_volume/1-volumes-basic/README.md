# 1 — Basic Volumes: emptyDir, hostPath, subPath

## Cel
Poznać najprostsze typy volumes: tymczasowy `emptyDir`, node-local `hostPath` oraz `subPath` do montażu pojedynczego pliku.

## Prereqs
- Działający cluster (k3d/kind)

## Uruchomienie
```sh
kubectl apply -f empty-dir-pod.yaml
kubectl apply -f host-path-pod.yaml
kubectl apply -f sub-path-overwrite-pod.yaml
kubectl apply -f sub-path-wo-overwrite-pod.yaml
```

Szczegóły i wyjaśnienia: zobacz `../task.md` i `../solution.md`.

## Linki
- [Volumes — emptyDir](https://kubernetes.io/docs/concepts/storage/volumes/#emptydir)
- [Volumes — hostPath](https://kubernetes.io/docs/concepts/storage/volumes/#hostpath)
- [Using subPath](https://kubernetes.io/docs/concepts/storage/volumes/#using-subpath)

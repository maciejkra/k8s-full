```sh
kubectl create configmap configuration --from-file=./
kubectl get configmap/configuration -o yaml
```

# From env file
```sh
kubectl create configmap fromenv --from-env-file=env-file-example
kubectl get configmap/fromenv -o json
kubectl get configmap/fromenv -o yaml
```
# Data as file

```sh
kubectl create configmap test-config --from-file=<my-key-name>=<path-to-file>
kubectl create configmap test-config --from-file=s.json=service.json
kubectl get configmap/test-config -o yaml
```


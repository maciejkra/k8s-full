## Prirority Class
```sh
kubectl apply -f priorityclass.yaml
kubectl apply -f nginx-deploy.yaml
kubectl apply -f nginx-deploy-prio.yaml
```

Some pods should be pending.
Uncomment files in `nginx-deploy-prio.yaml`
```sh
kubectl apply -f nginx-deploy-prio.yaml
```

Check what happened
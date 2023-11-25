```sh
kubectl apply -f redis.yaml
kubectl apply -f producer.job.yaml
kubectl apply -f parallel.job.yaml
kubectl get job
kubectl logs -f -l type=consumer
```

## Useful Links

https://kubernetes.io/docs/concepts/workloads/controllers/job/
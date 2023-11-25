## Limit by default


```sh
kubectl create ns test-1
kubectl apply -f ns-quota.yaml
kubectl apply -f deployment.yaml -n test-1
kubectl scale deployment -n test-1 nginx-readiness --replicas=3
kubectl -n test-1 describe deploy nginx-readines
kubectl -n test-1 describe rs $(kubectl -n test-1 get rs -o jsonpath='{.items[0].metadata.name}')
```

## Resource quotas

https://kubernetes.io/docs/concepts/policy/resource-quotas/



https://kubernetes.io/docs/concepts/scheduling-eviction/kube-scheduler/
https://kubernetes.io/docs/reference/scheduling/config/#profiles
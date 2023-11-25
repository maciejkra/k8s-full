## Limit by default

https://kubernetes.io/docs/concepts/policy/limit-range/

```sh
kubectl create ns ns-limit
kubectl apply -f limitrange.yaml -n ns-limit
kubectl describe limitrange cpu-resource-constraint -n ns-limit
kubectl apply -f pod.yaml -n ns-limit
```
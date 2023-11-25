# Labels


```sh
kubectl get pods -A --show-labels
kubectl get pods -l environment=production,tier=frontend
kubectl get pods -A -l 'tier in(control-plane)'
kubectl get pods -A -l 'tier in(control-plane),component notin(kube-scheduler)'

kubectl label pod/myapp-pod test-label=my-label
kubectl get pods -l test-label=my-label
kubectl get pods -l 'test-label in (my-label)'
```

Guidlines: https://kubernetes.io/docs/concepts/overview/working-with-objects/common-labels/


# Resources for set based selectors
- Job
- Deployment
- ReplicaSet
- DaemonSet
- StatefullSet

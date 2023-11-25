https://kubernetes.io/docs/tasks/administer-cluster/safely-drain-node/

```sh
kubectl drain --ignore-daemonsets <node name> #to drain the node

kubectl uncordon <node name> #to restore it
```

## Useful Links
[kubepug](https://github.com/kubepug/kubepug)
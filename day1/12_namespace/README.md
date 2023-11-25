```sh
kubectl get namespaces
kubectl create namespace workshops
kubectl apply -f . -n <?>
```

1. Create python-app deployment in this namespace
2. Find all object in this namespace

## Check this links

```sh
kubectl config set-context --current --namespace=<insert-namespace-name-here>
```
But maybe there is an easier way?
[Kubems/buectx](https://github.com/ahmetb/kubectx)

Make life easier:
* [Powershell 10k for zsh](https://github.com/romkatv/powerlevel10k)
* [kube-ps1](https://github.com/jonmosco/kube-ps1)

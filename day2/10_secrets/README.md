```sh
kubectl create secret generic my-secret --from-file=./my-secrets --from-literal=user=maciek
kubectl get secret my-secret -o yaml
```
* https://kubernetes.io/docs/concepts/configuration/secret/
* https://kubernetes.io/docs/tasks/inject-data-application/distribute-credentials-secure/#define-container-environment-variables-using-secret-data
* https://kubernetes.io/docs/tasks/configure-pod-container/pull-image-private-registry/

# Worth Checking
* https://www.vaultproject.io
* https://learn.hashicorp.com/tutorials/vault/agent-kubernetes?in=vault/kubernetes

Alternatives to vault apporach:
* https://github.com/getsops/sops
* https://github.com/bitnami-labs/sealed-secrets
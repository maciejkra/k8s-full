## Secrets from helm

```sh
helm repo add hashicorp https://helm.releases.hashicorp.com

helm upgrade --install vault hashicorp/vault --version 0.24.1 \
--create-namespace -n vault \
-f vault-values.yaml
```

Install CSI controller

```sh
helm repo add secrets-store-csi-driver https://kubernetes-sigs.github.io/secrets-store-csi-driver/charts

helm upgrade --install csi-secrets-store \
secrets-store-csi-driver/secrets-store-csi-driver \
-n kube-system --set syncSecret.enabled=true
```

Turn on k8s engine in vault (enter the pod)
```sh
kubectl exec -it -n vault vault-0 -- sh


vault auth enable kubernetes

vault write auth/kubernetes/config \
kubernetes_host="https://$KUBERNETES_PORT_443_TCP_ADDR:443"
```

Set up policy to access via password
```sh
vault policy write internal-app - <<EOF
path "secret/data/db-pass" {
capabilities = ["read"]
}
EOF
```

Create role that connects policy with service account

```sh
vault write auth/kubernetes/role/database \
bound_service_account_names=app-sa \
bound_service_account_namespaces=default \
policies=internal-app \
ttl=20m

exit
```

```sh
kubectl port-forward -n vault vault-0 8200
```
Create secret called `db-pass` and create key `password`
http://127.0.0.1:8200 (login `root`)

### Secrets as values using CSI

```sh
kubectl apply -f csisecret.yaml 
kubectl apply -f csi-pod.yaml
```
Enter the new pod and check password.

Check if there are any secrets

### Secrets as envs using CSI
```sh
kubectl apply -f csisecret-env.yaml 
kubectl apply -f csi-pod-env.yaml
```
Enter the new pod and check password.
Check if there are any secrets.
Check what happens after you delete the secret.

### Secrets as envs using inject (classic)
```sh
kubectl apply -f inject-pod.yaml
```
Enter the new pod and check this path `/vault/secrets/database-config.txt`

# Alternatives to vault apporach:
* https://github.com/getsops/sops
* https://github.com/bitnami-labs/sealed-secrets
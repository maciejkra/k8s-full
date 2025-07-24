# Install 3 CP + 3 worker nodes + LB

prepare the nodes and lunch `preapre.sh` on each of them - it will prepare the nodes for installation

## Prepare the first CP node
Log in on to the node (ssh)

Add virtual IP for kube-vip
```sh
ip a a dev eth1 10.135.0.100/24
```

Copy files in `kubernetes` dir into `/etc/kubernetes`

Change the hostname
```sh
sudo hostnamectl set-hostname "cpnode1"
```
Modify `/etc/hosts` accordingly (add to the file)
```sh
10.135.0.5 cpnode1.example.com cpnode1
10.135.0.6 cpnode2.example.com cpnode2
10.135.0.3 cpnode3.example.com cpnode3
10.135.0.4 knode1.example.com knode1
10.135.0.2 knode2.example.com knode2
10.135.0.7 knode3.example.com knode3
10.135.0.100 kubeapi.example.com kubeapi
```


Modify the `kubeadm-config.yaml` file according to comments, especially:
* advertiseAddress (add the interface ip)
* certSANs (add the interface and virtual ip addresses)

Install kubernetes components
```sh
kubeadm init --config ./kubeadm-config.yaml --upload-certs
```

**Save the output `kubeadm join` commands**

Install Network driver - Cilium
https://docs.cilium.io/en/stable/gettingstarted/k8s-install-default/

```sh
CILIUM_CLI_VERSION=$(curl -s https://raw.githubusercontent.com/cilium/cilium-cli/main/stable.txt)
CLI_ARCH=amd64
if [ "$(uname -m)" = "aarch64" ]; then CLI_ARCH=arm64; fi
curl -L --fail --remote-name-all https://github.com/cilium/cilium-cli/releases/download/${CILIUM_CLI_VERSION}/cilium-linux-${CLI_ARCH}.tar.gz{,.sha256sum}
sha256sum --check cilium-linux-${CLI_ARCH}.tar.gz.sha256sum
sudo tar xzvfC cilium-linux-${CLI_ARCH}.tar.gz /usr/local/bin
rm cilium-linux-${CLI_ARCH}.tar.gz{,.sha256sum}


export KUBECONFIG=/etc/kubernetes/admin.conf
cilium install --version 1.17.6
```

## Join other CP nodes
Log in on to the node (ssh)

Copy files in `kubernetes` dir into `/etc/kubernetes`

Change the hostname
```sh
sudo hostnamectl set-hostname "<nodename>"
```
Modify `/etc/hosts` accordingly (add to the file)
```sh
10.135.0.5 cpnode1.example.com cpnode1
10.135.0.6 cpnode2.example.com cpnode2
10.135.0.3 cpnode3.example.com cpnode3
10.135.0.4 knode1.example.com knode1
10.135.0.2 knode2.example.com knode2
10.135.0.7 knode3.example.com knode3
10.135.0.100 kubeapi.example.com kubeapi
```
Run `kubeadm join` command you got from the first node
```sh
kubeadm join kubeapi.example.com:6443 --token 7kwnu1.zmop3tuysdmdwrhv \
	--discovery-token-ca-cert-hash sha256:a30106570559692815bfdd008026ac0a36a91f4f997a1b563cd0995a49693dd8 \
	--control-plane --certificate-key ead587109844cced6cdbda7743c080571e370f6061be3a7d08753f9185deee07
```

## Join worker nodes
Log in on to the node (ssh)


Change the hostname
```sh
sudo hostnamectl set-hostname "<nodename>"
```
Modify `/etc/hosts` accordingly (add to the file)
```sh
10.135.0.5 cpnode1.example.com cpnode1
10.135.0.6 cpnode2.example.com cpnode2
10.135.0.3 cpnode3.example.com cpnode3
10.135.0.4 knode1.example.com knode1
10.135.0.2 knode2.example.com knode2
10.135.0.7 knode3.example.com knode3
10.135.0.100 kubeapi.example.com kubeapi
```
Run `kubeadm join` command **for worker** you got from the first node
```sh
kubeadm join kubeapi.example.com:6443 --token eiicj4.9ybifdjxw6bcn6g7 \
	--discovery-token-ca-cert-hash sha256:e8ad7cccfb8fe12c81db99b1e94e0d40ef83494b5064796043fdef476b801d90
```

## Install kube-vip
https://kube-vip.io

Remove virtual IP for kube-vip
```sh
ip a d dev eth1 10.135.0.100/24
```

On one control-plane node run `kube-vip.sh` script (edit first `VIP_IF` & `VIP_IP`).

Have FUN!

## More fun....

```sh
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update

helm install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx --create-namespace \
  --set controller.kind=DaemonSet \
  --set controller.daemonset.useHostPort=true \
  --set controller.hostNetwork=true \
  --set controller.service.type="" \
  --set controller.service.enabled=false \
  --set controller.admissionWebhooks.enabled=false \
  --set controller.extraArgs.enable-ssl-passthrough="" \
  --set controller.nodeSelector."node-role\.kubernetes\.io/control-plane"="" \
  --set controller.tolerations\[0\].key="node-role.kubernetes.io/control-plane" \
  --set controller.tolerations\[0\].operator="Exists" \
  --set controller.tolerations\[0\].effect="NoSchedule"
```


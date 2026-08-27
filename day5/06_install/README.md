# Install 3 CP + 3 worker nodes + LB

prepare the nodes and lunch `preapre.sh` on each of them - it will prepare the nodes for installation

## Prepare the first CP node
Log in on to the node (ssh)

Add virtual IP for kube-vip
```sh
ip a a dev eth1 10.135.0.100/32
```

> Maska **/32** jest istotna. `eth1` ma już `10.135.0.x/16`; adres z maską /24 tworzy
> bardziej szczegółową trasę i cały ruch do `10.135.0.0/24` — w tym peering etcd —
> zaczyna wychodzić ze źródłem `10.135.0.100`, którego nie ma w SAN-ach certyfikatu.
> Join kolejnych CP pada wtedy na `can only promote a learner member...`.
> Sam kube-vip też nadaje ten adres jako /32 (`vip_subnet: "32"` w `kube-vip.sh`).

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
kubeadm init --config ./kubeadm-config.yaml --upload-certs --skip-phases=addon/kube-proxy
```

> `--skip-phases=addon/kube-proxy` — kube-proxy w ogóle nie powstaje, bo jego rolę
> przejmuje Cilium w eBPF (`kubeProxyReplacement=true` niżej). Jest to wymagane przez
> Cilium Gateway API. Bez tej flagi kube-proxy i Cilium instalują konkurencyjne
> reguły dla tego samego ruchu.

**Save the output `kubeadm join` commands**

Zanim pójdziesz dalej — sprawdź, czy IP LoadBalancera jest w certyfikacie apiservera:
```sh
openssl x509 -in /etc/kubernetes/pki/apiserver.crt -noout -ext subjectAltName \
  | grep -q "$(grep kubeapi /etc/hosts | awk '{print $1}')" && echo OK || echo "BRAK IP LB W CERCIE"
```
Jeśli wyjdzie `BRAK`, dopisz to IP do `certSANs` i odtwórz certyfikat, zanim ruszysz dalej:
```sh
rm /etc/kubernetes/pki/apiserver.{crt,key}
kubeadm init phase certs apiserver --config ./kubeadm-config.yaml
mv /etc/kubernetes/manifests/kube-apiserver.yaml /root/ && sleep 15 \
  && mv /root/kube-apiserver.yaml /etc/kubernetes/manifests/
```
Popraw też `certSANs` w ConfigMapie `kube-system/kubeadm-config` — to z niego kolejne CP
biorą listę przy `kubeadm join`. Bez tego kroku instalacja Cilium stanie na `Init:0/6`.

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
```

Gateway API to osobne CRD-y — Cilium ich nie wozi, trzeba je zainstalować przed nim:
```sh
GW=https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/v1.6.1/config/crd/standard
for crd in gatewayclasses gateways httproutes referencegrants grpcroutes backendtlspolicies tlsroutes; do
  kubectl apply --server-side -f $GW/gateway.networking.k8s.io_$crd.yaml
done
```

Instalacja Cilium z kube-proxy replacement i Gateway API:
```sh
cilium install --version 1.20.1 \
  --set kubeProxyReplacement=true \
  --set k8sServiceHost=<IP-LoadBalancera-DO> \
  --set k8sServicePort=6443 \
  --set gatewayAPI.enabled=true \
  --set gatewayAPI.hostNetwork.enabled=true \
  --set envoy.securityContext.capabilities.keepCapNetBindService=true \
  --set envoy.securityContext.capabilities.envoy="{NET_ADMIN,SYS_ADMIN,NET_BIND_SERVICE}"

cilium status --wait
```

> `k8sServiceHost`/`k8sServicePort` — bez kube-proxy Cilium musi sam wiedzieć, jak dobić
> do apiservera. Podaj IP LoadBalancera (nie nazwę `kubeapi.example.com` — Pody Cilium nie
> korzystają z `/etc/hosts` node'a).
> `gatewayAPI.hostNetwork.enabled=true` — L7 proxy wystawia się wprost na sieci hosta,
> więc Gateway nie potrzebuje Service'u `LoadBalancer` (a taki na kubeadm bez
> cloud-controller-managera zostałby `<pending>`). DO LB forwarduje `:80/:443` na CP node'y
> i trafia prosto w to proxy.
>
> Dwie ostatnie flagi są **konieczne**: bez `NET_BIND_SERVICE` cilium-envoy nie zbinduje
> portu <1024, Gateway pokazuje `PROGRAMMED=True`, a ruch dostaje connection refused.
> Szczegóły objawu: `solution.md`.

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
Run `kubeadm join` command you got from the first node — **add `--apiserver-advertise-address` with this node's PRIVATE ip**
```sh
kubeadm join kubeapi.example.com:6443 --token 7kwnu1.zmop3tuysdmdwrhv \
	--discovery-token-ca-cert-hash sha256:a30106570559692815bfdd008026ac0a36a91f4f997a1b563cd0995a49693dd8 \
	--control-plane --certificate-key ead587109844cced6cdbda7743c080571e370f6061be3a7d08753f9185deee07 \
	--apiserver-advertise-address 10.135.0.6
```

> Bez tej flagi kubeadm bierze adres z interfejsu z domyślną trasą — na DO publiczny.
> etcd peeruje wtedy po publicznym IP, którego nie ma w SAN-ach certyfikatu, learner
> nie synchronizuje się i join pada na `can only promote a learner member...`.
> Wyjście z tego stanu i pełna analiza: `solution.md`.

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
ip a d dev eth1 10.135.0.100/32
```

On one control-plane node run `kube-vip.sh` script (edit first `VIP_IF` & `VIP_IP`).

Have FUN!

## Gateway API (Cilium)

Gateway API obsługuje tutaj **Cilium**, nie osobny kontroler — jest już w klastrze jako CNI,
a `gatewayAPI.hostNetwork.enabled=true` z instalacji wyżej wystawia jego L7 proxy wprost na
sieci hosta. Dzięki temu Gateway nie potrzebuje Service'u `LoadBalancer` (ten na kubeadm bez
cloud-controller-managera zostałby `<pending>`), a DO LB forwarduje `:80/:443` prosto na CP node'y.
To ta sama `GatewayClass cilium`, którą widzieliście na DOKS w D2/07.

```sh
kubectl get gatewayclass        # cilium  io.cilium/gateway-controller  Accepted=True
```

Backend, Gateway i HTTPRoute:
```sh
kubectl create deployment web --image=nginx:1.27-alpine --replicas=2
kubectl expose deployment web --port=80

kubectl apply -f - <<'EOF'
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata: { name: training-gateway, namespace: default }
spec:
  gatewayClassName: cilium
  listeners:
    - { name: http, protocol: HTTP, port: 80, allowedRoutes: { namespaces: { from: All } } }
---
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata: { name: web, namespace: default }
spec:
  parentRefs: [ { name: training-gateway } ]
  rules:
    - backendRefs: [ { name: web, port: 80 } ]
EOF

kubectl wait --for=condition=Programmed gateway/training-gateway --timeout=5m
```

Test z dowolnej maszyny — publiczny IP LoadBalancera DO:
```sh
curl http://<IP-LB>/
# <title>Welcome to nginx!</title>
```

> Dlaczego nie osobny Envoy Gateway: jego data plane musiałby stanąć na tych samych
> node'ach co `cilium-envoy`, a dwa Envoye w sieci hosta biją się o abstrakcyjne gniazdo
> `@envoy_domain_socket_parent_0` (`base_id=0`) — drugi wpada w CrashLoopBackOff
> z `unable to bind domain socket ... errno=98`. Obejście przez `hostPort` też odpada,
> bo Cilium implementuje go dopiero z `kubeProxyReplacement`. Skoro i tak włączamy
> kube-proxy replacement, prościej użyć Gateway API wbudowanego w Cilium.

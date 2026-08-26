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
kubeadm init --config ./kubeadm-config.yaml --upload-certs --skip-phases=addon/kube-proxy
```

> `--skip-phases=addon/kube-proxy` — kube-proxy w ogóle nie powstaje, bo jego rolę
> przejmuje Cilium w eBPF (`kubeProxyReplacement=true` niżej). Jest to wymagane przez
> Cilium Gateway API. Bez tej flagi kube-proxy i Cilium instalują konkurencyjne
> reguły dla tego samego ruchu.

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
> Dwie ostatnie flagi są **konieczne**, żeby listener na porcie 80 w ogóle powstał.
> `cilium-envoy` domyślnie nie ma `NET_BIND_SERVICE`, więc nie zbinduje portu <1024.
> Bez nich Gateway pokazuje `PROGRAMMED=True` i wygląda na sprawny, ale w logach
> `cilium-envoy` leci w kółko:
> `cannot bind '0.0.0.0:80': Permission denied`, a `curl` dostaje connection refused.
> Sam `keepCapNetBindService=true` nie wystarcza — ustawia tylko flagę w `cilium-config`,
> capability trzeba dołożyć do listy `capabilities.envoy`.

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

> **Dlaczego ta flaga jest konieczna.** `kubeadm init` na cpnode1 bierze adres z pola
> `advertiseAddress` w `kubeadm-config.yaml`, czyli PRYWATNY — i taki trafia do SAN-ów
> certyfikatu peer etcd:
> `X509v3 SAN: DNS:cpnode1, DNS:localhost, IP:10.135.0.20, IP:127.0.0.1`
>
> `kubeadm join` nie czyta tego pliku i wybiera adres z interfejsu z **domyślną trasą** —
> na dropletach DO to `eth0`, czyli PUBLICZNY. (Nie zależy to od `/etc/hosts`: nawet gdy
> `kubeapi.example.com` wskazuje na adres prywatny, join i tak wybiera publiczny.)
> Nowy członek etcd startuje więc z `--listen-peer-urls=https://<PUBLICZNY>:2380`.
>
> Skutek: cpnode1 łączy się do niego po publicznym IP, więc jako adres źródłowy ma własny
> publiczny IP — a tego nie ma w jego certyfikacie. Learner odrzuca połączenie:
> `rejected connection on peer endpoint`,
> `tls: "138.68.93.203" does not match any of DNSNames ["cpnode1" "localhost"]`
>
> Ruch raft nigdy nie dochodzi, learner się nie synchronizuje i po ~2 minutach join pada na:
> `etcdserver: can only promote a learner member which is in sync with leader`.
> To nie jest brak łączności — TCP na publiczny `:2380` działa. To niezgodność SAN-ów,
> wynikająca z tego, że jedna strona peeruje prywatnie, a druga publicznie.
>
> Wyjście z tego stanu wymaga usunięcia członka etcd na cpnode1
> (`etcdctl member remove <id>`) i `kubeadm reset -f` na node'zie, który padł —
> sam ponowny `join` nie wystarczy.
>
> Workerów to nie dotyczy: nie dokładają członka etcd, a ich kubelet i tak bierze adres
> prywatny (rozwiązuje nazwę node'a z `/etc/hosts`).

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

## More fun....

> UWAGA: ta instalacja ingress-nginx bierze porty 80/443 na hoście — dokładnie te same,
> na których nasłuchuje L7 proxy Cilium z sekcji Gateway API. Albo jedno, albo drugie,
> nie oba naraz.

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


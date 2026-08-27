# Solution — 06_install

## kube-vip jako DaemonSet
Tu instalujemy kube-vip DaemonSetem (`kube-vip.sh`) i to jest wariant obowiązujący — przetestowany: 3 Pody Running, lease `plndr-cp-lock` na liderze, VIP `/32` na jego `eth1`, `curl -k https://10.135.0.100:6443/healthz` zwraca `ok`.

Klasyczny argument za static podem (`/etc/kubernetes/manifests/kube-vip.yaml`) brzmi: kubelet uruchamia go zanim wstanie apiserver, więc VIP jest gotowy na moment `kubeadm init`, a DaemonSet startuje dopiero po gotowym apiserverze (chicken-and-egg). **W tym setupie to nie ma zastosowania**, bo `controlPlaneEndpoint` celuje w LoadBalancer DigitalOcean, nie w VIP — kubeadm nigdy nie czeka na kube-vip. VIP jest tu elementem dydaktycznym: pokazuje mechanizm HA, którego na DO i tak nie da się użyć jako endpointu, bo VPC blokuje GARP (patrz Troubleshooting).

Gdybyś przenosił ten materiał na bare metal, gdzie VIP JEST endpointem, wtedy static pod jest konieczny — z pułapką, że `kubeadm join --control-plane` nie kopiuje manifestów static podów, więc trzeba je `scp` na każdy nowy CP przed joinem.

## Cilium kube-proxy replacement
- kube-proxy + iptables: dla 1000+ Services = 10k+ rules, liniowe przeszukiwanie, latency ~100µs/packet.
- Cilium eBPF: routing w kernelu O(1) (hash table), latency ~10µs, socket-LB. Plus Hubble L7 observability, NetworkPolicy L7, encryption (WireGuard/IPsec), cluster mesh.

## `--skip-phases=addon/kube-proxy`
Bez flagi kubeadm instaluje kube-proxy; Cilium też instaluje eBPF zamienniki → konflikt (kube-proxy CrashLoopBackOff lub zapętlony Service traffic). Fix: flaga przy init lub `kubectl delete ds/kube-proxy -n kube-system`.

## podSubnet /24 vs /16
K8s dzieli podSubnet na per-node block (default /24/node). `/24` cluster + `/24`/node = 1 node. `/16` cluster + `/24`/node = 256 nodów. Minimum dla HA: `/16` (standard `10.244.0.0/16`).

## Audit policy + encryption-at-rest
- **Audit policy** — apiserver loguje każdy request (kto/co/kiedy). Poziomy: None/Metadata/Request/RequestResponse. Wymagane przez SOC2/ISO 27001/PCI-DSS. Forensic/detection po fakcie, nie ochrona.
- **Encryption-at-rest** — apiserver szyfruje Secret/ConfigMap przed zapisem do etcd. Providery: `aesgcm`, `kms`. Chroni przed wyciekiem etcd backupów; nie chroni przed compromise apiservera (klucz w RAM). Produkcja: `kms` + HSM/cloud KMS, rotacja co 90 dni.

## etcd stacked vs external
- **Stacked** (default kubeadm): etcd na każdym CP. Prostsze, mniej VM; CP outage = etcd outage.
- **External**: dedicated etcd VM. Niezależne skalowanie, CP upgrade bez dotykania etcd; więcej VM/ops.
- <100 nodów: stacked; 100–500: rozważ external; >500: external + NVMe.

## Join CP: dlaczego `--apiserver-advertise-address`

`kubeadm init` bierze adres z `advertiseAddress` w `kubeadm-config.yaml` — prywatny — i taki
trafia do SAN-ów certyfikatu peer etcd:
`DNS:cpnode1, DNS:localhost, IP:10.135.0.20, IP:127.0.0.1`.

`kubeadm join` tego pliku nie czyta i wybiera adres z interfejsu z **domyślną trasą**, czyli
na dropletach DO publiczny. Sprawdzone: nie zależy to od `/etc/hosts` — przy
`kubeapi.example.com` wskazującym na adres prywatny join i tak wybrał publiczny.

Nowy członek etcd startuje więc z `--listen-peer-urls=https://<PUBLICZNY>:2380`. cpnode1
łączy się do niego po publicznym IP, więc ma publiczny adres źródłowy — a tego nie ma
w jego certyfikacie. Learner odrzuca połączenie:
`tls: "138.68.93.203" does not match any of DNSNames ["cpnode1" "localhost"]`.
Raft nie płynie, learner się nie synchronizuje i po ~2 min join pada na
`can only promote a learner member which is in sync with leader`.

To **nie** jest brak łączności — TCP na publiczny `:2380` działa. To niezgodność SAN-ów:
jedna strona peeruje prywatnie, druga publicznie.

Wyjście z zablokowanego stanu (sam ponowny join nie wystarczy):
```bash
# na cpnode1 — znajdź learnera i usuń go
kubectl -n kube-system exec etcd-cpnode1 -- etcdctl \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key member list
# ... member remove <ID learnera>

# na node, który padł
kubeadm reset -f && rm -rf /etc/cni/net.d /var/lib/etcd
```

## Cilium stoi na Init:0/6 — brak IP LoadBalancera w certSANs

Objaw: po `cilium install` agent wisi w `Init:0/6` i restartuje się, operator w
CrashLoopBackOff, CoreDNS w `Pending`. Wygląda na problem z siecią, ale nie jest.

`Init:0/6` to pierwszy z sześciu init-kontenerów — `config`, który uruchamia
`cilium-dbg build-config` i **łączy się z apiserverem**. Przy `kubeProxyReplacement=true`
nie ma kube-proxy ani ClusterIP, więc jedyną drogą jest `k8sServiceHost:k8sServicePort`.

Prawda jest w logach tego kontenera:
```bash
kubectl -n kube-system logs -l k8s-app=cilium -c config --tail=20
```
```
tls: failed to verify certificate: x509: certificate is valid for
10.96.0.1, 10.135.0.4, ..., 207.154.222.233, not 139.59.205.196
```

Czyli certyfikat apiservera nie ma w SAN-ach IP LoadBalancera — a to właśnie ten adres
podajemy jako `k8sServiceHost`. Pułapka polega na tym, że `kubeadm init` przechodzi bez
ostrzeżenia, a objaw wychodzi dopiero przy Cilium, kilka kroków dalej.

Uwaga: `kubeapi.example.com` zwykle **jest** w certSANs i wskazuje na to samo IP — ale
podanie nazwy zamiast IP nie pomoże, bo Pody Cilium mają własny `/etc/hosts` i nie widzą
wpisu z node'a.

Naprawa bez stawiania klastra od nowa:
```bash
# 1) dopisz IP LB do certSANs w kubeadm-config.yaml, potem:
rm /etc/kubernetes/pki/apiserver.{crt,key}
kubeadm init phase certs apiserver --config ./kubeadm-config.yaml

# 2) restart statycznego Poda apiservera
mv /etc/kubernetes/manifests/kube-apiserver.yaml /root/ && sleep 15 \
  && mv /root/kube-apiserver.yaml /etc/kubernetes/manifests/

# 3) ConfigMap w klastrze — stąd kolejne CP wezmą certSANs przy join
kubectl -n kube-system get cm kubeadm-config -o jsonpath='{.data.ClusterConfiguration}' > cc.yaml
#    dopisz IP LB pod certSANs, potem:
kubectl -n kube-system create cm kubeadm-config \
  --from-file=ClusterConfiguration=cc.yaml --dry-run=client -o yaml | kubectl apply -f -

# 4) Cilium od nowa
kubectl -n kube-system delete pod -l k8s-app=cilium
kubectl -n kube-system rollout restart deploy/cilium-operator
```

Po restarcie apiservera LoadBalancer DO potrzebuje ~15-30 s (health check TCP 6443,
trzy sprawdzenia co 5 s), zanim znów zacznie przepuszczać ruch.

## VIP z maską /24 rozwala peering etcd

`eth1` na dropletach DO ma adres `10.135.0.x/16`. Dodanie VIP-a jako `/24`
(`ip a a dev eth1 10.135.0.100/24`) tworzy bardziej szczegółową trasę na `10.135.0.0/24`,
więc **cały** ruch w tej podsieci zaczyna wychodzić ze źródłem `10.135.0.100`:

```
$ ip route get 10.135.0.18
10.135.0.18 dev eth1 src 10.135.0.100      # zamiast src 10.135.0.21
```

Certyfikat peer etcd cpnode1 ma SAN-y `IP:10.135.0.21, IP:127.0.0.1` — VIP-a tam nie ma.
Leader wysyła snapshot do learnera z niepasującego adresu, learner odrzuca połączenie,
sync nie następuje i join pada na `can only promote a learner member which is in sync
with leader` — objaw identyczny jak przy publicznym IP, przyczyna inna.

Z maską `/32` trasa się nie zmienia, `src` zostaje `10.135.0.21` i join przechodzi.
kube-vip sam używa `/32` (`vip_subnet: "32"` w `kube-vip.sh`), więc /24 w README było
niespójne także z tym.

## Cilium Gateway API: NET_BIND_SERVICE

`cilium-envoy` domyślnie dostaje tylko `NET_ADMIN` i `SYS_ADMIN`, więc nie zbinduje portu
<1024. Objaw jest mylący, bo wszystko wygląda zdrowo: `GatewayClass Accepted=True`,
Gateway `PROGRAMMED=True`, operator loguje „Successfully reconciled Gateway",
`CiliumEnvoyConfig` ma poprawny listener na `0.0.0.0:80` — a `curl` dostaje connection
refused i `ss -lntp` nie pokazuje nic na `:80`.

Prawda jest w logach `cilium-envoy`:
```
cannot bind '0.0.0.0:80': Permission denied
```

Samo `keepCapNetBindService=true` **nie wystarcza** — ustawia tylko flagę
`envoy-keep-cap-netbindservice` w `cilium-config`, a kontener nadal ma starą listę
capability. Trzeba podać obie rzeczy:
```
--set envoy.securityContext.capabilities.keepCapNetBindService=true
--set envoy.securityContext.capabilities.envoy="{NET_ADMIN,SYS_ADMIN,NET_BIND_SERVICE}"
```

Weryfikacja: `kubectl -n kube-system get ds cilium-envoy -o jsonpath='{.spec.template.spec.containers[0].securityContext.capabilities.add}'`
ma zwrócić listę z `NET_BIND_SERVICE`.

## Walidacja end-to-end
```bash
kubectl get nodes -o wide                                # 6 Ready
kubectl get pods -n kube-system                          # cilium, kube-vip×3, etcd×3, BRAK kube-proxy
cilium status --wait
kubectl get leases -n kube-system plndr-cp-lock          # holderIdentity = aktywny leader
curl -sk https://kubeapi.example.com:6443/healthz        # ok
```

## Troubleshooting
- `kubeadm init` hangs at „api server health check" → VIP nie działa. `ip a | grep <VIP>`, `journalctl -u kubelet`, `crictl ps | grep kube-vip`. Często zły `vip_interface`.
- Node `NotReady` → `NetworkReady: false`, CNI nie zainstalowany. Uruchom `cilium install`.
- kube-vip leader flapping → network partition między CP. Sprawdź `ping` latency (>50ms = problem VPC).
- `kubeadm join --control-plane` fails `FileAvailable--...kube-vip.yaml` → zapomniany scp static poda.
- DO: VIP nie odpowiada, klaster działa → VPC blokuje GARP, endpoint celuje w DO LB; kube-vip pokazujemy dydaktycznie. Oczekiwane.

## Cross-link
- D2/07 (Gateway API) — wdrażaj w prawdziwym klastrze po instalacji
- D2/06 (AuthN/AuthZ) — RBAC na prawdziwym klastrze
- D3/08 (NetworkPolicy) — Cilium domyślnie wspiera NP
- D4/03 (Admission Controllers) — VAP na prawdziwym klastrze

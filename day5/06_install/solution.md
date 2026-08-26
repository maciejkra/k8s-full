# Solution — 06_install

## kube-vip jako static pod, nie DaemonSet
Static pod (`/etc/kubernetes/manifests/kube-vip.yaml`): kubelet uruchamia Pod przed połączeniem z apiserver → VIP gotowy zanim kubeadm init kontaktuje apiserver. DaemonSet wstałby dopiero po gotowym apiserverze (~30s bez VIP, chicken-and-egg). Pułapka: `kubeadm join --control-plane` nie kopiuje static pod manifestów — `scp` ręcznie na każdy nowy CP przed join.

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

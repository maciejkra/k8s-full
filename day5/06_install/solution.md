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

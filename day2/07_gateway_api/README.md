# 07 — Gateway API (Envoy Gateway)

## Cel
Wystawić aplikację python-api (z D1/11) przez Gateway API. Rdzeń ćwiczenia jest w `task.md`. Sekcje „Opcjonalne" niżej (routing po domenie, URLRewrite, TLS, cert-manager) to rozszerzenia dla chętnych.

## Kontekst
Gateway API zastępuje Ingress. GA (v1.0) od października 2023 — to osobny projekt SIG-Network, wersjonowany niezależnie od Kubernetesa (dziś v1.6.1), instalowany jako CRD-y, a nie część core API. Trzy CRD-y, trzy role:
- `GatewayClass` — implementacja (Envoy, NGINX, Cilium, …) — infra admin
- `Gateway` — instancja LB z portami i listenerami — cluster operator
- `HTTPRoute` (lub `TCPRoute`, `TLSRoute`, `GRPCRoute`) — reguły routingu — app dev

Routing i filtry (rewrite, redirect, modyfikacja nagłówków) są w `spec`, nie w adnotacjach per-controller — ten sam manifest działa na Envoy Gateway, NGINX Gateway Fabric, Cilium czy Istio.

## Prereqs
- Klaster Kubernetes: Docker Desktop / Kind / K3d / managed (cloud)
- Envoy Gateway zainstalowany dla Twojego runtime (sekcja „Setup" poniżej)
- Aplikacja Python+Redis z D1/11. Service `python-service` nasłuchuje na porcie 80 (Service port), wewnętrznie `targetPort` mapuje na `containerPort: 5002`. W `HTTPRoute.backendRefs.port` używaj portu Service (`80`).

## Setup Envoy Gateway — wybierz swój runtime

Krok wspólny dla Kind / Docker Desktop / K3d — zainstaluj kontroler. Helma poznajemy dopiero
w `day5/02_helm`, więc tu zwykły `kubectl apply` (Envoy Gateway publikuje `install.yaml`
w release assets):
```bash
kubectl apply --server-side -f https://github.com/envoyproxy/gateway/releases/download/v1.9.0/install.yaml
kubectl wait --timeout=5m -n envoy-gateway-system \
  deployment/envoy-gateway --for=condition=Available
```
`install.yaml` zawiera CRD-y Gateway API (bundle v1.6.1) + Envoy Gateway. **Nie** tworzy
`GatewayClass` — robi to `gateway-http.yaml` niżej. Dalej wykonaj kroki TYLKO dla swojego runtime.

> Gdyby `install.yaml` v1.9.0 sprawiał kłopoty, poprzednia stabilna linia to
> `v1.8.3` — ten sam URL, inny tag.

### Docker Desktop (wbudowany Kubernetes)/K3d
LoadBalancer działa na `localhost` od ręki — nic więcej nie trzeba. Po stworzeniu Gateway `curl http://localhost/` trafia w Envoy. Pomiń też `kubectl patch gatewayclass` z sekcji Kind.

### Kind
Kind nie ma cloud-providera → Service typu LoadBalancer wisi w `EXTERNAL-IP=<pending>`. Przypinamy poda Envoya do control-plane i otwieramy na nim `hostPort`:
- `day1/04_k8s/kind.yaml` mapuje host `80/443` → containerPort `80/443` (tylko control-plane, label `ingress-ready=true`, taint `node-role.kubernetes.io/control-plane:NoSchedule`).
```bash
# EnvoyProxy CR: hostPort 80/443 + nodeSelector ingress-ready + toleration
kubectl apply -f envoyproxy-kind.yaml

# Podepnij CR pod GatewayClass eg
kubectl patch gatewayclass eg --type=merge -p '{
  "spec": {"parametersRef": {
    "group": "gateway.envoyproxy.io", "kind": "EnvoyProxy",
    "name": "kind-control-plane", "namespace": "envoy-gateway-system"}}}'
```

### Managed (DOKS / EKS / GKE) — nie instaluj Envoy Gateway
Na klastrze zarządzanym z własnym Gateway API **kontrolera nie instalujesz w ogóle**. Sprawdź, co już jest:
```bash
kubectl get gatewayclass
```
Na **DigitalOcean (DOKS)** zobaczysz `cilium  io.cilium/gateway-controller  Accepted=True` — wbudowany Cilium z włączonym Gateway API. Wystarczy `Gateway` z `gatewayClassName: cilium`, a DO sam nada mu publiczny `EXTERNAL-IP` (Service `cilium-gateway-<nazwa>`).

Instalacja Envoy Gateway na DOKS **padnie**: DO pinuje własne CRD-y Gateway API (bundle `v1.2.1`, field manager `c3`), a `install.yaml` v1.9.0 przynosi `v1.6.1` — Server-Side Apply kończy się `Apply failed ... conflicts with "c3"`. `--skip-crds` (Helm) tego nie ratuje, bo Envoy Gateway trzyma CRD-y w `templates/`, nie w `crds/`.

Gotowy, przetestowany przepis dla DOKS (HTTP → Let's Encrypt → HTTPS) jest niżej w sekcji **„TLS przez cert-manager"**.

## Sanity check — `curl http://localhost/` zwraca stronę
```bash
kubectl get pods -n envoy-gateway-system
kubectl apply -f gateway-http.yaml -f app.yaml -f httproute-welcome.yaml
# Kind: tu wykonaj patch gatewayclass z sekcji Kind powyżej (po stworzeniu Gateway)
kubectl wait --for=condition=Programmed gateway/training-gateway --timeout=2m
curl -s http://localhost/ | head -3
```
`httproute-welcome.yaml` to catch-all (bez `hostnames`) — matchuje każdy Host header. Route'y z konkretnym hostname wygrywają nad nim (most-specific match), więc może zostać w klastrze.

---

## Zadanie
Rdzeń ćwiczenia: `task.md` (napisz HTTPRoute → python-api + zadanie z gwiazdką z filtrem `URLRewrite`).

---

## Next Steps

> Pliki `httproute-*.yaml`, `gateway-https.yaml`, `certificate.yaml`, `cluster-issuer-letsencrypt.yaml` to gotowe przykłady poniższych rozszerzeń.

### Routing po nazwie domeny (nip.io)
Dwa HTTPRoute z różnymi `hostnames` na tej samej Gateway:
```bash
kubectl apply -f httproute-domain.yaml
curl http://python.127-0-0-1.nip.io/api/v1/info
curl http://nginx.127-0-0-1.nip.io/
```
`<cokolwiek>.A-B-C-D.nip.io` rozwiązuje się na IP `A.B.C.D` (tu `127.0.0.1`) — bez DNS / `/etc/hosts`.

### URLRewrite — migracja legacy ścieżki
Stare klienty wołają `/old-api/v1/info`, backend przyjmuje `/api/v1/info`. Filter `URLRewrite` (`ReplacePrefixMatch`) przepisuje prefix `/old-api` → `/api`:
```bash
kubectl apply -f httproute-uri.yaml -f httproute-rewrite.yaml
curl http://demo.127-0-0-1.nip.io/old-api/v1/info
```
Dwa HTTPRoute na tym samym hoście koegzystują (most-specific match). Inne filtry: `RequestHeaderModifier`, `RequestRedirect` (HTTP→HTTPS), `RequestMirror`, `ResponseHeaderModifier`.

### TLS self-signed (openssl + `kubernetes.io/tls` Secret)
Gateway API referuje Secret przez `certificateRefs` — cert generujemy openssl-em (offline, bez cert-managera):
```bash
openssl req -x509 -newkey rsa:2048 -nodes -days 365 \
  -keyout /tmp/tls.key -out /tmp/tls.crt \
  -subj "/CN=python.127-0-0-1.nip.io" \
  -addext "subjectAltName=DNS:python.127-0-0-1.nip.io,DNS:demo.127-0-0-1.nip.io,DNS:nginx.127-0-0-1.nip.io"
kubectl create secret tls app-tls --cert=/tmp/tls.crt --key=/tmp/tls.key \
  --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -f gateway-https.yaml -f httproute-domain.yaml
curl -kv https://python.127-0-0-1.nip.io/api/v1/info 2>&1 | grep -E "subject|issuer|HTTP/"
# subject == issuer  => self-signed
```
Listener `tls.mode: Terminate` + `certificateRefs`. Envoy ładuje Secret i terminuje TLS. Rotacja: podmiana Secret → Envoy przeładowuje cert.

### TLS przez cert-manager + Let's Encrypt (wymaga PUBLICZNEGO IP)

HTTP-01 wymaga, by Let's Encrypt dotarł do Twojego IP z internetu — z `127.0.0.1` nie zadziała. Poniższy przepis jest przetestowany na **DOKS** (wbudowany Cilium, bez Envoy Gateway — patrz sekcja „Managed" wyżej).

**1) Gateway na `cilium` — DO nada publiczny EXTERNAL-IP**
```bash
kubectl apply -f ../../day1/11_deployment/solution/   # python-api + redis
kubectl apply -f - <<'EOF'
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata: { name: training-gateway, namespace: default }
spec:
  gatewayClassName: cilium
  listeners:
    - { name: http, protocol: HTTP, port: 80, allowedRoutes: { namespaces: { from: All } } }
EOF
kubectl wait --for=condition=Programmed gateway/training-gateway --timeout=5m
IP=$(kubectl get gateway training-gateway -o jsonpath='{.status.addresses[0].value}')
echo $IP
```

**2) cert-manager (też bez Helma) + solver Gateway**
```bash
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.21.1/cert-manager.yaml
kubectl wait --timeout=5m -n cert-manager \
  deployment/cert-manager deployment/cert-manager-webhook --for=condition=Available

kubectl -n cert-manager patch deploy cert-manager --type=json \
  -p='[{"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--enable-gateway-api"}]'
kubectl -n cert-manager rollout status deploy/cert-manager
```
Bez flagi `--enable-gateway-api` `gateway-shim` jest wyłączony i Challenge wisi w `pending` z `gateway api is not enabled`.

**3) HTTPRoute + pre-flight HTTP-01**

W `httproute.yaml` podmień `<GATEWAY-IP>` na IP z kroku 1 (`hostnames`), potem:
```bash
kubectl apply -f httproute.yaml
curl -s -o /dev/null -w "%{http_code}\n" http://python.$IP.nip.io/.well-known/acme-challenge/probe
# 404 z backendu = ścieżka drożna. refused/timeout => NIE wystawiaj certu (rate limit LE!)
```

**4) Certificate (issuer `letsencrypt-prod`)**

W `certificate.yaml` podmień `<GATEWAY-IP>` na to samo IP (`dnsNames` musi się zgadzać
z `hostnames` w `httproute.yaml`), potem:
```bash
kubectl apply -f cluster-issuer-letsencrypt.yaml
kubectl apply -f certificate.yaml
kubectl wait --for=condition=Ready certificate/app-tls --timeout=5m   # ~40 s
```

**5) Listener HTTPS — Cilium terminuje TLS Secretem `app-tls`**
```bash
kubectl apply -f - <<EOF
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata: { name: training-gateway, namespace: default }
spec:
  gatewayClassName: cilium
  listeners:
    - { name: http, protocol: HTTP, port: 80, allowedRoutes: { namespaces: { from: All } } }
    - name: https
      protocol: HTTPS
      port: 443
      hostname: python.$IP.nip.io
      tls: { mode: Terminate, certificateRefs: [ { kind: Secret, name: app-tls } ] }
      allowedRoutes: { namespaces: { from: All } }
EOF

curl -sv https://python.$IP.nip.io/api/v1/info 2>&1 | grep -iE 'issuer:|subject:'
# issuer: C=US; O=Let's Encrypt  ->  zaufany łańcuch, curl BEZ -k
```

> `cluster-issuer-letsencrypt.yaml` definiuje oba issuery. Powyższy przepis idzie od razu na
> `letsencrypt-prod` (zielona kłódka bez `-k`) — ceną jest limit **5 nieudanych walidacji na
> godzinę na hostname**, stąd pre-flight `curl` w kroku 3. Jeśli iterujesz nad konfiguracją,
> przełącz `issuerRef` w `certificate.yaml` na `letsencrypt-staging`
> (cert niezaufany, `curl -k`, ale limity dużo wyższe).

## Linki
- [Gateway API spec](https://gateway-api.sigs.k8s.io/)
- [Envoy Gateway docs](https://gateway.envoyproxy.io/)
- [HTTPRoute filters (URLRewrite, redirect, …)](https://gateway-api.sigs.k8s.io/api-types/httproute/)
- [cert-manager docs](https://cert-manager.io/docs/)
- [nip.io — wildcard DNS](https://nip.io/)
- [ingress2gateway migration tool](https://github.com/kubernetes-sigs/ingress2gateway)

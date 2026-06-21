# 07 — Gateway API (Envoy Gateway)

## Cel
Wystawić aplikację python-api (z D1/11) przez Gateway API. Rdzeń ćwiczenia jest w `task.md`. Sekcje „Opcjonalne" niżej (routing po domenie, URLRewrite, TLS, cert-manager) to rozszerzenia dla chętnych.

## Kontekst
Gateway API (GA od K8s 1.29) zastępuje Ingress. Trzy CRD-y, trzy role:
- `GatewayClass` — implementacja (Envoy, NGINX, Cilium, …) — infra admin
- `Gateway` — instancja LB z portami i listenerami — cluster operator
- `HTTPRoute` (lub `TCPRoute`, `TLSRoute`, `GRPCRoute`) — reguły routingu — app dev

Routing i filtry (rewrite, redirect, modyfikacja nagłówków) są w `spec`, nie w adnotacjach per-controller — ten sam manifest działa na Envoy Gateway, NGINX Gateway Fabric, Cilium czy Istio.

## Prereqs
- Klaster Kubernetes: Docker Desktop / Kind / K3d / managed (cloud)
- Envoy Gateway zainstalowany dla Twojego runtime (sekcja „Setup" poniżej)
- Aplikacja Python+Redis z D1/11. Service `python-service` nasłuchuje na porcie 80 (Service port), wewnętrznie `targetPort` mapuje na `containerPort: 5002`. W `HTTPRoute.backendRefs.port` używaj portu Service (`80`).

## Setup Envoy Gateway — wybierz swój runtime

Krok wspólny dla KAŻDEGO runtime — zainstaluj kontroler:
```bash
helm upgrade --install eg oci://docker.io/envoyproxy/gateway-helm \
  --version v1.3.2 -n envoy-gateway-system --create-namespace
kubectl wait --timeout=5m -n envoy-gateway-system \
  deployment/envoy-gateway --for=condition=Available
```
Chart to OCI artifact z Docker Hub (stąd `oci://`, nie `helm repo add`). Instalacja tworzy `GatewayClass eg`. Dalej wykonaj kroki TYLKO dla swojego runtime:

### Docker Desktop (wbudowany Kubernetes)/K3d
LoadBalancer działa na `localhost` od ręki — nic więcej nie trzeba. Po stworzeniu Gateway `curl http://localhost/` trafia w Envoy.

### Kind
Kind nie ma cloud-providera → Service typu LoadBalancer wisi w `EXTERNAL-IP=<pending>`. Trzeba NodePort + pin data-plane na control-plane:
- `day1/04_k8s/kind.yaml` mapuje host `80/443` → containerPort `30080/30443` (tylko control-plane, label `ingress-ready=true`, taint `node-role.kubernetes.io/control-plane:NoSchedule`).
```bash
# EnvoyProxy CR: Service NodePort 30080/30443 + nodeSelector ingress-ready + toleration
kubectl apply -f envoyproxy-kind.yaml

# Podepnij CR pod GatewayClass eg
kubectl patch gatewayclass eg --type=merge -p '{
  "spec": {"parametersRef": {
    "group": "gateway.envoyproxy.io", "kind": "EnvoyProxy",
    "name": "kind-control-plane", "namespace": "envoy-gateway-system"}}}'
```

### Managed (DOKS / EKS / GKE / Cilium CNI)
CRD-y Gateway API zwykle już są w klastrze → dorzuć `--skip-crds` do `helm install` (inaczej Server-Side Apply conflict). Cloud LoadBalancer nada publiczny `EXTERNAL-IP`:
```bash
helm upgrade --install eg oci://docker.io/envoyproxy/gateway-helm \
  --version v1.3.2 --skip-crds -n envoy-gateway-system --create-namespace
kubectl get svc -n envoy-gateway-system   # EXTERNAL-IP = publiczny IP
```
Pinuj stabilny tag (`v1.3.x`) — `v0.0.0-latest` wymaga channel `experimental` (m.in. `TLSRoute` w `v1`), którego managed K8s w channel `standard` nie ma.

## Sanity check — `curl http://localhost/` zwraca stronę
```bash
kubectl get pods -n envoy-gateway-system
kubectl apply -f gateway-http.yaml -f app.yaml -f httproute-welcome.yaml
# Kind: tu wykonaj patch gatewayclass z sekcji Kind powyżej (po stworzeniu Gateway)
kubectl wait --for=condition=Programmed gateway/training-gateway --timeout=2m
curl -s http://localhost/ | head -3
```
`httproute-welcome.yaml` to catch-all (bez `hostnames`) — matchuje każdy Host header. Route'y z konkretnym hostname wygrywają nad nim (most-specific match).

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
```
Listener `tls.mode: Terminate` + `certificateRefs`. Envoy ładuje Secret i terminuje TLS. Rotacja: podmiana Secret → Envoy przeładowuje cert.

### TLS przez cert-manager (Let's Encrypt staging)
Najpierw zainstaluj cert-manager:
```bash
helm repo add jetstack https://charts.jetstack.io
helm repo update
helm upgrade --install cert-manager jetstack/cert-manager \
  -n cert-manager --create-namespace \
  --set crds.enabled=true \
  --set config.apiVersion=controller.config.cert-manager.io/v1alpha1 \
  --set config.kind=ControllerConfiguration \
  --set config.enableGatewayAPI=true
kubectl wait --timeout=5m -n cert-manager deployment/cert-manager --for=condition=Available
```
`crds.enabled=true` — bez tego `apply -f certificate.yaml` padnie z `no matches for kind "Certificate"`. `config.enableGatewayAPI=true` — bez tego `gateway-shim` jest wyłączony i Challenge wisi z `gateway api is not enabled` (w v1.20 to nie feature gate, lecz `ControllerConfiguration`).

```bash
kubectl apply -f cluster-issuer-letsencrypt.yaml
# Edytuj certificate.yaml — własna nip.io z PUBLICZNYM IP
kubectl apply -f certificate.yaml
kubectl wait --for=condition=Ready certificate/app-tls --timeout=5m
kubectl apply -f gateway-https.yaml
curl -k https://python.<TWOJ-IP>.nip.io/api/v1/info
```
HTTP-01 wymaga, by Let's Encrypt dotarł do Twojego IP z internetu — z `127.0.0.1` nie zadziała (potrzebny publiczny IP: `cloudflared tunnel`/`ngrok`, lub DNS-01). Rate limit `letsencrypt-prod`: 50 cert/tydzień/domena — iteruj na `letsencrypt-staging` (`cluster-issuer-letsencrypt.yaml` definiuje oba).

## Linki
- [Gateway API spec](https://gateway-api.sigs.k8s.io/)
- [Envoy Gateway docs](https://gateway.envoyproxy.io/)
- [HTTPRoute filters (URLRewrite, redirect, …)](https://gateway-api.sigs.k8s.io/api-types/httproute/)
- [cert-manager docs](https://cert-manager.io/docs/)
- [nip.io — wildcard DNS](https://nip.io/)
- [ingress2gateway migration tool](https://github.com/kubernetes-sigs/ingress2gateway)

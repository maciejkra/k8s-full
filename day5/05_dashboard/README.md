# 05 — Web UI do klastra (Kubernetes Dashboard zarchiwizowany)

## Status: Kubernetes Dashboard wycofany
Repozytorium **Kubernetes Dashboard zostało zarchiwizowane 21 stycznia 2026** (`kubernetes/dashboard` → `kubernetes-retired/dashboard`, read-only — brak dalszego rozwoju i poprawek bezpieczeństwa). Dodatkowo w wersji v3.x dochodzi komponent **Kong proxy**, który ma udokumentowane problemy ze startem (bind unix socket / IPv6, nieudane probe, DNS timeout do `kubernetes-dashboard-web`) — instalacja często nie wstaje out-of-the-box.

Dlatego nie instalujemy już Dashboardu. Poniżej aktualne alternatywy.

## Alternatywy

### Headlamp — oficjalny następca (CNCF Sandbox, SIG UI), web UI
Web/desktop UI z systemem pluginów, OIDC, RBAC. Główna rekomendacja jako zamiennik Dashboardu.

```bash
# Wariant in-cluster (Helm)
helm repo add headlamp https://kubernetes-sigs.github.io/headlamp/
helm repo update
helm install headlamp headlamp/headlamp -n kube-system

# Dostęp
kubectl -n kube-system port-forward svc/headlamp 8080:80
# http://localhost:8080  → logowanie tokenem ServiceAccount:
kubectl -n kube-system create token headlamp --duration=1h
```
Wariant desktop (bez instalacji w klastrze) — aplikacja czyta lokalny `~/.kube/config`: https://headlamp.dev/

### k9s — terminal UI (TUI)
Najszybszy do logów / podów / remediacji, keyboard-driven, czyta `~/.kube/config`.
```bash
brew install k9s        # macOS; Linux: https://k9scli.io/topics/install/
k9s
```

### FreeLens — desktop (następca OpenLens)
Po wycofaniu OpenLens / Lens OSS — w pełni open-source desktop IDE do klastrów.
```bash
brew install --cask freelens   # lub release z https://github.com/freelensapp/freelens/releases
```

### Portainer — web, multi-cluster, enterprise RBAC
Dla zarządzania wieloma klastrami z jednego UI.
```bash
helm repo add portainer https://portainer.github.io/k8s/
helm repo update
helm install portainer portainer/portainer -n portainer --create-namespace
kubectl -n portainer port-forward svc/portainer 9000:9000
# http://localhost:9000
```

## Linki
- [Headlamp](https://headlamp.dev/) · [repo](https://github.com/kubernetes-sigs/headlamp)
- [k9s](https://k9scli.io/)
- [FreeLens](https://github.com/freelensapp/freelens)
- [Portainer](https://www.portainer.io/)
- [kubernetes-retired/dashboard (archiwum)](https://github.com/kubernetes-retired/dashboard)

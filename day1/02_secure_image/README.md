# 02 — Secure image: multi-stage Go build

## Cel
Porównać obraz standardowy i multi-stage. Zobaczyć redukcję rozmiaru (~900 MB → ~10 MB) i mniejszy attack surface.

## Prereqs
- [Trivy](https://aquasecurity.github.io/trivy/) (porównanie CVE)

Zadanie: `task.md` · rozwiązanie: `solution.md`

## Linki
- [Multi-stage builds](https://docs.docker.com/build/building/multi-stage/)
- [Distroless images](https://github.com/GoogleContainerTools/distroless)
- [Building static Go binaries](https://www.arp242.net/static-go.html)

# 01 — Debug Pod (ephemeral containers, kubectl debug)

## Cel
Zdebugować aplikację w obrazie distroless/scratch (bez shella) używając `kubectl debug` — ephemeral container oraz `--copy-to`.

## Prereqs
- Klaster K8s ≥1.25 (K3s / Kind / K3d)

Zadanie: `task.md` · rozwiązanie: `solution.md`

## Linki
- [Debug Running Pod](https://kubernetes.io/docs/tasks/debug/debug-application/debug-running-pod/#ephemeral-container)
- [nicolaka/netshoot](https://github.com/nicolaka/netshoot)

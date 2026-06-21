# Parallel Completion — fixed count

## Cel
Wykonać N identycznych zadań równolegle (`completions: N, parallelism: M`).

## Prereqs
- Działający klaster (k3d / kind).

## Manifest
- `job.yaml` — Job `parallel-completion`: `completions: 10`, `parallelism: 5`, `backoffLimit: 0`, image `busybox`.

Kroki i omówienie: zobacz [`../task.md`](../task.md) i [`../solution.md`](../solution.md).

## Linki
- [Job patterns](https://kubernetes.io/docs/concepts/workloads/controllers/job/#job-patterns)

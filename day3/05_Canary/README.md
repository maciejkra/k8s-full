https://github.com/ContainerSolutions/k8s-deployment-strategies


## Task

1. Create 2 different Deployments one with `python app` one with `nginx`
2. Create them in 2 different namespaces
3. Make a propper changes in the HTTPRoute (weighted `backendRefs`) - 30% of traffic should hit nginx
4. Run curl on the HTTPRoute hostname (for example `api.127-0-0-1.nip.io`) and check if it works

> Wymaga Gateway API z `day2/07_gateway_api` (`training-gateway`, `Programmed=True`).
> Gotowe manifesty weighted HTTPRoute: `solution/`. Szczegóły i progresywny rollout: `task.md`. Pozostałe strategie wdrożeń: `day1/11_deployment/strategies/`.

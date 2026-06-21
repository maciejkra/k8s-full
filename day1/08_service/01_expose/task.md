# Zadanie

1. Napisz `service.yaml` dla Pod-a python typu `NodePort`.
2. Otwórz w przeglądarce `<IP-node>:<NodePort>` i sprawdź, że aplikacja odpowiada.
3. Sprawdź dostęp od wewnątrz klastra przez DNS (krótka i pełna nazwa).
4. Obejrzyj `/etc/resolv.conf` w Pod-zie — co zawiera linia `search`?

```sh
kubectl apply -f service.yaml
kubectl exec -ti myapp-pod -- curl my-app-service
kubectl exec -ti myapp-pod -- curl my-app-service.default.svc.cluster.local
kubectl exec -ti myapp-pod -- cat /etc/resolv.conf
```

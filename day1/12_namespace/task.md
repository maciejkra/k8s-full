# Zadanie

1. Wypisz listę istniejących namespace.
2. Stwórz nowy namespace `workshops`.
3. Zaaplikuj deployment `python-app` w namespace `workshops` i wypisz wszystkie zasoby z tego namespace.
4. Ustaw `workshops` jako default dla bieżącego kontekstu, zweryfikuj `kubectl get pods` bez `-n`, potem wróć do `default`.

```sh
kubectl create namespace workshops
kubectl apply -f . -n workshops
kubectl get all -n workshops
kubectl config set-context --current --namespace=workshops
kubectl config set-context --current --namespace=default
```

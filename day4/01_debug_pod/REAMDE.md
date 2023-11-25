## Debug Pod

```sh
kubectl apply -f scretch-deployment.yaml
```

Now let's try to debug the app - lets tcpdump all incoming traffic on port 8080
To do that lets enter the app and install tcpdump
```sh
kubectl exec -it <podname> -- sh
```
:(

We have 2 options:

```sh
kubectl debug -it <podname> --image=nicolaka/netshoot -- tcpdump -n port 8080
```
or this to make a copy of a pod for debugging
```sh
kubectl debug -it <podname> --image=ubuntu --share-processes --copy-to=myapp-debug
```




https://kubernetes.io/docs/tasks/debug/debug-application/debug-running-pod/#ephemeral-container
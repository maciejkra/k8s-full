## Install helm
[Install helm](https://helm.sh/docs/intro/install/)

Consider setting up [helm completition](https://v3-1-0.helm.sh/docs/helm/helm_completion/)

## Add & search repo
```sh
helm repo add workshop https://maciejkra.github.io/helm/
helm repo update #optional
helm search repo workshop
```

## Install chart
```sh
helm install <release> workshop/hello-world -n <namespace>
```

or
```sh
helm install --generate-name workshop/hello-world -n <namespace>
```
or
```sh
helm upgrade --install <release> workshop/hello-world -n <namespace>
```
or
```sh
helm upgrade --install <release> workshop/hello-world -n <namespace> --create-namespace
```
or 
```sh
helm upgrade --install --atomic <release> workshop/hello-world -n <namespace> --create-namespace
```
or just
```sh
helm upgrade --help
```

## Check if everything works
```sh
helm ls -n <namespace>
kubectl get all -n <namespace>
kubectl get secrets -n <namespace>
```

## Check values
```sh
helm show values workshop/hello-world # gets information about the chart
helm get values <release> # gets information about the release
```

## Customize values and upgrade

```sh
helm upgrade --install --atomic <release> workshop/hello-world -n <namespace> --create-namespace --set <key>=<value>
```
or
```sh
helm upgrade --install --atomic <release> workshop/hello-world -n <namespace> --create-namespace -f <value file>
```

# Task :)
Get some value from `workshop/hello-world` and update the release - check if it works.

If everything is ok perform rollback with

```sh
helm status <release>           # This command shows the status of a named release.
helm history <release>          # Historical revisions for a given release.
helm rollback <release> <revision>
```





## Now let's try something hard...

```sh
helm pull workshop/hello-world --untar=true
```

## Remove the release
```sh
helm uninstall <release>
```


# Useful links
* [Helm cheat sheet](https://helm.sh/docs/intro/cheatsheet/)
* [Helm qucikstart guide](https://helm.sh/docs/intro/quickstart/)
* [Helm using helm](https://helm.sh/docs/intro/using_helm/)
* [Helm charts](https://helm.sh/docs/topics/charts/)

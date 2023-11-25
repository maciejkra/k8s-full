## Pod Security Admission

* [Pod Security Standards](https://kubernetes.io/docs/concepts/security/pod-security-standards/)
* [Security Context for a Pod or Container](https://kubernetes.io/docs/tasks/configure-pod-container/security-context/)

```sh
kubectl explain pod.spec.securityContext
```


[Pod Security Admission](https://kubernetes.io/docs/concepts/security/pod-security-admission/)


```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: my-baseline-namespace
  labels:

    # The per-mode level label indicates which policy level to apply for the mode.
    #
    # MODE must be one of `enforce`, `audit`, or `warn`.
    # LEVEL must be one of `privileged`, `baseline`, or `restricted`.
    pod-security.kubernetes.io/<MODE>: <LEVEL>

    # Optional: per-mode version label that can be used to pin the policy to the
    # version that shipped with a given Kubernetes minor version (for example v1.28).
    #
    # MODE must be one of `enforce`, `audit`, or `warn`.
    # VERSION must be a valid Kubernetes minor version, or `latest`.
    pod-security.kubernetes.io/<MODE>-version: <VERSION>
```

```sh
kubectl apply -f ns.yaml
kubectl apply -f deployment.yaml
```
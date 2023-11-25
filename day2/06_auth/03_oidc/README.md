## OIDC auth
Why do we use OIDC?

```sh
kubectl oidc-login setup \
  --oidc-issuer-url=https://accounts.google.com \
  --oidc-client-id=452556527381-p2l78q08vr0cn67vit17h27a9n1lbgg2.apps.googleusercontent.com \
  --oidc-client-secret=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 \
  --oidc-extra-scope=email
```

Lunch Kind
```sh
kind create cluster --config ./kind.yaml --name workshop
```

Have fun...

## Useful Links

* [kubelogin](https://github.com/int128/kubelogin)
* [dex](https://dexidp.io/docs/kubernetes/)
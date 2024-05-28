As next steps, we will install [KEDA]() and [http-add-on]()

```plain
helm repo add kedacore https://kedacore.github.io/charts
helm install keda kedacore/keda --namespace keda --create-namespace
helm install http-add-on kedacore/keda-add-ons-http --namespace keda
```{{exec}}

Wait for the KEDA http-add-on to be ready
```plain
kubectl wait --for=condition=Available --namespace keda deployment/keda-add-ons-http-controller-manager --timeout=5m
```{{exec}}

TODO: describe KEDA a bit

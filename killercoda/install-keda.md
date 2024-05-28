As next steps, we will install [KEDA]() and [http-add-on]()

Add KEDA charts to helm
```plain
helm repo add kedacore https://kedacore.github.io/charts
```{{exec}}

Install KEDA
```plain
helm install keda kedacore/keda --namespace keda --create-namespace
```{{exec}}

Install trimmed down http-add-on so it fits on the Killercoda resource limitted cluster
```plain
helm install http-add-on kedacore/keda-add-ons-http --namespace keda \
  --set interceptor.replicas.min=1 \
  --set scaler.replicas=1 \
  --set interceptor.resources=null \
  --set operator.resources=null \
  --set scaler.resources=null
```{{exec}}

Wait for the KEDA http-add-on to be ready
```plain
kubectl wait --for=condition=Available --namespace keda deployment/keda-add-ons-http-controller-manager --timeout=5m
```{{exec}}

TODO: describe KEDA a bit

As next steps, we will install [KEDA]() and [http-add-on]()

metrics server as prerequisite
```bash
helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server
helm install metrics-server metrics-server/metrics-server \
  --set args=--kubelet-insecure-tls
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
```{{exec}}

Add KEDA charts to helm, install KEDA and install http-add-on, slightly trimmed down so it all can fit in Killercoda cluster
```bash
helm repo add kedacore https://kedacore.github.io/charts
helm install keda kedacore/keda --namespace keda --create-namespace
helm install http-add-on kedacore/keda-add-ons-http --namespace keda \
  --set interceptor.replicas.min=1 \
  --set scaler.replicas=1 \
  --set interceptor.resources=null \
  --set operator.resources=null \
  --set scaler.resources=null
```{{exec}}


Wait for the KEDA and http-add-on to be ready
```bash
kubectl wait --for=condition=Available --namespace keda deployment/keda-admission-webhooks --timeout=5m
kubectl wait --for=condition=Available --namespace keda deployment/keda-add-ons-http-controller-manager --timeout=5m
```{{exec}}

TODO: describe KEDA a bit

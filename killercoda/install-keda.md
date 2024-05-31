### Step 1: Install Metrics Server
KEDA for CPU and memory metrics uses [**metrics-server**](https://github.com/kubernetes-sigs/metrics-server), so let's install this prerequisite first.
```bash
helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server
helm install metrics-server metrics-server/metrics-server --set args={--kubelet-insecure-tls} --namespace kube-system
```{{exec}}

When it becomes available, we can start querying live CPU and memory metrics through `kube-api`{{}}.
```bash
kubectl wait --for=condition=Available --namespace kube-system deployment/metrics-server --timeout=5m
```{{exec}}

There are convenience commands baked into `kubectl`{{}} for looking at these metrics for `Nodes`{{}} as well as `Pods`{{}}
```bash
kubectl top nodes
```{{exec}}
```bash
kubectl top pods -n kube-system
```{{exec}}

But it could be handy to know how to get the raw metrics too with `kubectl get --raw`{{}}, we will use this later to explore KEDA and http-add-on metrics. There are two registered metrics at the moment in `kube-api`{{}}.

There is only one metrics related API group registered at the moment, this one is served by `kube-system/metrics-server`{{}} we just deployed
```bash
kubectl get apiservices.apiregistration.k8s.io | grep metrics
```{{exec}}

It contains `Pod` and `Node` metrics
```bash
kubectl api-resources | grep metrics
```{{exec}}

We can explore that further with following set of commands
```bash
kubectl get --raw "/apis/metrics.k8s.io/v1beta1" | jq '.'
```{{exec}}
```bash
kubectl get --raw "/apis/metrics.k8s.io/v1beta1/nodes" | jq '.'
```{{exec}}
```bash
kubectl get --raw "/apis/metrics.k8s.io/v1beta1/pods" | \
  jq --raw-output '.items[] | .metadata.namespace + " " + .metadata.name + " " + .containers[].usage.memory' | \
  column -t
```{{exec}}

### Step 2: Install KEDA and http-add-on
Now we are finally ready to install [**KEDA**](https://keda.sh/) and its [**http-add-on**](https://github.com/kedacore/http-add-on). We will slightly simplify the http-add-on deployment by reducing required resources so it all can all fit in this Killercoda cluster. In a production grade environment, you do want to run http-add-on components in HA mode and ensure sufficient CPU and memory allocation because network traffic for the autoscaled applications will flow through the `interceptor`{{}}, but here we can cut some corners.
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


Let's wait for the KEDA and http-add-on to be ready
```bash
kubectl wait --for=condition=Available --namespace keda deployment/keda-admission-webhooks --timeout=5m
kubectl wait --for=condition=Available --namespace keda deployment/keda-add-ons-http-controller-manager --timeout=5m
```{{exec}}

And we can take a look at healthy, operational KEDA deployment.
```bash
kubectl get deployment --namespace keda
```{{exec}}

This is the `interceptor`{{}} cluster local `Service`{{}} our applications may use for autoscaling based on traffic load.
```bash
kubectl get service --namespace keda keda-add-ons-http-interceptor-proxy
```{{exec}}

Now when we look at registered API groups, there is additional `v1beta1.external.metrics.k8s.io`{{}} group served by KEDA `keda/keda-operator-metrics-apiserver`{{}}
```bash
kubectl get apiservices.apiregistration.k8s.io | grep metrics
```{{exec}}

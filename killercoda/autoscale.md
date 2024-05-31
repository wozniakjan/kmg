### Step 1: Configure `HTTPScaledObjects` for Application Versions
To start autoscaling based on HTTP load using KEDA http-add-on, there are few steps you as a application developer need to take.

`HTTPScaledObject`{{}} for application version `app-1`{{}} tells  KEDA to start autoscaling this particular deployment of our application, so as soon as this object is created in `kube-api`{{}}, KEDA will scale down the pods to 0.
```yaml
cat << 'EOF' | kubectl apply -f -
kind: HTTPScaledObject
apiVersion: http.keda.sh/v1alpha1
metadata:
  name: app-1
spec:
  hosts:
    - app-1
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: app-1
    service: app-1
    port: 8080
  replicas:
    min: 0
    max: 10
  scalingMetric:
    requestRate:
      targetValue: 2
  scaledownPeriod: 5
EOF
```{{exec}}

Similarly `HTTPScaledObject`{{}} for application version `app-2`{{}}. Both of these resources tell `interceptor`{{}} where to send the packets next, how quickly to scale up and how quickly to scale back down.
```yaml
cat << 'EOF' | kubectl apply -f -
kind: HTTPScaledObject
apiVersion: http.keda.sh/v1alpha1
metadata:
  name: app-2
spec:
  hosts:
    - app-2
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: app-2
    service: app-2
    port: 8080
  replicas:
    min: 0
    max: 10
  scalingMetric:
    requestRate:
      targetValue: 2
  scaledownPeriod: 5
EOF
```{{exec}}

### Step 2: Re-route Application Traffic to `interceptor`{{}}
GatewayAPI has this useful feature called `ReferenceGrant`{{}}, which allows referencing services from routes in a different `Namespace`{{}}. With `Ingress`{{}}, we wouldn't have that luxury and we would either need `ExternalName`{{}} service or custom reverse proxy as a workaround.

```yaml
cat << 'EOF' | kubectl apply -f -
apiVersion: gateway.networking.k8s.io/v1beta1
kind: ReferenceGrant
metadata:
  name: app
  namespace: keda
spec:
  from:
  - group: gateway.networking.k8s.io
    kind: HTTPRoute
    namespace: default
  to:
  - group: ""
    kind: Service
    name: keda-add-on-http-interceptor-proxy
EOF
```{{exec}}

Then we have to reconfigure the `HTTPRoute`{{}} to route the traffic through KEDA interceptor

```yaml
cat << 'EOF' | kubectl apply -f -
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: app
spec:
  hostnames:
  - keda-meets-gw.com
  parentRefs:
  - kind: Gateway
    namespace: envoy-gateway-system
    name: eg
  rules:
  - backendRefs:
    - kind: Service
      name: keda-add-on-http-interceptor-proxy 
      namespace: keda
      port: 8080
      weight: 1
      filters: 
      - type: RequestHeaderModifier
        requestHeaderModifier:
          set:
          - name: x-keda-http-addon
            value: app-1
    - kind: Service
      name: keda-add-on-http-interceptor-proxy 
      namespace: keda
      port: 8080
      weight: 1
      filters: 
      - type: RequestHeaderModifier
        requestHeaderModifier:
          set:
          - name: x-keda-http-addon
            value: app-2
    matches:
    - path:
        type: PathPrefix
        value: /
EOF
kubectl apply -f /configs/envoy.yaml
```{{exec}}

To highlight what has changed, the `backendRefs`{{}} are no longer the `app-1`{{}} and `app-2`{{}} services, but both point to the `keda-add-on-http-interceptor-proxy`{{}} and there are HTTP header modifiers for each `backendRef`{{}}.

> Because both versions would now have the same `hostname`{{}}, same `port`{{}} and same `backendRef`{{}}, we need to somehow distinguish what version of the application should be forwarded the request. The `HTTPRoute`{{}} resource supports various modifying filters as part of the `rule`{{}} and some implementations also support these filters per `backendRef`{{}}. This is exactly what we will be using with adding custom header `x-keda-http-addon: app-1`{{}} or `x-keda-http-addon: app-2`{{}}. Because the `HTTPScaledObject`{{}} knows how to route by `hostname`{{}} but not how by HTTP headers, and at the time of writing this, Envoy Gateway doesn't support [`urlRewrite`{{}} filter directly on `backendRef`{{}}](https://gateway-api.sigs.k8s.io/reference/spec/#gateway.networking.k8s.io/v1.HTTPURLRewriteFilter) we need one more intermediary step to translate the custom headers to URL rewrite rule. If you are curious, check out the file under `/configs/envoy.yaml`{{}}.

Now let's generate some load, the first request for each application version will experience cold start and the initial response time will be slower, that is when KEDA interceptor caches the request and waits for the application to become ready to serve the traffic. Then the interceptor turns into simple reverse proxy and its impact on traffic speed reduces.
```bash
/scripts/curl_load.sh
```{{exec}}

You can stop the `curl_load.sh` by
```
# ctrl+c
```{{exec interrupt}}

We can play around with the traffic shaping, instead of 50-50 split, we can route 90% to `app-1`{{}} and only 10% to `app-2`{{}}
```bash
kubectl patch httproute app -n default --type=json -p='[{"op": "replace", "path": "/spec/rules/0/backendRefs/0/weight", "value": 9}]'
```{{exec}}

Soon we should start observing how KEDA scales up the busy version `app-1`{{}} and scale down the not-so-busy `app-2`{{}}. Check out the `watch_app.sh`{{}} script in case you have killed it already.
```bash
/scripts/watch_app.sh
```{{exec}}

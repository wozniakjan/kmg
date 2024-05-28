Start autoscaling based on HTTP load using KEDA http-add-on.

`HTTPScaledObject`{{}} for application version `1`{{}}
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
      targetValue: 1
  scaledownPeriod: 1
EOF
```{{exec}}

`HTTPScaledObject`{{}} for application version `2`{{}}
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
      targetValue: 1
  scaledownPeriod: 1
```{{exec}}

GatewayAPI `ReferenceGrant`{{}} to allow referencing services and routes in a different `Namespace`{{}}
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

Then reconfigure the `HTTPRoute`{{}} to route traffic through KEDA interceptor
```yaml
cat << 'EOF' | kubectl apply --server-side -f -
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: app
spec:
  rules:
  - backendRefs:
    - kind: Service
      name: keda-add-on-http-interceptor-proxy 
      namespace: keda
      filters: 
      - type: RequestHeaderModifier
        requestHeaderModifier:
          set:
          - name: x-keda-http-addon
            value: app-1
    - kind: Service
      name: keda-add-on-http-interceptor-proxy 
      namespace: keda
      filters: 
      - type: RequestHeaderModifier
        requestHeaderModifier:
          set:
          - name: x-keda-http-addon
            value: app-2
EOF
```{{exec}}

Generate some load:
```bash
/scripts/curl_load.sh
```{{exec}}

You can stop the `curl_load.sh` by
```
# ctrl+c
```{{exec interrupt}}

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

Generate some load:
```bash
/scripts/curl_load.sh
```{{exec}}

You can stop the `curl_load.sh` by
```
# ctrl+c
```{{exec interrupt}}

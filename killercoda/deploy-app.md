TODO: link to source code

Deploy our sample application, first version `1`{{}}
```yaml
cat << 'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app-1
spec:
  selector:
    matchLabels:
      app: app-1
  template:
    metadata:
      labels:
        app: app-1
    spec:
      containers:
        - name: mycontainer
          image: wozniakjan/simple-http
          env:
            - name: POD_IP
              valueFrom:
                fieldRef:
                  fieldPath: status.podIP
            - name: VERSION
              value: "1"
EOF
```{{exec}}

Expose as simple `Service`{{}}
```yaml
cat << 'EOF' | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: app-1
spec:
  ports:
  - port: 8080
    protocol: TCP
    targetPort: 8080
  selector:
    app: app-1
  type: ClusterIP
EOF
```{{exec}}

Same with version `2`{{}} of the application
```yaml
cat << 'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app-2
spec:
  selector:
    matchLabels:
      app: app-2
  template:
    metadata:
      labels:
        app: app-2
    spec:
      containers:
        - name: mycontainer
          image: wozniakjan/simple-http
          imagePullPolicy: Always
          env:
            - name: POD_IP
              valueFrom:
                fieldRef:
                  fieldPath: status.podIP
            - name: VERSION
              value: "2"
EOF
```{{exec}}

`Service`{{}}
```yaml
cat << 'EOF' | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: app-2
spec:
  ports:
  - port: 8080
    protocol: TCP
    targetPort: 8080
  selector:
    app: app-2
  type: ClusterIP
EOF
```{{exec}}

Expose the application, both versions, loadbalancing 50% of the requests round-robin style

Then the `HTTPRoute`{{}} to configure Envoy Gateway to route requests with hostname `keda-meets-gw.com`{{}} to our application.
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
      name: app-1
      port: 8080
      weight: 1
    - kind: Service
      name: app-2
      port: 8080
      weight: 1
    matches:
    - path:
        type: PathPrefix
        value: /
EOF
```{{exec}}

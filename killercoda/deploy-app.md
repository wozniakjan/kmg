### Step 1: Deploy Application version 1

Now we are going to create some workload. As a foundation, we will use this embarrasingly trivial [HTTP server](https://github.com/wozniakjan/kmg/tree/main/app/main.go).
We will `Deployment`{{}} with a name `app-1`{{}}.
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

Next we will expose it as simple `Service`{{}} called also `app-1`{{}}
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

### Step 2: Deploy Application version 2

We are going to deploy the same application as a different version, and call it `app-2`{{}}
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

Also exposed with a `Service`{{}} called `app-2`{{}}
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

### Step 3: Create `HTTPRoute`
To expose "externally" both versions `app-1`{{}} and `app-2`{{}} as a single application, we are going to use `HTTPRoute`{{}}. The traffic betwen the versions will be loadbalanced by the
Envoy Gateway and requests will be split 50% round-robin style. The hostname for our application is `keda-meets-gw.com`{{}} but there is no DNS record attached to the app, so we will
just pretend everything is fine with `host: keda-meets-gw.com`{{}} header for our HTTP requests but hit the Gateway IP address instead.
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

There is a convenience `watch`{{}} script that enhances the `kubectl`{{}} output to make it easier to see
running replicas of each application version.
```bash
/scripts/watch_app.sh
```{{exec}}

To stop the script, you can just hit
```bash
# ctrl+c
```{{exec interrupt}}

Let's try to access our app over HTTP on `/`{{}}.
```bash
GATEWAY_IP=$(kubectl get gateway -n envoy-gateway-system -o json eg | jq --raw-output '.status.addresses[0].value')
curl -v -H "host: keda-meets-gw.com" http://"$GATEWAY_IP"
```{{exec}}

There are also two scripts that will help us generate some load and visualize responses a bit nicer. 
For a single batch of 10 requests
```bash
/scripts/curl_batch.sh
```{{exec}}

For running the requests in batches periodically
```bash
/scripts/curl_load.sh
```{{exec}}

And here too, to stop the script, you can just hit
```bash
# ctrl+c
```{{exec interrupt}}

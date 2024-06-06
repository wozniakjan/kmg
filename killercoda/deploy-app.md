### Step 1: Deploy `blue`{{}} App

Now we are going to create some workload. As a foundation, we will use this embarrasingly trivial [HTTP server](https://github.com/wozniakjan/kmg/tree/main/app/main.go).
We will `Deployment`{{}} with a name `blue`{{}}.
```yaml
cat << 'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: blue
spec:
  selector:
    matchLabels:
      app: blue
  template:
    metadata:
      labels:
        app: blue
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
              value: blue
EOF
```{{exec}}

Next we will expose it as simple `Service`{{}} called also `blue`{{}}
```yaml
cat << 'EOF' | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: blue
spec:
  ports:
  - port: 8080
    protocol: TCP
    targetPort: 8080
  selector:
    app: blue
  type: ClusterIP
EOF
```{{exec}}

### Step 2: Deploy `prpl`{{}} App 

We are going to deploy the same application as a different version, and call it `prpl`{{}}
```yaml
cat << 'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: prpl
spec:
  selector:
    matchLabels:
      app: prpl
  template:
    metadata:
      labels:
        app: prpl
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
              value: prpl
EOF
```{{exec}}

Also exposed with a `Service`{{}} called `prpl`{{}}
```yaml
cat << 'EOF' | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: prpl
spec:
  ports:
  - port: 8080
    protocol: TCP
    targetPort: 8080
  selector:
    app: prpl
  type: ClusterIP
EOF
```{{exec}}

### Step 3: Create `HTTPRoute`
To expose "externally" both versions `blue`{{}} and `prpl`{{}} as a single application, we are going to use `HTTPRoute`{{}}. The traffic betwen the versions will be loadbalanced by the
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
      name: blue
      port: 8080
      weight: 1
    - kind: Service
      name: prpl
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

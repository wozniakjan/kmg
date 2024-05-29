Install **MetalLB** to allow GatewayAPI *external IP*. It actually won't be entirely public IP in a sense that you can reach
it throug internet, just an IP that is exposed outside of the kubernetes cluster to the terminal of Killercoda. This is necessary
for the successful GatewayAPI configuration.
```bash
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.14.5/config/manifests/metallb-native.yaml
```{{exec}}

Wait for MetalLB controller to be ready
```bash
kubectl wait --for=condition=Available --namespace metallb-system deployment/controller --timeout=5m
```{{exec}}

Configure MetalLB with an IPv4 range valid for Killercoda scenarios
```yaml
cat <<EOF | kubectl apply -f -
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: kubelb
  namespace: metallb-system
spec:
  addresses:
  - 172.30.255.200-172.30.255.250
---
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: kubelb
  namespace: metallb-system
EOF
```{{exec}}

Install **Envoy Gateway** as a GatewayAPI implementation of choice. We are going to be using the [nightly build](https://github.com/envoyproxy/gateway/releases/tag/latest)
because at the time of writing this, a feature for [advanced filtering](https://github.com/envoyproxy/gateway/pull/3246) has not been released yet.
```bash
helm install eg oci://docker.io/envoyproxy/gateway-helm --version v0.0.0-latest -n envoy-gateway-system --create-namespace
```{{exec}}

Wait for `envoy-gateway` controller to be available
```bash
kubectl wait --for=condition=Available --namespace envoy-gateway-system deployment/envoy-gateway --timeout=5m 
```{{exec}}

Create a `GatewayClass` using `envoy-gateway` as the controller
```yaml
cat << 'EOF' | kubectl apply -f -
apiVersion: gateway.networking.k8s.io/v1
kind: GatewayClass
metadata:
  name: eg
spec:
  controllerName: gateway.envoyproxy.io/gatewayclass-controller
EOF
```{{exec}}

Create a `Gateway` referencing the above created `GatewayClass` so we can attach `HTTPRoutes` and expose applications.
```yaml
cat << 'EOF' | kubectl apply -f -
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: eg
  namespace: envoy-gateway-system
spec:
  gatewayClassName: eg
  listeners:
    - name: http
      protocol: HTTP
      port: 80
      allowedRoutes:
        namespaces: 
          from: All
EOF
```{{exec}}

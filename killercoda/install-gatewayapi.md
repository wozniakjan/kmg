### Step 1: Install and Configure MetalLB

First, we need to install [**MetalLB**](https://metallb.universe.tf/) to allow GatewayAPI get an *external IP*. It actually won't be a public IP in a sense that you can reach
it throug internet, just an IP that is exposed outside of the Kubernetes cluster to the terminal of Killercoda. This is necessary for a successful GatewayAPI configuration.
```bash
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.14.5/config/manifests/metallb-native.yaml
```{{exec}}

We should wait for the MetalLB controller to become ready before we procede with configuration
```bash
kubectl wait --for=condition=Available --namespace metallb-system deployment/controller --timeout=5m
```{{exec}}

And when it's reporting as ready, it's safe to configure it with an IPv4 range valid for Killercoda environments. Each environment receives private `172.30.0.0/16`{{}} subnet
where `172.30.1.2`{{}} is the IP address of the host as well as the Kubernetes control-plane. For the external IPs, we will use IP address pool `172.30.255.200 - 172.30.255.250`{{}}
and [`ARP`{{}} for L2 advertisement](https://en.wikipedia.org/wiki/Address_Resolution_Protocol).

```yaml
cat <<EOF | kubectl apply -f -
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: killercoda
  namespace: metallb-system
spec:
  addresses:
  - 172.30.255.200-172.30.255.250
---
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: killercoda
  namespace: metallb-system
EOF
```{{exec}}

### Step 2: Install and Configure Envoy Gateway

Now we are goint to install [**Envoy Gateway**](https://gateway.envoyproxy.io/) as our GatewayAPI implementation of choice. The GatewayAPI is just a specification + CRDs,
and there are plenty of [implementations](https://gateway.envoyproxy.io/), usually supporting a subset of the specification. Envoy Gateway has graduated to GA and continues to
be actively developed. In this scenario, we are going to be using the [nightly build](https://github.com/envoyproxy/gateway/releases/tag/latest) because at the time of writing this,
a feature for [advanced backend filtering](https://github.com/envoyproxy/gateway/pull/3246) has not been released yet in a official release.
```bash
helm install eg /configs/gateway-helm -n envoy-gateway-system --create-namespace
```{{exec}}

Let's again wait for the `envoy-gateway`{{}} controller to become available
```bash
kubectl wait --for=condition=Available --namespace envoy-gateway-system deployment/envoy-gateway --timeout=5m 
```{{exec}}

And now we can create a `GatewayClass`{{}} using `envoy-gateway`{{}} as the controller, defining a template for the actual gateways.
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

The environment is ready to accept our definition of a first `Gateway`{{}} referencing the above created `GatewayClass`{{}}. This will allow exposing applications outside of the Kubernetes
cluster through attachment of `HTTPRoutes`{{}}. The `Gateway`{{}} has single listener, for `HTTP`{{}} protocol only, on a standard port `80`{{}} and allowing `HTTPRoutes`{{}} created in any `Namespace`{{}}.
Because `Gateways`{{}} are namespaced, without the `allowedRoutes`{{}} section, only `HTTPRoutes`{{}} created in the same `Namespace`{{}} would be accepted.
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

Let's take a quick look at the `Gateway`{{}} status, it should get configured and reconciled by the Envoy Gateway quickly.
```bash
kubectl get gateway -n envoy-gateway-system
```{{exec}}

We can see that it is `Programmed`{{}}, which means there are no issues with the configuration, and has received IP address from MetalLB that can be reached from Killercoda shell.
```bash
GATEWAY_IP=$(kubectl get gateway -n envoy-gateway-system -o json eg | jq --raw-output '.status.addresses[0].value')
curl -v http://"$GATEWAY_IP"
```{{exec}}
Although, there are no routes attached to it yet so it's responding with `404`{{}}.

# Bootstrapping Microservices - Deploy with IaC

This lab takes the existing `video-streaming` app from the previous chapter and deploys it to Kubernetes on AKS. The important part is the delivery path around it: build the container image, push it to Azure Container Registry, let AKS pull that image, and expose the running Pod through a Kubernetes Service.

The deployment flow looks like this:

```txt
Local machine
  -> build Docker image
  -> push image to Azure Container Registry
  -> AKS pulls image from ACR
  -> Kubernetes Deployment runs the Pod
  -> Kubernetes Service exposes the Pod
  -> Browser calls /video
```

## Ch06 — Deploying the video-streaming service to AKS

The first Kubernetes deployment is deliberately small. It only runs the `video-streaming` service and exposes it over HTTP. The goal is to prove the image publishing and Kubernetes deployment path before adding the rest of the microservice system back in.

---

### Building, tagging, and pushing the image

Kubernetes does not build the application image for us. It expects an image that already exists in a registry the cluster can reach.

For this lab, the image is built locally from the production Dockerfile:

```sh
docker image build -t video-streaming:1 --file Dockerfile-prod .
```

That creates a local image named:

```txt
video-streaming:1
```

Before pushing it to Azure Container Registry, the image needs a registry-qualified name. In my case, the registry is:

```txt
bmwdk.azurecr.io
```

So the local image is tagged like this:

```sh
docker image tag video-streaming:1 bmwdk.azurecr.io/video-streaming:1
```

The tag is important because it tells Docker where the image should be pushed. Without the registry prefix, Docker only knows about the local image name. With the registry prefix, the image becomes an ACR image reference:

```txt
bmwdk.azurecr.io/video-streaming:1
```

Then the image can be pushed:

```sh
docker login bmwdk.azurecr.io
docker image push bmwdk.azurecr.io/video-streaming:1
```

The same commands with placeholders are:

```sh
docker image build -t video-streaming:1 --file Dockerfile-prod .
docker image tag video-streaming:1 <registry-url>/video-streaming:1
docker login <registry-url>
docker image push <registry-url>/video-streaming:1
```

At this point, ACR stores the deployable artifact. Kubernetes does not need the source code or Dockerfile; it only needs permission to pull the image.

---

### Connecting AKS to ACR

The deployment manifest references the image in ACR:

```yaml
image: bmwdk.azurecr.io/video-streaming:1
```

That means AKS must be allowed to pull from that registry. One option would be to create Kubernetes image pull secrets manually. For this lab, the cleaner option is to attach the ACR registry to the AKS cluster:

```sh
az aks update \
  --resource-group <resource-group> \
  --name <cluster> \
  --attach-acr <registry>
```

This grants the AKS cluster identity pull access to the container registry.

I can test that connection with:

```sh
az aks check-acr \
  --resource-group <resource-group> \
  --name <cluster> \
  --acr <registry-url>
```

For this lab, that is:

```sh
az aks check-acr \
  --resource-group <resource-group> \
  --name <cluster> \
  --acr bmwdk.azurecr.io
```

The benefit is that the deployment YAML does not need to contain registry credentials. The Pod spec can simply reference the private image, and AKS can authenticate to ACR through Azure-managed permissions.

> So ACR answers: Where is the image stored?
> AKS-to-ACR attachment answers: Is this cluster allowed to pull it?

Together, they let Kubernetes create Pods from private application images without embedding credentials into the deployment config.

---

### What the deployment config provisions

The deployment file lives at:

```txt
video-streaming/scripts/deploy.yaml
```

It provisions two Kubernetes resources:

1. `Deployment` — manages the `video-streaming` Pod.
2. `Service` — exposes the Pod on the network.

The Deployment section looks like this:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: video-streaming
spec:
  replicas: 1
  selector:
    matchLabels:
      app: video-streaming
  template:
    metadata:
      labels:
        app: video-streaming
    spec:
      containers:
        - name: video-streaming
          image: bmwdk.azurecr.io/video-streaming:1
          imagePullPolicy: IfNotPresent
          env:
            - name: PORT
              value: "4000"
```

This tells Kubernetes to keep one `video-streaming` Pod running. If that Pod exits or disappears, the Deployment is responsible for creating a replacement.

The container uses the image that was pushed to ACR:

```yaml
image: bmwdk.azurecr.io/video-streaming:1
```

It also injects the app port as an environment variable:

```yaml
- name: PORT
  value: "4000"
```

So the Node app listens on port `4000` inside the container.

The Service section looks like this:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: video-streaming
spec:
  selector:
    app: video-streaming
  type: LoadBalancer
  ports:
    - protocol: TCP
      port: 80
      targetPort: 4000
```

This creates a stable network entry point for the Pod.

The important connection is the label selector:

```yaml
selector:
  app: video-streaming
```

The Service sends traffic to Pods with this label:

```yaml
labels:
  app: video-streaming
```

That means the Service does not depend on a specific Pod name or Pod IP. It depends on the label. If Kubernetes replaces the Pod, the new Pod gets the same label and the Service can continue routing traffic to it.

---

### How networking works in this deployment

There are three useful network layers in this specific deployment:

```txt
Browser
  -> Azure Load Balancer
    -> Kubernetes Service: video-streaming, port 80
      -> video-streaming Pod, targetPort 4000
        -> Express app, PORT=4000
```

The Service is declared as:

```yaml
type: LoadBalancer
```

On AKS, that asks Azure to provision an external load balancer. Once Azure assigns an external IP, clients can reach the service from outside the cluster.

The port mapping is:

```yaml
port: 80
targetPort: 4000
```

These two values are easy to confuse, but they mean different things:

- `port: 80` is the port exposed by the Kubernetes Service.
- `targetPort: 4000` is the port inside the Pod where the app is listening.

So the browser uses normal HTTP port `80`, while the container keeps running the app on `4000`.

The final request path is:

```txt
http://<external-ip>/video
```

When that request reaches the Azure load balancer, it is forwarded to the Kubernetes Service. The Service then forwards it to a matching `video-streaming` Pod on port `4000`.

This is the Kubernetes version of the same stable-name idea from Docker Compose, but the mechanics are different. Compose used service names inside one Docker network. Kubernetes uses Services, labels, and selectors to create a stable network endpoint in front of replaceable Pods.

---

### Applying the deployment

First, log in to Azure and make sure the correct subscription is active:

```sh
az login
az account show
```

Then configure `kubectl` to talk to the AKS cluster:

```sh
az aks get-credentials --resource-group <resource-group> --name <cluster>
```

I also check the current Kubernetes context before applying anything:

```sh
kubectl config current-context
kubectl config get-contexts
kubectl config use-context <context-name>
```

Then apply the deployment from the `video-streaming` directory:

```sh
kubectl apply -f scripts/deploy.yaml
```

After applying it, these commands are useful for checking what happened:

```sh
kubectl get deployments
kubectl get pods
kubectl get services
```

The expected result is:

1. The Deployment exists.
2. One `video-streaming` Pod is running.
3. The Service has type `LoadBalancer`.
4. The Service eventually receives an external IP.

Once the external IP is available, the app should be reachable at:

```txt
http://<external-ip>/video
```

---

### Troubleshooting: wrong image platform

If the Pod stays in `ImagePullBackOff`, inspect it with:

```sh
kubectl describe pod -l app=video-streaming
```

One failure I hit was:

```txt
Failed to pull image "bmwdk.azurecr.io/video-streaming:1": no match for platform in manifest: not found
```

The AKS-to-ACR permission was not the real problem in that case. The image had been built for the wrong CPU architecture. This can happen when building locally on an Apple Silicon machine, which may produce a `linux/arm64` image, while the AKS node pool expects `linux/amd64`.

The fix is to rebuild and push the image for the AKS node platform explicitly:

```sh
docker buildx build \
  --platform linux/amd64 \
  -t bmwdk.azurecr.io/video-streaming:1 \
  --file Dockerfile-prod \
  --push .
```

After pushing the corrected image, restart the Deployment or delete the failed Pod so Kubernetes pulls the image again:

```sh
kubectl rollout restart deployment/video-streaming
# or
kubectl delete pod -l app=video-streaming
```

Then check the rollout:

```sh
kubectl get pods
kubectl describe pod -l app=video-streaming
```

> [!NOTE]
> This deployment only proves the first AKS path for the existing app: image in ACR, Pod in AKS, and HTTP traffic through a LoadBalancer Service. A fuller production deployment would still need health checks, safer image versioning, config management, secrets, observability, and the rest of the microservices.

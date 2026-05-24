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

## Ch07 - Provision cloud resources with Terraform

Chapter 6 proved the AKS path manually: create Azure resources, push an image to ACR, connect AKS to ACR, and apply a Kubernetes manifest. Chapter 7 moves the Azure infrastructure setup into Terraform.

Because most Terraform mechanics are the same shape as AWS Terraform work — provider config, variables, resources, references, `terraform init`, `plan`, `apply`, and `destroy` — the important Azure-specific learning is not the syntax. The important learning is what becomes automated, what remains manual, and which Azure concepts are different from AWS.

---

### What is automated after this chapter

After this chapter, Terraform owns the Azure infrastructure needed for the first AKS deployment path:

```txt
Terraform apply
  -> creates Azure resource group
  -> creates Azure Container Registry
  -> creates AKS cluster
  -> grants AKS permission to pull from ACR
```

The Terraform configuration lives in:

```txt
infra/tf
```

It describes these resources:

```txt
resource-group.tf         -> Azure resource group
container-registry.tf     -> Azure Container Registry
kubernetes-cluster.tf     -> AKS cluster and ACR pull permission
providers.tf              -> AzureRM provider setup
variables.tf              -> shared app, region, and Kubernetes version inputs
```

The practical improvement is repeatability. Instead of recreating the lab by remembering a sequence of Azure Portal or CLI actions, I can run:

```sh
cd infra/tf
terraform init
terraform plan
terraform apply
```

and get the same infrastructure shape again:

1. A resource group named `bmwdkFlixtube`.
2. An ACR registry with a login server like `bmwdkflixtube.azurecr.io`.
3. An AKS cluster named `bmwdkFlixtube`.
4. An `AcrPull` role assignment that lets AKS pull images from that registry.

Cleanup is automated too:

```sh
terraform destroy
```

That removes the Terraform-managed Azure resources together instead of requiring a manual cleanup checklist across Azure services.

Terraform does **not** deploy the application in this chapter. It prepares the cloud infrastructure that the application deployment depends on. The Docker image build, image push, `kubectl` setup, and Kubernetes manifest apply are still separate steps.

---

### How AKS gets access to ACR

The key authentication problem is:

```txt
AKS needs to pull a private image from ACR.
```

The image lives in Azure Container Registry:

```txt
bmwdkflixtube.azurecr.io/video-streaming:1
```

Kubernetes should not need a registry username and password inside the Deployment manifest. Instead, Azure gives the AKS kubelet identity permission to pull from the registry.

In the manual version from Chapter 6, this was done with Azure CLI:

```sh
az aks update \
  --resource-group <resource-group> \
  --name <cluster> \
  --attach-acr <registry>
```

In the Terraform version, the same relationship is represented explicitly as an Azure role assignment:

```tf
resource "azurerm_role_assignment" "role_assignment" {
  principal_id         = azurerm_kubernetes_cluster.cluster.kubelet_identity[0].object_id
  role_definition_name = "AcrPull"
  scope                = azurerm_container_registry.container_registry.id
}
```

The relationship is:

```txt
AKS kubelet identity
  -> receives AcrPull role
  -> scoped to the ACR registry
  -> can pull private container images
```

That means the Kubernetes Deployment can reference the private image directly:

```yaml
image: bmwdkflixtube.azurecr.io/video-streaming:1
```

and AKS can pull it using Azure identity and RBAC rather than Kubernetes image-pull secrets.

This is the Azure equivalent of wiring runtime infrastructure to an image registry with cloud IAM. The Terraform detail is less important than the idea: the cluster identity must have pull permission on the registry.

---

### What is different from AWS

Most of the Terraform workflow feels familiar if you already use AWS:

```txt
provider config
variables
resources
resource references
terraform plan/apply/destroy
IAM-style permission binding
```

The differences that matter in this lab are Azure-specific platform concepts.

#### Resource groups

Azure resources live inside a **resource group**. The resource group is not just a tag or naming convention; it is a first-class container for related resources.

In this lab, the resource group contains:

```txt
Resource group: bmwdkFlixtube
  -> Azure Container Registry
  -> AKS cluster
  -> related Azure-managed child resources
```

This is different from the usual AWS mental model, where resources are grouped mostly by account, region, VPC, tags, CloudFormation stack, or Terraform state. Azure makes the grouping explicit in the resource model.

That affects both provisioning and cleanup. Creating the resource group gives the lab a parent container. Destroying the Terraform-managed stack removes that container and the resources Terraform placed in it.

#### Resource Provider registrations

Azure services are exposed through **Resource Provider namespaces**. For example:

```txt
Microsoft.ContainerService  -> AKS
Microsoft.ContainerRegistry -> ACR
Microsoft.Web               -> App Service
Microsoft.DBforMySQL        -> Azure Database for MySQL
```

A subscription may need a provider namespace registered before resources from that namespace can be created. That is why Azure Terraform can fail before any actual resource creation if provider registration is blocked or slow.

The failure I hit looked like this:

```txt
Error: Encountered an error whilst ensuring Resource Providers are registered.
...
Provider Name: "Microsoft.Web" ... context canceled
```

The surprising part was that the lab was not trying to create `Microsoft.Web` resources. The AzureRM provider was attempting broad automatic provider registration during startup.

The fix was to disable broad automatic registration:

```tf
provider "azurerm" {
  features {}
  resource_provider_registrations = "none"
}
```

Then, if a specific namespace is actually needed, register only that namespace:

```sh
az provider register --namespace Microsoft.ContainerService
az provider register --namespace Microsoft.ContainerRegistry
```

This is a major Azure difference from AWS. In AWS, you usually assume a service API is available in an account and region if the service exists there and IAM allows it. In Azure, the subscription also has this Resource Provider registration layer.

#### Naming behavior

Azure resources have service-specific naming rules. In this lab, the shared app name is mixed case:

```txt
bmwdkFlixtube
```

but the ACR login server is lowercase:

```txt
bmwdkflixtube.azurecr.io
```

That lowercase registry host is the value Docker and Kubernetes must use when tagging, pushing, and pulling images.

---

### What still requires human intervention

This chapter automates infrastructure creation, but it is not yet a full CI/CD system. I still manually perform the delivery steps around Terraform.

#### Running Terraform

A person still runs:

```sh
terraform init
terraform plan
terraform apply
```

There is no pipeline yet to run plans automatically, capture review approval, apply changes, or store state in a remote backend.

#### Building and pushing the image

After ACR exists, I still build and push the image manually:

```sh
docker login bmwdkflixtube.azurecr.io

docker buildx build \
  --platform linux/amd64 \
  -t bmwdkflixtube.azurecr.io/video-streaming:1 \
  --file Dockerfile-prod \
  --push .
```

The `--platform linux/amd64` flag still matters when building on Apple Silicon, because the AKS node expects an amd64-compatible image.

#### Connecting local kubectl to AKS

Terraform creates the cluster, but my local machine still needs Kubernetes credentials:

```sh
az aks get-credentials \
  --resource-group bmwdkFlixtube \
  --name bmwdkFlixtube

kubectl config use-context bmwdkFlixtube
```

#### Applying the Kubernetes manifest

The Kubernetes Deployment and Service are still applied manually:

```sh
cd infra/k8s
kubectl apply -f deploy.yaml
```

The manifest points at the Terraform-managed registry:

```yaml
image: bmwdkflixtube.azurecr.io/video-streaming:1
```

#### Checking the rollout

A person still checks whether the app is healthy and reachable:

```sh
kubectl get deployments
kubectl get pods
kubectl get services
```

Once the `LoadBalancer` Service receives an external IP, the app should be reachable at:

```txt
http://<external-ip>/video
```

#### Deciding when to clean up

A person still decides when to remove runtime and cloud resources:

```sh
cd infra/k8s
kubectl delete -f deploy.yaml

cd ../tf
terraform destroy
```

---

### End state of the chapter

After this chapter, the lab has automated the Azure infrastructure layer:

```txt
Terraform-managed:
  - resource group
  - container registry
  - AKS cluster
  - AKS-to-ACR pull permission

Still manual:
  - Terraform execution workflow
  - Docker image build and push
  - kubectl credential setup
  - Kubernetes manifest apply
  - rollout verification
  - cleanup decision
```

The most important progress is repeatability. The lab is not production-ready yet, but ACR, AKS, and the pull permission are now described as code. The next improvement would be CI/CD: build the image on code changes, tag it safely, push it to ACR, run Terraform with review gates, deploy the Kubernetes manifest, and report rollout status automatically.

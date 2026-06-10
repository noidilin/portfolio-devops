# Bootstrapping Microservices - Continuous Delivery with GitHub Actions

This lab takes the deployment path from the previous chapter and moves it into GitHub Actions. The app is still deliberately small: only the `video-streaming` service is deployed to Kubernetes. The important progress is not the number of services yet; it is making the build, publish, and deploy path repeatable.

The CI/CD flow looks like this:

```txt
Push to GitHub
  -> GitHub Actions checks out the repo
  -> Docker builds the video-streaming image
  -> Docker pushes the image to Azure Container Registry
  -> Kustomize renders the Kubernetes deployment
  -> kubectl applies the rendered config to AKS
  -> Kubernetes rolls out the new Pod
```

This continues the path from the IaC chapter:

```txt
Terraform-created ACR
  -> stores the image
Terraform-created AKS
  -> pulls the image
Kustomize-rendered Kubernetes config
  -> tells AKS which app version to run
```

## Ch08 — Deploying through CI/CD

The first CI/CD version is intentionally narrow. It does not try to deploy the full microservice system yet. It only proves that a commit can become a running Kubernetes deployment without manually running Docker and `kubectl` from a local machine.

The workflow is defined in:

```txt
.github/workflows/bmwdk-ch08-cicd.yaml
```

It runs when the deployment workflow, the `video-streaming` service, or the Kubernetes deployment files change. It can also be started manually from the GitHub Actions UI.

The workflow-level environment values are:

```yaml
IMAGE_NAME: video-streaming
VERSION: ${{ github.sha }}
CONTAINER_REGISTRY: ${{ secrets.CONTAINER_REGISTRY }}
```

The image tag comes from the Git commit SHA. That means each run publishes a specific image version:

```txt
<registry>/video-streaming:<commit-sha>
```

Using the commit SHA is useful because the deployment can be traced back to the exact source revision that produced it.

---

### Prerequisites for this lab

This CI/CD workflow assumes the Azure infrastructure already exists. It does not create ACR or AKS itself.

Before running the workflow, the Terraform project from the previous chapter needs to be applied from:

```txt
labs/40-microservices/infra/tf/
```

That Terraform stack creates:

```txt
Resource Group
  -> contains the lab resources

Azure Container Registry
  -> stores the video-streaming image

Azure Kubernetes Service
  -> runs the video-streaming Pod

AcrPull role assignment
  -> lets AKS pull images from ACR
```

The workflow also needs GitHub repository secrets:

```txt
CONTAINER_REGISTRY  # example: bmwdkflixtube.azurecr.io
REGISTRY_UN         # registry username
REGISTRY_PW         # registry password
KUBE_CONFIG         # base64-encoded kubeconfig for the AKS cluster
```

The setup order is therefore:

```txt
1. Run Terraform
   -> create ACR, AKS, and the pull permission

2. Configure GitHub secrets
   -> give the workflow access to ACR and AKS

3. Run the CI/CD workflow
   -> build, push, and deploy video-streaming
```

This keeps the responsibility split clear. Terraform provisions cloud infrastructure. The CI/CD workflow deploys the application onto that infrastructure.

#### AKS KUBE_CONFIG

Generate from Azure CLI, and encode it with base64

```sh
az aks get-credentials \
  --resource-group <resource-group-name> \
  --name <aks-cluster-name> \
  --file ./kubeconfig

base64 -i ./kubeconfig | pbcopy
```

---

### Why the textbook `envsubst` approach was replaced

The textbook deployment uses a Kubernetes YAML file with shell variables in it:

```yaml
image: $CONTAINER_REGISTRY/video-streaming:$VERSION
```

Then it expands the file with:

```sh
envsubst < deploy.yaml | kubectl apply -f -
```

That is a good teaching step because it makes the moving parts visible. The registry and image version are passed in from the shell, and the final YAML is sent to Kubernetes.

The problem is that `envsubst` is only text replacement. It does not know that the value being changed is a Kubernetes image field. It does not know about environments, overlays, objects, patches, or deployment intent. It only sees strings.

For one service, this is manageable:

```txt
CONTAINER_REGISTRY
VERSION
```

But the deployment will not stay that small. As the microservice system grows, each environment may need different values:

```txt
image tags
replica counts
resource requests and limits
service types
ingress hosts
ConfigMaps
Secret references
namespaces
feature-specific patches
```

With plain shell substitution, the manifest tends to go in one of two directions:

```txt
Option 1: one big YAML template
  -> many $VARIABLE placeholders
  -> hard to see what Kubernetes will actually receive

Option 2: copied YAML per environment
  -> dev, staging, and prod drift from each other
  -> the same Deployment is repeated with small differences
```

Both options become fragile. A shell template is fine for a lab-sized deployment, but it is not a great structure for a growing Kubernetes app.

---

### Using Kustomize overlays instead

The deployment config now uses Kustomize:

```txt
labs/40-microservices/infra/k8s/
  base/
    deployment.yaml
    service.yaml
    kustomization.yaml
  overlays/
    dev/
      kustomization.yaml
    prod/
      kustomization.yaml
```

The base directory describes the common application resources:

```txt
Deployment/video-streaming
Service/video-streaming
```

The overlay directory describes environment-specific changes. In the current lab, the overlay is mostly used as the place where the image can be replaced during deployment.

The base Deployment keeps a simple image name:

```yaml
image: video-streaming:latest
```

During deployment, the script replaces that image reference with the image built by CI:

```sh
kustomize edit set image video-streaming=$CONTAINER_REGISTRY/video-streaming:$VERSION
```

So the rendered Deployment sent to Kubernetes uses an image like:

```txt
bmwdkflixtube.azurecr.io/video-streaming:<commit-sha>
```

This is a better fit for the portfolio repo because the deployment now has a structure that can grow with the app:

```txt
base
  -> shared Kubernetes resources

overlays/dev
  -> dev-specific changes

overlays/prod
  -> prod-specific changes
```

When more services are added, they can be added to the same model without turning the deployment into one large shell template.

Kustomize also does not conflict with Terraform. They operate at different layers:

```txt
Terraform owns Azure infrastructure:
  - resource group
  - ACR
  - AKS
  - IAM / AcrPull

Kustomize owns Kubernetes app config:
  - Deployments
  - Services
  - app image versions
  - future app ConfigMaps or Secret references
```

The important rule is that both tools should not manage the same Kubernetes object. If Kustomize owns `Deployment/video-streaming`, Terraform should not also create that Deployment.

---

### Building and publishing the image

The workflow uses Docker actions instead of the old root-level scripts from the textbook example.

The build context is the actual service directory in this repo:

```txt
labs/40-microservices/video-streaming
```

The production Dockerfile is:

```txt
labs/40-microservices/video-streaming/Dockerfile-prod
```

The workflow builds and pushes this image:

```txt
${CONTAINER_REGISTRY}/video-streaming:${VERSION}
```

For example:

```txt
bmwdkflixtube.azurecr.io/video-streaming:6d8e2c1...
```

At this point, ACR has the deployable artifact. The next step is only about telling AKS to run that artifact.

---

### Deploying with `deploy.sh`

The deployment wrapper is:

```txt
labs/40-microservices/infra/scripts/deploy.sh
```

The script expects the workflow to provide:

```txt
CONTAINER_REGISTRY
VERSION
```

Those two values are combined into the image that Kubernetes should run:

```sh
IMAGE="$CONTAINER_REGISTRY/video-streaming:$VERSION"
```

The script also supports `KUSTOMIZE_OVERLAY`. If that variable is not set, it deploys the production overlay:

```txt
infra/k8s/overlays/prod
```

The interesting part is how the script handles `kustomize edit`. That command updates `kustomization.yaml`, so running it directly against the repository would dirty the working tree. The script avoids that by copying the Kubernetes config to a temporary directory first:

```sh
WORK_DIR=$(mktemp -d)
cp -R "$SCRIPT_DIR/../k8s" "$WORK_DIR/k8s"
```

Then it edits only the temporary copy:

```sh
kustomize edit set image "video-streaming=$IMAGE"
```

This gives the deployment the exact image tag from the current workflow run, while keeping the repo files stable.

After that, the script renders and applies the overlay:

```sh
kustomize build . | kubectl apply -f -
```

Finally, it waits for Kubernetes to report that the rollout completed:

```sh
kubectl rollout status deployment/video-streaming
```

If the new Pod cannot start, the pipeline fails instead of silently reporting success.

---

### Deleting the app with `delete.sh`

The cleanup wrapper is:

```txt
labs/40-microservices/infra/scripts/delete.sh
```

It uses the same overlay selection as `deploy.sh`: by default it targets the production overlay, and `KUSTOMIZE_OVERLAY` can point it somewhere else.

It does not need `CONTAINER_REGISTRY` or `VERSION`, because deleting the app does not depend on which image tag was deployed.

The delete command is:

```sh
kubectl delete -k "$OVERLAY"
```

The `-k` flag tells `kubectl` to process the Kustomize overlay and delete the resources described by it.

In the current lab, that deletes:

```txt
Deployment/video-streaming
Service/video-streaming
```

It leaves the Terraform-managed Azure resources alone. ACR, AKS, and the resource group still exist after this script runs.

---

### Current state

At the end of this step, the repo has a CI/CD path for one service:

```txt
video-streaming source
  -> Docker image
  -> Azure Container Registry
  -> Kustomize overlay
  -> AKS Deployment and Service
```

The full Compose system is not deployed to Kubernetes yet:

```txt
video-streaming
history
recommendations
mongodb
rabbitmq
azure-storage
```

That is intentional. The current lab proves the deployment path with one service first. Once this path is reliable, the other services can be moved into the same Kubernetes base/overlay structure.

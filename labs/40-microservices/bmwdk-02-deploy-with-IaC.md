# Bootstrapping Microservices - Deploy with IaC

```sh
az login
az account show # make sure in correct account
# setup k8s context
az aks get-credentials --resource-group <resource-group> --name <cluster>

# examine k8s context
kubectl config current-context
kubectl config get-contexts
kubectl config use-context <context-name>

# build docker image
docker image build -t video-streaming:1 --file Dockerfile-prod .
dokcer tag video-streaming:1 <registry-url>/video-streaming:1
docker login <registry-url>
docker push <registry-url>/video-streaming:1
```

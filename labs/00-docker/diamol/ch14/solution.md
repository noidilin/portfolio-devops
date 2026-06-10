# Solution

## Setup Infrastructure

```sh
# reusable env var
$REGION='us-east1'
$PROJECT='diamol14lab'
$REGISTRY="${REGION}-docker.pkg.dev"

# create a new project
gcloud projects create $PROJECT
# link your billing account:
gcloud billing projects link $PROJECT --billing-account=<your-billing-account-id>

# make sure Artifact Registry, Cloud Run and Cloud Build services are enabled:
gcloud services enable artifactregistry.googleapis.com cloudbuild.googleapis.com run.googleapis.com --project=$PROJECT

# create repo in the registry
gcloud artifacts repositories create pi --repository-format=docker --project=$PROJECT --location=$REGION
```

## Build source code

```sh
# switch to the source code repo and submit the build:
cd exercises/pi-web
# build image with google cloud based on local source code and Dockerfile
gcloud builds submit --tag="$REGISTRY/$PROJECT/pi/web" --project=$PROJECT 
# provision service with resources (requirement asks for more CPU)
gcloud run deploy pi-web --image="$REGISTRY/$PROJECT/pi/web" --cpu=4 --memory=4Gi --port=80 --allow-unauthenticated --project=$PROJECT --region=$REGION 

# delete projects after the lab finished
gcloud projects delete $PROJECT --quiet
```


# Note

## Overview

Docker Compose is being used for two related purposes

1. Runtime definition: services, ports networks, dependencies
2. Image naming source of truth: build tags, staging tags, release tags

Then, the CI/CD scripts combine different Compose image overlays depending on the pipeline stage, so the same three-service app can be built, tested, promoted, and deployed without duplicating service definitions everywhere.

The GitHub Actions workflows decide when each script runs, on which OS, and with which environment variables.

## Tool integration

- Compose:
  - Base: define app services, ports, dependencies, network
  - Build: define build context, and build args
  - Tag: define image names for build, staging, release
- PowerShell scripts: run build, push tag, smoke test, deploy commands
- Docker Registry: store promoted image tags
- GitHub Actions: trigger jobs, choose runner OS, set env vars, login to registry
- Helm: deploys final release images to Kubernetes

---

## Compose files

### Docker Compose Flow

1. build/test each component
2. build real images using `docker-compose-build.yml`
3. tag them with unique build-number tags (`docker-compose-build-tags.yml`)
   - push those unique image
4. re-tag selected build as staging (`docker-compose-staging-tags.yml`)
   - smoke test staging
5. re-tag staging as release (`docker-compose-release-tags.yml`)
   - deploy release images with Helm

### Build app components

- `docker-compose`: app topology for services, ports, notwork, dependencies
- `docker-compose-build`: build contexts and args

1. read merged compose config
2. finds services with `build`
3. runs docker build using each service's `build.context`
4. passes `build.args` into Dockerfile
5. tags the resulting image using the service's `image` value

```sh
# image tagged as: ch16-access-log:2e
docker compose `
  -f docker-compose.yml `
  -f docker-compose-build.yml `
  build

# image tagged as: docker.io/myuser/myrepo/staging/ch16-access-log:e-linux-amd64-123
docker compose `
  -f docker-compose.yml `
  -f docker-compose-build.yml `
  -f docker-compose-build-tags.yml `
  build
```

### Tag based on progress

- `docker-compose-build-tags`: use unique CI build tags
- `docker-compose-staging-tags`: use stable staging tags
- `docker-compose-release-tags`: use stable release tags

---

## CICD Scripts

`set-vars.ps1`:

- define compose file groups
- sets platform variables that used in image tags
- env: `DOCKER_BUILD_OS`, `DOCKER_BUILD_CPU`, `OS_VERSION_TAG`
  - `2e-linux-amd64-123`
  - `2e-windows-ltsc2022-amd64-123`

### Scripts Flow

1. `build.ps1`: build each component's Dockerfile test target directly with `docker build`
2. `build-push.ps1`: builds real images using build-number tags, and pushes them to registry (env: `BUILD_ID`, `COMMIT_SHA`)
3. `tag-push.ps1 -From build -To staging` retag unique build images as stable staging images
4. `smoke-test.ps1`: run staging images with docker compose, and check API + Web endpoints
5. `tag-push.ps1 -From staging -To release`: retag stable staging images as stable release images
6. `deploy.ps1`: read release image names from Compose, and pass them into Helm for kubernetes deployment

---

## CI/CD Workflows

- `build.yaml`: validate that each component builds and its Dockerfile test stage passes
- `package-staging.yaml`: build and push build-image with build number and stable staging-image
- `smoke-test.yaml`: test staging image
- `package-release.yaml`: promote already-tested staging image with release image tag
- `deploy.yaml`: deploy release images with Helm to Kubernetes

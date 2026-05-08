# Solution

Goal: publishing one logical image tag that works across multiple platforms

Create a platform-neutral tag: `ch16-access-log:2e`, and let it becomes a manifest list.

- user can pull `ch16-access-log:2e` directly
  - docker will inspect manifest list and automatically choose the right image
- no need to manually choose:
  - `ch16-access-log:2e-linux-amd64`
  - `ch16-access-log:2e-windows-ltsc2022-amd64`

## Core Concepts Recap

- Image tag: human-readable name/version (`ch16-access-log:2e`)
- Docker registry: remote storage service holding images and manifests (`ghcr.io`)
- Manifest list: a multi-platform index that maps one image tag to different platform-specific images

## Related Files

> Linux and Windows images are built and pushed separately with platform suffixes

- `./src/docker-compose-multi-platform-tags.yml`: defines the final shared release tags
- `./cicd/push-manifest-list.ps1`: GitHub workflow logs into GHCR
- `@repo-root/.github/workflows/diamol-ch16-push-manifest-list.yaml`: reads image names from Compose and creates Docker manifest list for each app component

## Commands Cheat Sheet

```sh
# Build platform-specific images
docker compose -f docker-compose.yml -f docker-compose-build.yml -f docker-compose-build-tags.yml build --pull

# Push platform-specific build images:
docker compose -f docker-compose.yml -f docker-compose-build.yml -f docker-compose-build-tags.yml push

# Tag an image locally
docker image tag <source-image> <target-image>

# Push a tagged image:
docker push <target-image>

# Create a manifest list
docker manifest create <target-image> <variant-image-1>  <variant-image-2>
docker manifest create \
  ghcr.io/<owner>/release/ch16-access-log:2e \
  ghcr.io/<owner>/release/ch16-access-log:2e-linux-amd64 \
  ghcr.io/<owner>/release/ch16-access-log:2e-windows-ltsc2022-amd64 \

# Push manifest list
docker manifest push ghcr.io/<owner>/release/ch16-access-log:2e

# Remove an existing local manifest before recreating it
docker manifest rm ghcr.io/<owner>/release/ch16-access-log:2e

# Inspect a manifest list
docker manifest inspect ghcr.io/<owner>/release/ch16-access-log:2e
```

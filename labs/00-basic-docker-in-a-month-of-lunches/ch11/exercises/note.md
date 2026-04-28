# Local containerized CI project structure

> Docker is all you need to build app.
> No need for a build server with lots of tools installed.

## Why separate docker compose config

### `docker-compose.yml`: define flexible image name for different env (DEV, CI)

By define different env var for different env, we can build and run different image within each env based on our needs.

### `docker-compose-build.yml`: actual build process for certain `Dockerfiles`

We can build image with `docker compose build`, and it will builds images for services that have a `build:` section. It uses the current environment when resolving the compose file first, so env var substitutions affect tags, build args, paths, etc.

## Manage LABEL for tracking image builds

Label instruction get baked into the image and move with it, which allows `docker image inspect` to:

- find exactly where that image came from
- tracking it back to the CI job that produced it
- further tracks back to the exact version of code that triggered the build

> It’s an audit trail from the running container in any environment back to the source code.

### Use ARG to provide values to LABEL

ARG is similar to ENV but it works at build time on the image. Any container runtime of that image can't see the that ARG var. Thus it becomes a great way to pass data into the build process that isn't relevant for running containers.

### Prepare default value for different build method

This exercise provide default value in ARG for Dockerfile and `args` for docker compose, so user can build image in all kind of env without issues.

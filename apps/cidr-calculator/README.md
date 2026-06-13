# Shared CIDR Calculator app

This directory is the shared ownership boundary for the CIDR Calculator static-site container used by the container deployment labs. It owns the React/Vite SPA source, pnpm package metadata, mise Node toolchain config, Docker build definition, and Nginx SPA runtime config.

Lab-specific infrastructure remains outside this directory. Build and deploy workflows can use this directory as the Docker build context while keeping per-lab ECR repositories, Terraform roots, and runtime settings unchanged.

## Toolchain

Use `mise` from this directory to install Node 24 and enable Corepack-managed pnpm:

```sh
cd apps/cidr-calculator
mise install
corepack pnpm --version
```

The package metadata pins pnpm through the `packageManager` field and keeps the existing pnpm minimum-release-age bypass in `.npmrc` and `pnpm-workspace.yaml`.

## Local development

```sh
cd apps/cidr-calculator
pnpm install
pnpm dev
```

The Vite dev server listens on `http://localhost:5173` by default. Enter a CIDR such as `192.168.1.42/24` to calculate network address, broadcast address, masks, host range, address counts, and binary representations.

## Checks and production build

```sh
cd apps/cidr-calculator
pnpm lint
pnpm test
pnpm build
pnpm preview
```

- `pnpm test` runs the Vitest CIDR calculator unit tests.
- `pnpm build` type-checks and emits static assets into `dist/`.
- `pnpm preview` serves the production build locally for review.

## Docker build and local smoke test

Build the static-site image from this directory:

```sh
cd apps/cidr-calculator
docker build -t cidr-calc .
# or: pnpm docker:build
```

Run it locally. The container listens on port 80; this example maps it to host port 8090:

```sh
docker run --rm -p 8090:80 cidr-calc
# or: pnpm docker:run
```

Smoke test the running container from another terminal:

```sh
curl -fsS http://localhost:8090 | grep -F "CIDR Calculator"
```

Open `http://localhost:8090` in a browser to verify the SPA loads. The Dockerfile keeps the existing multi-stage shape: Node builds the static assets, then Nginx serves them from `/usr/share/nginx/html` over port 80. The Nginx config in `nginx/default.conf` preserves SPA fallback routing and immutable cache headers for static assets.

Stop a container started by the package script with:

```sh
pnpm docker:stop
```

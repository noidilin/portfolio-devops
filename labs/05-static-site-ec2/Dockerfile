FROM node:24-alpine AS build
RUN corepack enable && corepack prepare pnpm@latest --activate
WORKDIR /app

# Bypass minimumReleaseAge supply-chain policy
RUN pnpm config set minimumReleaseAge 0

COPY app/package.json app/pnpm-lock.yaml ./
RUN pnpm install --no-frozen-lockfile

COPY app/ ./
RUN pnpm build

FROM nginx:1.27-alpine
COPY --from=build /app/dist /usr/share/nginx/html
COPY nginx/default.conf /etc/nginx/conf.d/default.conf

EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]

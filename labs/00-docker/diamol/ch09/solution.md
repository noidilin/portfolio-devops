# Solution

## Step

1. copy `prometheus`, `grafana` directory and `docker-compose-with-grafana`
2. build needed images, and trim down `docker-compose` file
3. spin up containers with docker compose
4. create grafana dashboard in web UI
5. rebuild grafana image
6. spin up containers with docker compose

---

## Docker Compose: clean up `docker-compose-with-grafana`

- Only the `image`, `ports`, and `networks` is needed in the compose file.
- Name the images that will be used
  - `diamol/ch09-todo-list:2e` (port `8080`)
  - `diamol/ch09-lab-prometheus:soln` (port `9090`)
  - `diamol/ch09-lab-grafana:soln` (port `3000`)

---

## Images

### App image

The app image already support metrics for Prometheus.

- image: `diamol/ch09-todo-list:2e`
- app: `http://localhost:8080`
- metrics: `http://localhost:8080/metrics`

### Prometheus image

- image: `diamol/ch09-lab-prometheus:2e`
- app: `http://localhost:9060`

This image built with the `prometheus.yml` config

```yml
scrape_configs:
  - job_name: "todo-list"
    metrics_path: /metrics
    static_configs:
      - targets: ["todo-list:8080"]
```

### The custom Grafana image

Build Grafana image first based on the exercises setup.

```dockerfile
FROM diamol/grafana:2e

COPY datasource-prometheus.yaml ${GF_PATHS_PROVISIONING}/datasources/
COPY dashboard-provider.yaml ${GF_PATHS_PROVISIONING}/dashboards/
# COPY dashboard.json /var/lib/grafana/dashboards/
```

- image: `diamol/ch09-lab-grafana:2e`
- app: `http://localhost:3060`

We still lack of `dashboard.json` for now. First,we will interact with the app in the `localhost:8080` to produce some data, and then spin up the Grafana app in a container to build panels for:

- created tasks number: `todo_tasks_created_total`
- received HTTP requests: `http_requests_received_total`
- in-progress HTTP requests: `http_requests_in_progress`

Export panels to `json` file as `dashboard.json`, and we can un-comment the final line in the Dockerfile to build the final image for Grafana.

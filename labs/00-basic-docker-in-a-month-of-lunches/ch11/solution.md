# Solution

## Step

### infrastructure for CI

Execute the `scripts/add-to-hosts.sh` with `sudo` to setup hosts file for local DNS

```sh
# ch11/exercises/infrastructure
docker compose -f docker-compose.yml -f docker-compose-linux.yml up -d
```

### build instruction for docker compose

- `context` and `dockerfile` are needed to locate Dockerfile
- `args` is used to pass build arguments to the Dockerfile
  - what args to pass can be found out from the ARG instruction in Dockerfile

```yml
    build:
      context: todo-list
      dockerfile: Dockerfile
      args:
        BUILD_NUMBER: ${BUILD_NUMBER:-0}
```

### Create Jenkins Job

> this part is coming from the book solution part

- log into Jenkins with default username `diamol` and password `diamol`
- Dashboard -> New Item
  - item name: `ch11-lab`
  - copy from: `diamol`
- in pipeline definition, script path: `ch11/Jenkinsfile`
- Save -> Build Now
- check image in local registry `http://registry.local:5010/v2/diamol/ch11-todo-list/tags/list`

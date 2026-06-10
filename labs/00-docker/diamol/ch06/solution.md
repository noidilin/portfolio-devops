# Solution

## Steps

- spin up the lab container first

```sh
docker container run -d -p 8015:8080 diamol/ch06-lab:2e
```

- prepare the bind mount and volume mount for the app
  - bind mount: readonly, for passing in config
  - volume mount: read and write, for storing app data

```sh
# bind mount
docker volume create ch06-lab
```

- setup volume mount with app config so it utilize the desired data directory
  - prepare the `config.json`
  - the format comes from config in `./todo-list-v3/`

> [!CAUTION]
> I can find out what name should I use for the config file, and I tried to name it as `appsettings.json` like the `./todo-list-v3/` directory does, but with no luck. I have no choice to copy the solution's name `config.json`, which finally make it work.

```jsonc
// store data under `/data-lab` dir
{
  "ConnectionStrings": {
    "ToDoDb": "Filename=/data-lab/todo-list.db"
  }
}
```

> [!NOTE]
> To find out what is currently used by the image we can look into image config
> the image Dockerfile declares a volume at `/data` so that was the first clue

- spin up a new container that accepts actual command for wiring up the mount

```sh
docker container run -d -p 8016:8080 /
  --mount type=bind,source=$(pwd),target=/app/config,readonly /
  --volume ch06-lab:/data-lab /
  diamol/ch06-lab:2e
```

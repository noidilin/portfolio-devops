# Solution

## Steps

```sh
# k is alias for kubectl in my shell

# apply manifest under k8s dir
k apply -f k8s/

# examine the logs
k9s

# copy the content of ./logging.json into the configmap manifest for todo-web
k apply -f k8s/

# HACK:
# commands from the solution to quickly check if the setting is passed into the deployment
kubectl exec deploy/todo-web -- cat /app/config/logging.json

# use the app to produce logs, and examine again
k9s
```

## Tips from the solution

We might sometimes need to restart the rollout, since not all apps reload config files when they change.

```sh
k rollout restart deploy/todo-web
```


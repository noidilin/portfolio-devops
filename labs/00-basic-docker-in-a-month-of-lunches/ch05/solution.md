# Solution

> must of the answer is coming from AI provided by docker.

## Steps

- push multiple images for one repo

```sh
docker image push --all-tags registry.local:5010/gallery/ui
```

- check image tags from repo in local registry with `curl`

```sh
curl http://registry.local:5010/v2/gallery/ui/tags/list
```

Received tags for one repo:

```json
{"name":"gallery/ui","tags":["2","2.1.106","latest","v1","2.1"]}
```

- retrieve `lates` manifest with `/latest`

```sh
curl --head `
  http://registry.local:5010/v2/gallery/ui/manifests/latest `
  -H 'Accept: application/vnd.docker.distribution.manifest.v2+json'
```

The `Docker-Content-Digest` in the headers is the manifest we need.

```txt
Docker-Content-Digest: sha256:ee332f847543d675155772f3a15ba9f788fe2823e832efd77b9fb36ffcb32f82
```

- delete tags

```
curl -XDELETE `
  http://registry.local:5010/v2/gallery/ui/manifests/sha256:ee332f847543d675155772f3a15ba9f788fe2823e832efd77b9fb36ffcb32f82
```

- check again for image tags from repo in local registry with `curl`

```sh
curl http://registry.local:5010/v2/gallery/ui/tags/list
```

There should be no tags left in the repo if the deleting operation successes.

```json
{"name":"gallery/ui","tags":null}
```

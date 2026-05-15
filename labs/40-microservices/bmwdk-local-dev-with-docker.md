# Bootstrapping Microservices - Local Development with Docker

This lab turns a simple video-streaming application into a small microservice system. The goal is to separate responsibilities: one service handles the public streaming API, another service knows how to talk to Azure Blob Storage, and MongoDB stores the metadata that connects a video id to the actual video asset.

## Ch03 — Packaging the application

The first step is containerizing the application.

A `Dockerfile` is used to build an application image that can run consistently outside the local development machine. Once the image exists, it can be pushed to Azure Container Registry so that the same build artifact can be pulled by other environments.

---

## Ch04 — Splitting storage from streaming

In this chapter, the app becomes more interesting. Video streaming is no longer hard-coded to read directly from a local file or a single implementation. Instead, the system is split into three moving parts:

1. `video-streaming` — the public-facing service
2. `db` — MongoDB, used as the video metadata database
3. `azure-storage` — a storage microservice that fetches video files from Azure Blob Storage

The request path looks like this:

```txt
Browser
  -> video-streaming
    -> MongoDB, lookup video id
    -> azure-storage, fetch video by path
      -> Azure Blob Storage
    -> stream video back to browser
```

### How the code connects the services

The client calls the streaming service with a video id:

```txt
http://localhost:4002/video?id=5d9e690ad76fe06a3d7ae416
```

The `video-streaming` service connects to MongoDB using environment variables from the compose file:

```txt
DBHOST=mongodb://db:27017
DBNAME=video-streaming
```

Inside `video-streaming/src/index.js`, the service reads the `videos` collection and translates the incoming id into a storage path:

```js
const videoRecord = await videosCollection.findOne({ _id: videoId });
```

The fixture data provides this mapping:

```json
{
  "_id": { "$oid": "5d9e690ad76fe06a3d7ae416" },
  "videoPath": "midwest-emo-bojack-horseman.mp4"
}
```

After the lookup, `video-streaming` forwards the request to the storage microservice:

```txt
http://video-storage:80/video?path=midwest-emo-bojack-horseman.mp4
```

The `azure-storage` service receives that path, connects to Azure Blob Storage using `STORAGE_ACCOUNT_NAME` and `STORAGE_ACCESS_KEY`, reads the blob from the `videos` container, and pipes the video stream back through the streaming service to the browser.

This keeps the public API independent from the storage implementation. The streaming app only knows there is a service called `video-storage`; it does not need to know whether the file comes from Azure, S3, the local filesystem, or another backend.

### How DNS works in Compose

The most useful thing I learned in this step is that Docker Compose gives the services a small private network with built-in DNS.

That means the containers do not need to know each other's IP addresses. They can talk to each other by name:

- db              -> MongoDB
- video-storage   -> Azure storage microservice

In the compose file, the streaming service receives those names as environment variables:

```yaml
video-streaming:
  ports:
    - "4002:80"
  environment:
    - PORT=80
    - DBHOST=mongodb://db:27017
    - DBNAME=video-streaming
    - VIDEO_STORAGE_HOST=video-storage
    - VIDEO_STORAGE_PORT=80
  depends_on:
    db-fixture:
      condition: service_completed_successfully
```

There are two separate ideas working together here.

First, the environment variables tell the application which dependency names to use. The Node.js code does not hard-code `db` or `video-storage`; it reads `DBHOST`, `VIDEO_STORAGE_HOST`, and `VIDEO_STORAGE_PORT` from the environment. This keeps the code configurable.

Second, Compose DNS makes those names actually resolve inside the Docker network. When `video-streaming` opens a connection to `mongodb://db:27017`, Docker resolves `db` to the MongoDB container. When it forwards a video request to `video-storage:80`, Docker resolves `video-storage` to the storage service container.

> So the env var answers: What hostname should my app call?
> Compose DNS answers: Where is that hostname inside this Compose network?

Together, they let the app call dependencies by stable names instead of fragile container IP addresses.

### Set up fixtures for MongoDB

The same DNS behavior is used by the fixture loader. It imports seed data by connecting to MongoDB through the Compose name `db`:

```txt
mongodb://db:27017
```

The `db-fixture` service loads seed data into MongoDB:

```yaml
db-fixture:
  image: mongo:7.0.0
  volumes:
    - ./db-fixture:/fixtures:ro
  depends_on:
    db:
      condition: service_healthy
  command: >
    bash -c "mongoimport --host db --db video-streaming --collection videos --drop --file /fixtures/videos.json"
```

This service waits until MongoDB is healthy, imports `db-fixture/videos.json` into the `video-streaming.videos` collection, then exits. The main streaming service depends on this import finishing successfully, so the metadata is available before the app starts serving requests.

> [!NOTE]
> This is still a deliberately simple wiring approach. The streaming service depends on a specific hostname and port for storage. That is good enough for the lab, but a production system would usually use service discovery, stronger configuration management, and safer secret handling.

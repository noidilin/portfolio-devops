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

## Ch05 - Communication between microservices

Chapter 5 adds the first real service-to-service business communication, and the streaming service now starts talking to a new `history` service.

The new flow is:

```txt
video-streaming
  -> azure-storage, fetch the video
  -> history, record that the video was viewed
```

### DEV and PROD environment with dedicated Dockerfile

The `history` service now has separate Dockerfiles for different goals:

- `Dockerfile-dev` keeps the feedback loop fast with bind-mounted source code and `nodemon`.
- `Dockerfile-prod` builds a self-contained image with `npm ci --omit=dev` and copied source files.

This matters more as the number of services grows. Development containers should be easy to change and restart. Production containers should be predictable, repeatable, and independent from the host machine.

### Synchronous communication between microservices

The current communication style is synchronous HTTP. `video-streaming` sends a `POST` request to the Compose service name `history`:

```js
const req = http.request("http://history/viewed", postOptions);
req.write(JSON.stringify({ videoPath }));
req.end();
```

The `history` service receives that request and stores the viewed video path:

```js
app.post("/viewed", async (req, res) => {
  await historyCollection.insertOne({ videoPath: req.body.videoPath });
  res.sendStatus(200);
});
```

The benefit is simplicity. HTTP is easy to understand, easy to test, and easy to debug with logs or curl. Docker Compose DNS also keeps the local setup clean: `video-streaming` can call `http://history/viewed` without knowing container IPs or host ports.

The tradeoff is coupling. With synchronous communication, the caller depends on the receiver being reachable at request time. If `history` is down, slow, or misconfigured, the streaming service has to decide whether to fail the user request, wait, retry, or ignore the history failure. This is fine for a lab and for simple request/response workflows, but it becomes risky when the side effect is not required for the main user action.

For this specific case, recording history feels like a secondary event. The user mainly wants the video to stream. That makes this a good example of where asynchronous messaging could eventually be better: `video-streaming` could publish a "video viewed" event and continue streaming, while `history` processes the event independently.

### Asynchronous communication between microservices

The next step replaces the direct `video-streaming -> history` HTTP call with RabbitMQ. Instead of asking `history` to record the view during the request, `video-streaming` publishes a small message and keeps doing its own job: streaming the video.

The new flow looks like this:

```txt
Browser
  -> video-streaming, request video
    -> RabbitMQ, publish "viewed" message
      -> history, consume message later
        -> MongoDB, store viewing history
```

This changes the relationship between the services. `video-streaming` no longer needs to know where the `history` API lives, which route to call, or whether `history` is ready at that exact moment. Both services only need the same broker address:

```yaml
RABBIT=amqp://guest:guest@rabbit:5672
```

Docker Compose runs RabbitMQ as the `rabbit` service, so the same Compose DNS idea still applies. Inside the Docker network, `rabbit` resolves to the RabbitMQ container. The broker listens on `5672` for application traffic, and the management UI is exposed on `15672` for local debugging.

#### Make sure RabbitMQ server is up

RabbitMQ is now shared infrastructure for the microservices. The Compose file starts it with the management image:

```yaml
rabbit:
  image: rabbitmq:3.12.4-management
  ports:
    - "5672:5672"
    - "15672:15672"
```

Both `video-streaming` and `history` declare `depends_on: rabbit`, but that only controls startup order. The app code still needs to connect to the broker before it can publish or consume messages.

The Dockerfiles add one extra guard before starting Node:

```dockerfile
CMD npm install --prefer-offline && \
    npx wait-port rabbit:5672 && \
    npm run start:dev
```

`npx wait-port rabbit:5672` blocks the container startup command until the RabbitMQ TCP port is reachable from inside the Compose network. This closes the gap left by `depends_on`: Compose may start the `rabbit` container first, but RabbitMQ can still need a few more seconds before it accepts AMQP connections. Waiting on `rabbit:5672` makes local development less flaky because `video-streaming` and `history` do not immediately crash just because the broker process is still warming up.

In `video-streaming`, startup now begins by connecting to RabbitMQ and opening a channel:

```js
const messagingConnection = await amqp.connect(RABBIT);
const messageChannel = await messagingConnection.createChannel();
```

After that, the communication pattern evolves in two steps: first a single queue for one receiver, then a fanout exchange for many receivers.

#### Sending and receiving single recipient messages

The first RabbitMQ version uses one queue named `viewed`. When a video is streamed, `video-streaming` publishes a JSON message directly to that queue:

```js
const msg = { videoPath };
messageChannel.publish("", "viewed", Buffer.from(JSON.stringify(msg)));
```

The empty exchange name uses RabbitMQ's default exchange. In that mode, the routing key is the queue name, so `"viewed"` sends the message to the `viewed` queue. The `history` service consumes from that queue, writes the view to MongoDB, and only then acknowledges the message:

```js
await messageChannel.consume("viewed", async (msg) => {
  const parsedMsg = JSON.parse(msg.content.toString());
  await historyCollection.insertOne({ videoPath: parsedMsg.videoPath });
  messageChannel.ack(msg);
});
```

This is a good fit when exactly one service should handle the work. The event is still asynchronous, but the queue behaves like a single work lane: one published `viewed` message is meant for one consumer.

#### Sending and receiving multiple recipient messages

The latest step changes the model from direct queue delivery to broadcasting. `video-streaming` now publishes the `viewed` event to a RabbitMQ `fanout` exchange:

```js
await messageChannel.assertExchange("viewed", "fanout");
messageChannel.publish("viewed", "", Buffer.from(JSON.stringify(msg)));
```

A fanout exchange ignores routing keys and copies each message to every queue bound to it. That means `video-streaming` no longer decides who receives the event. It only announces that a video was viewed.

Each interested service creates its own temporary queue and binds it to the `viewed` exchange:

```js
const { queue } = await messageChannel.assertQueue("", { exclusive: true });
await messageChannel.bindQueue(queue, "viewed", "");
await messageChannel.consume(queue, consumeViewedMessage);
```

Now both `history` and `recommendations` can receive the same event independently. `history` records the view in MongoDB, while `recommendations` can react to the same viewing signal without adding another HTTP call to `video-streaming`.

This makes the communication more fluent as the system grows. Instead of chaining services together with direct requests, the streaming service publishes a small fact — "this video was viewed" — and RabbitMQ delivers that fact to whichever services care about it. The result is looser coupling: producers focus on producing events, consumers choose how to respond, and new consumers can be added without changing the producer's request flow.

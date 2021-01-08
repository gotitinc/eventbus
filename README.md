<p align="center">
  <img src="https://raw.githubusercontent.com/gotitinc/eventbus/main/origin/eventbus-logo-trasparent.svg" alt="eventbus logo" width="150" height="150">
</p>

<h3 align="center">EventBus</h3>

[![Build Status](https://travis-ci.org/gotitinc/eventbus.svg?branch=main)](https://travis-ci.org/gotitinc/eventbus)

Eventbus is a scalable and Highly Available Event Bus Service.

An event is a REST request which includes a `url` that is used to forward the event to other server.
Pending requests are queued within Eventbus.

Eventbus is configured with a list of supported `topics` and a valid event is required to include a `topic` from the configured list.
Each topic has multiple partitions and each partition defines a separate queue for storing pending events.

Each event should include a `key` that is always mapped to the same partition, hence events with a particular key are always dispatched in order.

Events from the same partition are always dispatched in order similar to Kafka events semantics.

When launching multiple instances in the same network the nodes will automatically cluster. The partitions are automatically distributed among the nodes in the cluster when new nodes are added or removed. Event dispatch order within a partition is always enforced regardless of the number of nodes in the cluster.

The pending events are stored in a Redis instance.

## API

**Produce**

Forwards an event request to another server

```
POST /api/produce
```

The POST request should include a JSON payload with the following mandatory parameters:

- topic: name of the topic (for example: 'router')
- key: a key used to map the request to a partition queue (for example a problem_id)
- url: the url to which the payload will be forwarded
- payload: the payload to forward

and the following optional parameters:
- max_retry: maximum retries if the request fails (default: 5)
- timeout: maximum request duration allowed in msec (default: 30 seconds)

Example:

```
$ curl -XPOST -H 'Content-Type: application/json' --data-binary '{"topic": "router", "key": "123", "url": "http://httpbin.org/post", "payload": "hello"}' http://event/api/produce
```

**Produce Delayed**

Forwards a request to another server and dispatched after the specified delay

```
POST /api/produce_delayed
```

The POST request should include a JSON payload with the following mandatory parameters:

- topic: name of the topic (for example: 'router')
- key: a key used to shard the request (for example a problem_id)
- url: the url to which the payload will be forwarded
- payload: the payload to forward
- delay: how long to delay the forward operation in msec

and the following optional parameters:
- max_retry: maximum retries if the request fails (default: 5)
- timeout: maximum request duration allowed in msec (default: 30 seconds)

Example:

```
$ curl -XPOST -H 'Content-Type: application/json' --data-binary '{"topic": "router", "key": "123", "url": "http://httpbin.org/post", "payload": "hello", "timeout": 60}' http://event/api/produce_delayed
```

## Installation

Install Elixir

```
$ brew update
$ brew install elixir
```

Check out code

```
$ git clone git@github.com:gotitinc/eventbus.git
$ cd eventbus
```

Install Redis

```
$ brew install redis
```

## Run Tests

Get dependencies

```
$ mix deps.get
```

Execute Unit Tests

```
$ mix test
```

Execute Coverage Tests

```
$ mix coveralls --umbrella
```

## Start Local server in Development Mode

Start EventBus server on port 4000

```
$ PORT=4000 mix phx.server
```

## Creating and running a Release

```
$ MIX_ENV=prod mix release
```

Run service in the foreground:

```
$ _build/prod/rel/eventbus_service/bin/eventbus_service start
```

## Run in Docker Compose

Start EventBus server in docker on port 80

```
$ docker-compose up
```

## Copyright and license

Documentation copyright 2020 the [Got It, Inc.](https://www.got-it.ai) Code released under the [Apache-2.0 License](https://github.com/gotitinc/eventbus/blob/master/LICENSE).

# fluent-plugin-unix-client

[Fluentd](https://fluentd.org/) input plugin to receive data from UNIX domain socket.  
This is a **client version** of [the default `unix` plugin](https://docs.fluentd.org/input/unix).

## Installation

### RubyGems

```
$ gem install fluent-plugin-unix-client
```

### Bundler

Add following line to your Gemfile:

```ruby
gem "fluent-plugin-unix-client"
```

And then execute:

```
$ bundle
```

## Configuration

### tag (string) (required)

Tag of output events.

### path (string) (required)

The path to Unix Domain Socket.

Note: This is a client side application, so you need to set the path which **is opened by another server side application**. 

### parse (section) (required)

This plugin use Fluentd parser plugin as a helper.  
See [Config: Parse Section](https://docs.fluentd.org/configuration/parse-section).

### delimiter (string) (optional)

The payload is read up to this character.

Default value: `"\n"` (newline).

### format_json (bool) (optional)

When recieved JSON data splitted by the delimiter is not completed, like '[{...},', trim '[', ']' and ',' characters to format.

Please see `Sample` below for details.

Default value: false.

## Sample

### For JSON

Config:

```
<source>
  @type unix_client
  tag debug.unix_client
  path /tmp/unix.sock
  <parse>
    @type json
  </parse>
  delimiter "\n"
</source>

<match debug.**>
  @type stdout
</match>
```

Assumed Data:

* ndjson
```
{"key":0}\n
{"key":0}\n
...
```

* JSON list
```
[{"key":0}, {"key":0}, ...]\n
[{"key":0}, {"key":0}, ...]\n
...
```

### Use `format_json`

Config:

```
<source>
  @type unix_client
  tag debug.unix_client
  path /tmp/unix.sock
  <parse>
    @type json
  </parse>
  delimiter "\n"
  format_json true
</source>

<match debug.**>
  @type stdout
</match>
```

Assumed Data:

```
[{"key":0},\n
{"key":0},\n
...
{"key":0}]\n
...
```

## Specification

* This recieves data from UNIX domain socket which **is opened by another application**.
  * If you need other applications to send data to the socket you opened, you can use [the default `unix` plugin](https://docs.fluentd.org/input/unix).
* If this can't connect to the socket, this trys to reconnect later.

## Copyright

* Copyright(c) 2021- daipom
* License
  * Apache License, Version 2.0

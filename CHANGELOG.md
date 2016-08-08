## v0.2.0 2016-08-08

* Added: Support for extracting the URL during Redix connection. The
  documentation now also illustrates use of `redis_opts` when setting the
  adapter to Redis.
* Added: Configurable serialization for adapters. Now JSON, MessagePack or some
  other custom option can be used instead of Erlang term storage.
* Added: Documentation for using a temporary worker to configure groups at boot
  time.

## v0.1.0 2016-08-02

* Initial release! Supports a Memory and Redis adapter.

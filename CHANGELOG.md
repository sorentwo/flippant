## v0.3.0 2016-09-20

### Enhancements

* [Flippant] Add `breakdown/0` for complete details
* [Flippant] Rename `reset/0` to `clear/0`, and add `clear/1` variants that can
  clear either `:features` or `:groups`.
* [Flippant.Adapter] Explicitly sort feature keys
* [Flippant.Adapter.Redis] Only load the adpater if `redix` is available
* [Flippant.Adapter.Memory] Optimize the adapter for read conncurency

### Bug Fixes

* [Flippant.Adapter] Safely generate a breakdown without any rules
* [Flippant.Adatper.Redis] Use custom pipeline that is aware of empty lists

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

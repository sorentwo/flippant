## v0.4.1 2017-10-20

* [Flippant] - Revert the elixir constraint to `~> 1.4`

## v0.4.0 2017-10-20

### Enhancements

* [Flippant] - Add a new Postgres adatper, backed by Postgrex.
* [Flippant] - Add `exists?/1` for checking whether a feature exists at all,
  and `exists?/2` for checking whether a feature exists for a particular group.
* [Flippant] - Add `rename/2` for renaming existing features.
* [Flippant] - Merge additional values when enabling features. This prevents
  clobbering existing values in "last write wins" situations.
* [Flippant] - Support enabling or disabling of individual values. This makes it
  possible to remove a single value from a group's rules.
* [Flippant] - Add `setup/0` to facilitate adapter setup (i.e. Postgres).
* [Flippant.Adapters.Redis] - Accept options to configure the adapter's set key.

### Changes

* [Flippant.Adapter] - Values are no longer guaranteed to be sorted. Some
  adapters guarantee sorting, but race conditions prevent it in the Postgres
  adapter, so it is no longer guaranteed.
* [Flippant.Registry] - Use a named ETS table for rule storage rather than an
  Agent. This is slightly faster, and it prepares us for crash recovery.

### Bug Fixes

* [Flippant] - Correct guard logic for multiple `when` clauses.

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

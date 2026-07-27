# ADR-0007: Kafka over RabbitMQ for the Write-Side Event Backbone

## Status

Accepted

## Context and Problem Statement

An earlier, less-granular design (4 services) recommended RabbitMQ for write-side async completion events, reasoning that ingestion is job-queue-shaped and RabbitMQ's simpler operational model was sufficient. After decomposing the write side into 8 fine-grained bounded contexts (ADR-0001), several write-side domain events now need to be read independently by multiple, evolving consumers — e.g. `DocumentUploaded` is consumed by Parsing, Document Catalog, *and* Audit, and that list is expected to grow (future re-embedding jobs, analytics).

## Decision Drivers

- Independent consumer groups on the same event, added over time without broker reconfiguration.
- Replay: Audit Service must be able to rebuild its log from scratch or backfill after downtime; a future "re-embed everything" job needs to replay chunk-creation history.
- Per-aggregate ordering (via partition keys).
- Throughput at the fine-grained per-chunk event layer (`ChunkCreated`/`ChunkEmbedded` can be hundreds of events per large document).

## Considered Options

1. RabbitMQ (carried over from the earlier, less-granular design).
2. Apache Kafka (KRaft mode, no separate ZooKeeper).

## Decision Outcome

Chosen option: **2 — Kafka**. RabbitMQ requires a new durable queue+binding per new reader of an *existing* event type — an operational action every time a new consumer appears. Kafka gives each new reader its own consumer group and offset with zero broker provisioning, and its retained log gives native replay, which RabbitMQ's ack-and-gone queue semantics don't. `documentId` is used as the partition key for strict per-document ordering. Events are serialized via Avro/JSON Schema with a schema registry (Apicurio, self-hosted) — deliberately not Java-native serialization, since Parsing/Chunking Service language choice was still an open question when this was decided (later resolved by ADR-0006, but the schema-registry approach remains the right call regardless of implementation language). One broker only — the read side's synchronous gRPC chain (ADR-0002) does not bridge into a second broker.

## Consequences

**Good:**
- New consumers attach without any producer or broker reconfiguration.
- Full replay capability for Audit Service and future reprocessing jobs.
- Per-document ordering via partition keys, without bolting anything on.

**Bad:**
- Kafka is operationally heavier than RabbitMQ (partitions, schema registry, consumer-group rebalancing) — a real cost, reasonable only because of the fan-out/replay requirements above, not for a simple point-to-point task queue.

## Alternatives Considered (detail)

### RabbitMQ
Reasonable for the earlier 4-service pragmatic split (few consumers per event, no genuine replay requirement). Stops being reasonable at 8+ fine-grained write-side bounded contexts with real multi-consumer fan-out and a compliance/replay requirement (Audit Service).

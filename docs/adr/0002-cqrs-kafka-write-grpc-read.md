# ADR-0002: CQRS Topology Split — Kafka for the Write Side, gRPC for the Read Side

## Status

Accepted

## Context and Problem Statement

ADR-0001 commits to event-driven microservices. Taken literally end-to-end, "event-driven" would mean every inter-service call — including the chat/query path a human is waiting on — goes through asynchronous broker hand-offs. Request/reply over a message broker is a well-known latency anti-pattern: each hop adds queueing/consumer-poll latency that is invisible and unacceptable to a human holding an open connection.

## Decision Drivers

- Document ingestion (write side) is not latency-sensitive to a human and benefits from durable, replayable, multi-consumer events.
- Chat/query (read side) is latency-sensitive; a human is waiting on the response.
- The user explicitly delegated protocol choice (gRPC/Kafka/REST) to this design rather than mandating one transport everywhere.

## Considered Options

1. Kafka (or another broker) end-to-end, including the query path.
2. REST end-to-end.
3. **CQRS split**: async Kafka event choreography for the write/ingestion side; synchronous, orchestrated gRPC request/response for the read/query side.

## Decision Outcome

Chosen option: **3**. Write-side services (Ingestion, Parsing, Chunking, Embedding, Document Catalog, Audit, Request Validator, Authorization) communicate via Kafka domain events (see ADR-0007 and the event catalog). Read-side services (Query Processor, Retrieval, Reranker, LLM Router, Response Formatter) communicate via gRPC, orchestrated by Query Processor, which owns the total request latency budget via gRPC deadline propagation. Every read-side service *also* fire-and-forgets Kafka audit events alongside its synchronous work — this is where "event-driven" legitimately shows up on the read side, strictly as a non-blocking side effect, never gating the response.

## Consequences

**Good:**
- The read path gets binary payloads, HTTP/2 multiplexing, native streaming, and built-in deadline propagation (see `docs/architecture/c4-component-query-processor-service.md`) — the properties that actually matter for a bounded chat-latency budget.
- The write path gets durable, replayable, independently-consumable events — the properties that matter for a multi-stage, multi-consumer ingestion pipeline and for compliance audit (ADR-0011).

**Bad:**
- Two distinct communication paradigms in one system raises the learning curve; a developer touching both sides must reason about both delivery models.
- The line between "synchronous chain" and "async audit side-effect" must be enforced by convention/code review (a fire-and-forget publish that accidentally blocks would silently reintroduce the anti-pattern this ADR avoids).

## Alternatives Considered (detail)

### Kafka end-to-end
Rejected for the read side specifically: request/reply-over-broker patterns add per-hop latency with no offsetting benefit for a request with exactly one consumer (the waiting user) and no replay requirement.

### REST end-to-end
Would have worked functionally but loses gRPC's binary-payload efficiency for embedding/chunk-array-heavy calls, native streaming semantics for token-by-token generation, and built-in deadline propagation — see ADR discussion in the Query Processor component doc for the concrete cost/benefit reasoning.

# ADR-0009: Separate Reranker Service from Retrieval Service

## Status

Accepted

## Context and Problem Statement

An earlier, less-granular design bundled embedding, vector search, and reranking into one "Retrieval/RAG Service." The user's explicit service list names Retrieval and Reranker separately. The question is whether that separation is DDD-justified or just following the list without reasoning.

## Decision Drivers

- Retrieval uses a bi-encoder (query and chunk embedded independently, compared via ANN vector distance — cheap, index-friendly, approximate).
- Reranking uses a cross-encoder (query and each candidate chunk jointly encoded per pair — expensive per-item, no ANN index possible, materially more precise).
- Different scaling profiles: Retrieval scales with PGVector I/O and connection pool sizing; Reranker scales with GPU/inference throughput for a fixed-size candidate batch.

## Considered Options

1. One combined "Retrieval/RAG" service doing embedding, search, and rerank.
2. Two services: Retrieval (bi-encoder ANN search + ACL filtering) and Reranker (cross-encoder precision reordering + MMR diversity filtering), as distinct bounded contexts.

## Decision Outcome

Chosen option: **2**. Bundling two components with unrelated computational shapes and scaling bottlenecks into one deployable is a direct violation of high cohesion / low coupling — one service would need to scale against two unrelated bottlenecks (I/O-bound ANN search vs. GPU-bound cross-encoder inference). Reranker Service defaults to an in-JVM DJL cross-encoder (consistent with the single-language-stack preference, ADR-0014), with a dedicated inference runtime (e.g., Triton/TEI, still called via a client rather than hand-written) documented as a scale-out option if GPU throughput later demands it. MMR diversity filtering (avoiding near-duplicate retrieved chunks) is genuine business logic owned here, not just raw model scoring.

## Consequences

**Good:**
- Each service can be scaled independently against its actual bottleneck.
- Reranker's model-serving concern (GPU sizing, batching) doesn't contaminate Retrieval Service's connection-pool/ANN-index concerns.

**Bad:**
- One more gRPC hop in the read-side chain (Query Processor → Retrieval → Reranker) versus a single combined call — accepted given the gRPC chain's low per-hop overhead and built-in deadline propagation (ADR-0002).

## Alternatives Considered (detail)

### Combined Retrieval/RAG service
Was the intermediate design; superseded once the user's more granular service list and its DDD justification (this ADR) were established.

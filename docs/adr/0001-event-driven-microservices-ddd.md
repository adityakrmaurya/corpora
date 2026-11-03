# ADR-0001: Adopt Event-Driven Microservices with Domain-Driven Design

## Status

Accepted

## Context and Problem Statement

An initial design proposed a single Spring Boot "modular monolith" for the document RAG system, with internal Gradle modules standing in for service boundaries. Stakeholders require genuine microservices: independently deployable services, each owning one bounded context, communicating over the network rather than in-process method calls. The system also needs to support many independent consumers reacting to the same domain facts (e.g., a document being parsed matters to chunking, cataloging, and audit simultaneously) without those consumers being coupled to each other or to a shared in-process call chain.

## Decision Drivers

- Independent deployability and scaling per bounded context.
- Multiple, independent, evolving consumers of the same domain facts (write-side).
- Long-term maintainability: service boundaries should track real domain boundaries (DDD bounded contexts), not incidental code organization.
- Explicit rejection of a monolith and of an under-decomposed "pragmatic" service split (see ADR-0008 for one concrete example of a bounded context this uncovered).

## Considered Options

1. Single modular monolith (internal packages/Gradle modules only).
2. A small number of pragmatically consolidated services (e.g., one "Retrieval/RAG Service" covering embedding + search + rerank + chat).
3. Full DDD bounded-context decomposition: one deployable service per domain responsibility, communicating via well-defined events/APIs.

## Decision Outcome

Chosen option: **3 — full DDD bounded-context decomposition**, yielding 14 services (see `docs/architecture/arc42/05-building-block-view.md` for the full list). Each service owns exactly one bounded context: its own aggregate/domain model, its own datastore schema, and a small, explicit set of inbound/outbound contracts (events or APIs). No service is introduced without an aggregate root and a clear "what this service does NOT own" statement (documented per-service in the building block view and `docs/architecture/arc42/12-glossary.md`).

## Consequences

**Good:**
- Each service can be understood, tested, deployed, and scaled independently.
- New consumers of an existing domain fact (e.g., a future analytics service) attach without modifying the producer.
- Bounded contexts map directly to team ownership boundaries if/when this grows past one team.

**Bad:**
- Significantly higher operational complexity than a monolith: 14 deployables, network calls where there used to be method calls, distributed tracing/observability becomes mandatory rather than optional (see ADR-0014 note on tracing).
- Requires disciplined contract versioning (see `docs/reference/events.md`) since services deploy independently.

## Alternatives Considered (detail)

### Single modular monolith
Rejected outright — no inter-service communication, no independent deployability, exactly the design this ADR supersedes.

### Pragmatic consolidation (e.g., 4-service split)
Considered and built as an intermediate design. Rejected because it re-introduced the coupling DDD is meant to avoid — e.g., bundling embedding, vector search, reranking, and chat orchestration into one service hides that these are different bounded contexts with different scaling profiles (see ADR-0009 on why Reranker is separate from Retrieval).

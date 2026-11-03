---
section: 8
title: Crosscutting concepts
owner: Unknown (to be assigned)
last-verified: 2026-11-03
verified-against: ADR-0001 to ADR-0014; the previous event catalog and component designs
---

# 8. Crosscutting concepts

Only concepts this system has. Each says how it works and where it will live. Nothing here is implemented yet.

## 8.1 Domain model and ubiquitous language

Every service owns exactly one bounded context with one aggregate root (ADR-0001). A term keeps the meaning of its own context; the same English word may mean different things in two contexts, which is expected in DDD. Aggregates and terms are in the [glossary](12-glossary.md).

Two aggregates are easy to confuse:

- **Document** (Document Catalog) is a mutable current-state projection, one row per document, with `currentStage`: `UPLOADED`, `PROCESSING`, `CHUNKED`, `EMBEDDING`, `INDEXED`, or `FAILED` or `DELETED`.
- **AuditLogEntry** (Audit Service) is immutable and append-only, including superseded, rejected, and failed events.

Merging them would mix two consistency and retention models (ADR-0008).

## 8.2 Event contracts and schema evolution

- Every event carries the envelope in the [event reference](../../reference/events.md): `eventId`, `occurredAt`, `producedBy`, `correlationId`, `causationId`, `schemaVersion`.
- Serialization is Avro or JSON Schema with Apicurio Registry. Every Kafka producer and consumer talks to the registry (model relationship tagged `Schema`).
- Additive changes stay on `*.v1`. A breaking change is published as `*.v2` in parallel with `*.v1` for a migration window.
- The partition key is `documentId`, giving strict per-document ordering.
- Large payloads use the claim-check pattern: the event carries a storage key into MinIO (`extractedContentStorageKey`, `chunkManifestStorageKey`). `ChunkCreated` and `ChunkEmbedded` inline their text and vector.
- Audit scope is an explicit topic list. A new event type enters audit scope on review, never automatically (ADR-0011).
- A machine-readable contract (AsyncAPI) does not exist yet. Topic names are Unknown (R-8).

## 8.3 Messaging reliability

| Mechanism | How it works |
|---|---|
| Transactional outbox | Every write-side producer writes its event row in the same database transaction as the business write. A poller relays rows to Kafka. There is never a commit followed by a separate publish |
| Idempotent producers | Producers are configured idempotent |
| Consumer commit rule | Offsets are committed only after successful persistence |
| Effectively-once | At-least-once delivery plus deduplication on `eventId` |
| Retry and dead-letter | Poison messages escalate through `retry-5s`, `retry-30s`, `retry-5m`, then a per-topic DLQ. DLQ depth is alertable in Prometheus. Replay is manual |
| Replay | Retained log; audit-relevant topics use long or never-delete retention so Audit Service can rebuild from offset zero (ADR-0011) |
| Raw-byte durability | MinIO holds the uploaded bytes before any downstream processing, so retries never need a re-upload |
| Read-side events | Fire-and-forget. If Kafka is unavailable the publish is logged and dropped or buffered locally, and the response is never blocked (R-4) |

The line between the synchronous gRPC chain and its asynchronous audit side effect is kept by convention and code review (ADR-0002). A publish that accidentally blocks would silently reintroduce the latency problem the ADR avoids.

## 8.4 Read-path orchestration

- Query Processor Service is the single orchestrator of the chat chain (orchestration, not choreography). It owns the total deadline, retry and circuit-breaking decisions, and the root trace span.
- Deadlines are propagated through gRPC. Each downstream call receives the remaining budget.
- LLM Router Service hides fallback from its callers: a provider failure reroutes inside the Router and the contract is identical either way (ADR-0010).
- Prompt and message assembly stays in Query Processor Service, which holds the orchestration context.
- The streamed answer is a typed `AnswerEvent` stream (`citations`, `token`, `done`, `error`). Citations are sent before tokens.

## 8.5 Security and access control

Layers, from the edge inward:

1. **Authentication.** Keycloak issues OIDC tokens. The API Gateway validates the JWT at the edge using Keycloak's JWKS. Coarse role checks stay in the JWT.
2. **Trusted identity context.** `tenant_id`, `acl_groups`, and `classification_ceiling` are resolved at the Gateway and passed downstream as trusted gRPC metadata. How downstream services establish that this metadata is trustworthy beyond the internal network is `Unknown`.
3. **Fine-grained authorization.** Upload and delete decisions on a specific corpus or document go to Authorization & Identity-Context Service over gRPC and are recorded as `AccessGranted` or `AccessDenied` events (ADR-0005).
4. **Query-time ACL filter.** Retrieval Service always builds an `ACLFilterExpression` from trusted claims. The user's natural-language `ExtractedFilterHint` is untrusted and is AND-merged afterwards, so it can only narrow the permitted set, never widen it. These two terms must not be confused ([glossary](12-glossary.md)).
5. **Database.** Least-privilege roles per Postgres instance. Retrieval Service's access to `embedding-db` is read-only by database role. Audit log updates and deletes are revoked at the database. Postgres Row-Level Security as an additional layer is possible (ADR-0003) and **not decided**.
6. **Network.** Only the Gateway, and Keycloak's user-facing endpoints if exposed, reach the public network ([§7](07-deployment-view.md)).

Every chunk, event, and query carries a `tenantId`.

## 8.6 Provider-agnostic model configuration

- Chat and embedding go through Spring AI `ChatModel` and `EmbeddingModel`, selected by `spring.ai.model.chat` and `spring.ai.model.embedding` plus a Spring profile.
- Ollama is the default profile and makes no external calls. Azure OpenAI, AWS Bedrock, and Anthropic are opt-in profiles.
- All four provider starters are bundled in the artifact, so a switch is a change of `SPRING_PROFILES_ACTIVE` with no rebuild.
- Chat and embedding providers are independent. Anthropic has no embeddings API, so it can serve chat only.
- A startup validator fails fast if the active embedding model's output dimension differs from the PGVector column dimension.
- Switching the embedding provider requires re-embedding the whole corpus. That is a manual step; no runbook exists yet (R-3).
- LLM Router Service adds live policy on top: tenant tier, capability (for example context window), and provider health with circuit breakers (ADR-0010).

## 8.7 Observability

- Every application container uses Micrometer and OpenTelemetry through Spring Boot and exports OTLP to the observability stack.
- The correlation ID is injected at the Gateway and propagated through gRPC metadata and Kafka headers, so one document's write-side journey and one chat request's read-side chain are each traceable end to end, including across Kafka hops (QS-7).
- Alerting on DLQ depth is specified. Further alerts, dashboards, and health groups are `Unknown`.

## 8.8 Persistence and data ownership

- One physical Postgres instance per data-owning service, with least-privilege roles per instance.
- Single-writer discipline: only Document Catalog writes the document projection; only Embedding Service writes the PGVector index.
- Chunk metadata (tenant, ACL groups, owner, classification, heading path, page span) is stored as JSONB or columns on the pgvector table and is filterable and indexable.
- Schema migration tool and index type (HNSW or IVFFlat) are `Unknown`.

## 8.9 Testing and build quality

- Build: one Gradle multi-module build, Java 25 toolchain, Checkstyle (Google style) with zero warnings on every service module.
- Tests: per-service unit tests; Testcontainers for every per-service Postgres instance, Kafka, and Keycloak; `docling-testcontainers` for a real Docling Serve.
- Two tests are release-blocking: the cross-tenant ACL test (QS-1) and the structure and table-chunking correctness test.
- Contract tests between services and architecture rule tests (for example ArchUnit) are `Unknown`.

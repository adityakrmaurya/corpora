---
section: 4
title: Solution strategy
owner: Unknown (to be assigned)
last-verified: 2026-11-03
verified-against: ADR-0001 to ADR-0014
---

# 4. Solution strategy

## 4.1 Approach per quality goal

| Quality goal | Scenario | Solution approach | Details |
|---|---|---|---|
| Q1 Security: isolation | QS-1 | A mandatory, server-derived ACL filter built from trusted JWT claims inside Retrieval Service; the user's own filter hint can only narrow results; a release-blocking cross-tenant test | [§5.2](05-building-block-view.md#52-level-2-important-building-blocks), [§8.5](08-crosscutting-concepts.md#85-security-and-access-control), ADR-0003, ADR-0005 |
| Q2 Data sovereignty | QS-9 | Self-hosted components only; Ollama as the default provider; cloud providers opt-in by profile | [§8.6](08-crosscutting-concepts.md#86-provider-agnostic-model-configuration), ADR-0003, ADR-0004 |
| Q3 Auditability | QS-5, QS-8 | Audit Service as a pure event-sourced consumer of an enumerated topic list, with replayable retention and DLQ alerting. No service calls it synchronously | [§8.3](08-crosscutting-concepts.md#83-messaging-reliability), ADR-0011 |
| Q4 Reliability of ingestion | QS-4, QS-8 | Transactional outbox, idempotent consumers with `eventId` deduplication, retry topics and DLQ, raw bytes durable in MinIO before processing | [§8.3](08-crosscutting-concepts.md#83-messaging-reliability), [§6.3](06-runtime-view.md#63-a-processing-stage-keeps-failing), ADR-0007 |
| Q5 Responsiveness of chat | QS-3 | Synchronous gRPC chain with one orchestrator that owns the deadline budget; audit publishing never blocks the response | [§8.4](08-crosscutting-concepts.md#84-read-path-orchestration), ADR-0002 |

## 4.2 Decomposition

- One deployable service per DDD bounded context, 14 in total including the API Gateway. Every service owns an aggregate, its own datastore, and a small set of explicit contracts (ADR-0001).
- CQRS-style split of communication. The write side (ingestion pipeline, lifecycle, audit) uses Kafka events. The read side (chat) uses synchronous gRPC orchestrated by Query Processor Service (ADR-0002).
- Database per service: one physical Postgres instance for each of nine data-owning services (ADR-0012).
- Ports-and-adapters inside services is visible in the component views in [§5.2](05-building-block-view.md#52-level-2-important-building-blocks). No rule enforcing it exists yet (R-2 in [§11](11-risks-and-technical-debt.md)).

## 4.3 Key technology decisions

| Topic | Decision | ADR |
|---|---|---|
| Event backbone | Apache Kafka (KRaft), Avro or JSON Schema with Apicurio | [0007](../../adr/0007-kafka-over-rabbitmq.md) |
| Vector store | PGVector on the Embedding Service's Postgres instance | [0003](../../adr/0003-pgvector-as-vector-store.md) |
| Document understanding | Docling Serve called through the official Java client | [0006](../../adr/0006-docling-serve-java-client-parsing-chunking.md) |
| Model access | Spring AI `ChatModel` and `EmbeddingModel`, selected by profile | [0004](../../adr/0004-provider-agnostic-model-config.md) |
| Identity | Keycloak for authentication; a narrow Authorization & Identity-Context Service for fine-grained decisions | [0005](../../adr/0005-authorization-identity-context-service.md) |
| Deployment | Docker Compose | [0013](../../adr/0013-docker-compose-over-kubernetes.md) |
| Language | Java 25 only for owned code | [0014](../../adr/0014-single-language-java-stack.md) |

## 4.4 Organisational decisions

None recorded. Team structure and ownership are Unknown ([§2.2](02-constraints.md#22-organisational-constraints)).

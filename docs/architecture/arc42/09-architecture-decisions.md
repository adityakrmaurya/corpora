---
section: 9
title: Architecture decisions
owner: Unknown (to be assigned)
last-verified: 2026-11-03
verified-against: docs/adr/0001 to 0014
---

# 9. Architecture decisions

Decisions are recorded as ADRs in [`docs/adr/`](../../adr) using the [template](../../adr/template.md). This page indexes them; it does not restate their rationale. The ADRs carry no date field.

| ADR | Title | Status |
|---|---|---|
| [0001](../../adr/0001-event-driven-microservices-ddd.md) | Adopt event-driven microservices with Domain-Driven Design | Accepted |
| [0002](../../adr/0002-cqrs-kafka-write-grpc-read.md) | CQRS topology split: Kafka for the write side, gRPC for the read side | Accepted |
| [0003](../../adr/0003-pgvector-as-vector-store.md) | PGVector as the vector store | Accepted |
| [0004](../../adr/0004-provider-agnostic-model-config.md) | Provider-agnostic chat and embedding model configuration via Spring AI | Accepted |
| [0005](../../adr/0005-authorization-identity-context-service.md) | Refocus "Authentication Service" to "Authorization & Identity-Context Service" | Accepted |
| [0006](../../adr/0006-docling-serve-java-client-parsing-chunking.md) | Parsing and chunking via Docling Serve, called from Java | Accepted |
| [0007](../../adr/0007-kafka-over-rabbitmq.md) | Kafka over RabbitMQ for the write-side event backbone | Accepted |
| [0008](../../adr/0008-document-catalog-lifecycle-service.md) | Add Document Catalog & Lifecycle Service as a bounded context | Accepted |
| [0009](../../adr/0009-separate-reranker-service.md) | Separate Reranker Service from Retrieval Service | Accepted |
| [0010](../../adr/0010-llm-router-service.md) | LLM Router Service as a distinct policy layer over Spring AI's ChatModel | Accepted |
| [0011](../../adr/0011-audit-service-event-sourced-consumer.md) | Audit Service as a pure event-sourced consumer | Accepted |
| [0012](../../adr/0012-database-per-service-postgres-instances.md) | Database per service: one physical Postgres instance per data-owning service | Accepted |
| [0013](../../adr/0013-docker-compose-over-kubernetes.md) | Docker Compose over Kubernetes for initial deployment | Accepted |
| [0014](../../adr/0014-single-language-java-stack.md) | Single-language (Java) service implementation stack | Accepted |

## Start here

New readers should read 0001 (why fourteen services), 0002 (why two communication styles), and 0012 (why nine databases) first. They explain most of the shape of [§5](05-building-block-view.md).

## Decisions visible in the design without an ADR

| Decision | Where it appears | Follow-up |
|---|---|---|
| Transactional outbox with a polling relay, rather than change data capture | [§8.3](08-crosscutting-concepts.md#83-messaging-reliability), Ingestion component view | Write an ADR |
| Retry topics (`retry-5s`, `retry-30s`, `retry-5m`) and per-topic DLQ | [§8.3](08-crosscutting-concepts.md#83-messaging-reliability) | Write an ADR, or fold into the outbox ADR |
| Trusted gRPC metadata for tenant and ACL claims | [§8.5](08-crosscutting-concepts.md#85-security-and-access-control) | Write an ADR covering how the metadata is trusted |
| Spring Cloud Gateway as the API Gateway technology | Model only; no document states the choice | Confirm and record |
| Keycloak as the identity provider | ADR-0005 treats it as given | Record the choice, including whether it ships in the Compose stack |
| Observability stack (Prometheus, Grafana, Tempo, Loki) and OpenTelemetry | [§8.7](08-crosscutting-concepts.md#87-observability) | Record the choice |
| Apicurio as schema registry | ADR-0007 | Covered; no action |

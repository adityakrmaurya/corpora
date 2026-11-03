# About the build order

Corpora has 14 services and about twenty infrastructure containers, and none is built yet. The earlier design fixed a 17-phase order, each phase buildable and testable before the next. This page keeps that order and explains what each phase depends on, using the relationships in [`workspace.dsl`](../architecture/workspace.dsl). The dependencies are derived from the model; the author of the original plan did not state them.

## The order and why

| Phase | Build | It needs first |
|---|---|---|
| 1 | Infrastructure scaffolding: `docker-compose.yml` with nine Postgres instances, Keycloak, Kafka, schema registry, Ollama, Docling Serve, MinIO, observability stack; root Gradle multi-module skeleton | Nothing. Every later service runs against these |
| 2 | API Gateway: routing, edge JWT validation, correlation-ID injection, SSE-to-gRPC translation for chat | Keycloak (phase 1) |
| 3 | Authorization & Identity-Context Service | Its Postgres instance. Ingestion and Catalog call it |
| 4 | Request Validator Service | Its Postgres instance. Ingestion calls it |
| 5 | Ingestion Service: streamed upload to MinIO, `DocumentUploaded` | Phases 3 and 4, because it calls both synchronously |
| 6 | Parsing Service | `DocumentUploaded` (phase 5), Docling Serve |
| 7 | Chunking Service | `DocumentParsed` (phase 6), Docling Serve |
| 8 | Embedding Service | `ChunkCreated` (phase 7), a model provider |
| 9 | Document Catalog & Lifecycle Service | Lifecycle events from phases 5 to 8; Authorization (phase 3) |
| 10 | Audit Service | Enough event types from earlier phases to consume |
| 11 | Retrieval Service | Vectors in `embedding-db` (phase 8) |
| 12 | Reranker Service | Nothing beyond phase 1 |
| 13 | LLM Router Service | Its Postgres instance, a model provider |
| 14 | Response Formatter Service | LLM Router (phase 13) |
| 15 | Query Processor Service | Retrieval, Reranker, Response Formatter (phases 11, 12, 14) |
| 16 | Cross-cutting: audit events on every service, Micrometer and OpenTelemetry, correlation-ID propagation through gRPC metadata and Kafka headers | All services |
| 17 | Testing and delivery: Testcontainers, the release-blocking tests, per-service images to an internal registry and a staged deploy | All services |

## Why the read side comes last

The read side depends on data the write side produces. Retrieval has nothing to search until Embedding Service has written vectors, and Query Processor needs all three downstream services before it can orchestrate. The write side has no such dependency on the read side, so it goes first and delivers an ingestible system that can be demonstrated on its own.

## A weakness of the order

Phase 16 adds instrumentation and audit wiring after every service exists. The architecture makes distributed tracing mandatory rather than optional (ADR-0001), and the correlation ID is what lets a failure in the pipeline be followed across Kafka hops. Every service built in phases 2 to 15 will therefore be retrofitted. Starting the correlation-ID and OpenTelemetry conventions in phase 2, and having each later service adopt them on creation, would avoid that rework. This is the author's opinion, not a decision; the owner chooses.

## See also

- [arc42 §5 Building block view](../architecture/arc42/05-building-block-view.md) for what each service is responsible for.
- [arc42 §10 Quality requirements](../architecture/arc42/10-quality-requirements.md) for the end-to-end scenarios the finished system must pass.

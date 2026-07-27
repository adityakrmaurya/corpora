# Implementation Order

The phased build order for the 14 services in `docs/architecture/c4-container.md`, referenced by the release-blocking tests in the component docs and by the project's task tracker. Each phase is buildable and testable before the next begins.

1. **Infra scaffolding** — `docker-compose.yml` (nine per-service Postgres instances per ADR-0012, Keycloak, Kafka + schema registry, Ollama, Docling Serve, MinIO, OTel stack), root Gradle multi-module skeleton.
2. **API Gateway** — routing, edge JWT validation, correlation-ID injection, SSE↔gRPC translation for the chat path.
3. **Authorization & Identity-Context Service** — policy data model, `AccessGranted`/`AccessDenied` events, gRPC contract.
4. **Request Validator Service** — quota/mime/malware/dedup policy, gRPC contract, `DocumentUploadRejected` event.
5. **Ingestion Service** — reactive (WebFlux) streamed upload → MinIO, `Upload` aggregate, `DocumentUploaded` event, calls to Validator/Authorization.
6. **Parsing Service** — `docling-serve-client` integration (`DoclingServeApi.convertSource`), MinIO persistence of the returned `DoclingDocument`; `DocumentParsed`/`DocumentParsingFailed` events.
7. **Chunking Service** — `docling-serve-client`'s `ChunkOperations` (`HybridChunkDocumentRequest`), mapping typed `Chunk` responses to `ChunkCreated`/`DocumentChunked` events.
8. **Embedding Service** — Spring AI `EmbeddingModel` invocation, PGVector write, completion counting; `ChunkEmbedded`/`DocumentEmbeddingCompleted` events.
9. **Document Catalog & Lifecycle Service** — `Document` state-machine projector, deletion saga, status/list/delete REST API.
10. **Audit Service** — Kafka consumer across the enumerated topic list (ADR-0011), append-only store, read-only query API.
11. **Retrieval Service** — embedding + PGVector search + ACL `Filter.Expression`, gRPC contract, `ChunksRetrieved` audit publisher.
12. **Reranker Service** — in-JVM DJL cross-encoder, MMR filtering, gRPC contract.
13. **LLM Router Service** — tenant-tier/capability/fallback routing policy wrapping Spring AI `ChatModel`, gRPC streaming contract.
14. **Response Formatter Service** — citation assembly, SSE event shaping, provider-shape normalization, bidi gRPC contract.
15. **Query Processor Service** — rewriting/intent classification, orchestration + deadline propagation across the whole read-side chain.
16. **Cross-cutting** — audit-event wiring on every service, Micrometer/OTel instrumentation, correlation-ID propagation through gRPC metadata and Kafka headers.
17. **Testing & CI/CD** — per-service unit tests; Testcontainers (each per-service Postgres instance, Kafka, Keycloak, `docling-testcontainers`); the release-blocking cross-tenant ACL test (`docs/architecture/c4-component-retrieval-service.md`) and structure/table-chunking test; Gradle build + per-service container images → internal registry → staged deploy.

## Verification (end-to-end)

1. Bring up infra + all 14 services; each reports healthy.
2. Upload a mixed batch (PDF with a table + nested headings, DOCX, PPTX, HTML); trace `DocumentUploaded → DocumentParsed → DocumentChunked → ChunkEmbedded* → DocumentEmbeddingCompleted` through Kafka and confirm Document Catalog reaches `INDEXED`.
3. Two Keycloak test users, different groups; ingest a doc ACL'd to one group; confirm the other user gets zero chunks/citations via chat (the release-blocking ACL test in `c4-component-retrieval-service.md`).
4. Chat request: confirm the `citations` SSE event arrives before token streaming begins, and the gRPC chain respects its total deadline budget under a simulated slow LLM Router response.
5. Kill a write-side service mid-job; confirm the Kafka message dead-letters after retry exhaustion, Document Catalog surfaces `FAILED`/`retryable`, and reprocessing resumes without re-uploading or re-parsing.
6. `./gradlew test` across all services green, including the cross-tenant ACL test and a structure/table-chunking correctness test.
7. Confirm a single document's write-side journey and a single chat request's read-side chain are both traceable end-to-end in Grafana/Tempo, including across Kafka hops.

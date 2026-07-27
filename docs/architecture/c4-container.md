# C4 Model — Level 2: Container Diagram

All 14 application services plus infrastructure. See ADR-0001 for why this is a full DDD decomposition rather than a monolith, ADR-0002 for the write-side/read-side protocol split shown here, and ADR-0012 for why every data-owning service gets its own physical Postgres instance rather than a shared cluster.

```mermaid
C4Container
    title Container Diagram — Corpora

    Person(user, "Knowledge Worker / Admin")

    System_Boundary(corpora, "Corpora") {
        Container(gateway, "API Gateway", "Spring Cloud Gateway (Reactor/Netty)", "Edge JWT validation, routing, CORS, rate limiting, SSE-to-gRPC translation")

        Boundary(writeSide, "Write Side (async, Kafka)") {
            Container(authz, "Authorization & Identity-Context Service", "Spring Boot / gRPC", "Fine-grained resource authz, AccessGranted/Denied events")
            Container(validator, "Request Validator Service", "Spring Boot / gRPC", "Quota, mime allow-list, malware scan, dedup policy gate")
            Container(ingestion, "Ingestion Service", "Spring Boot / WebFlux", "Streamed upload, Upload aggregate, DocumentUploaded event")
            Container(parsing, "Parsing Service", "Spring Boot", "Calls Docling Serve /convert; DocumentParsed event")
            Container(chunking, "Chunking Service", "Spring Boot", "Calls Docling Serve /chunk (HybridChunker); ChunkCreated/DocumentChunked events")
            Container(embedding, "Embedding Service", "Spring Boot / Spring AI", "Computes embeddings, writes PGVector; ChunkEmbedded/DocumentEmbeddingCompleted")
            Container(catalog, "Document Catalog & Lifecycle Service", "Spring Boot", "Document current-state projection, deletion saga")
            Container(audit, "Audit Service", "Spring Boot", "Append-only compliance log, pure Kafka consumer")
        }

        Boundary(readSide, "Read Side (sync, gRPC)") {
            Container(queryProcessor, "Query Processor Service", "Spring Boot / gRPC", "Query rewriting, chain orchestration, latency-budget owner")
            Container(retrieval, "Retrieval Service", "Spring Boot / Spring AI / gRPC", "Query embedding + PGVector search + ACL Filter.Expression")
            Container(reranker, "Reranker Service", "Spring Boot / DJL / gRPC", "Cross-encoder rerank + MMR diversity filter")
            Container(llmRouter, "LLM Router Service", "Spring Boot / Spring AI / gRPC", "Tenant-tier/capability/fallback model routing policy")
            Container(responseFormatter, "Response Formatter Service", "Spring Boot / gRPC", "Citation assembly, SSE event shaping")
        }

        Boundary(dataStores, "Data Stores (one dedicated Postgres instance per data-owning service — ADR-0012)") {
            ContainerDb(pgAuthz, "authorization-db", "PostgreSQL", "Policy/ACL data")
            ContainerDb(pgValidator, "request-validator-db", "PostgreSQL", "Validation-rule config")
            ContainerDb(pgIngestion, "ingestion-db", "PostgreSQL", "Submission/staging bookkeeping")
            ContainerDb(pgParsing, "parsing-db", "PostgreSQL", "Parse-job bookkeeping")
            ContainerDb(pgChunking, "chunking-db", "PostgreSQL", "ChunkSet/Chunk entities")
            ContainerDb(pgEmbedding, "embedding-db", "PostgreSQL + pgvector", "ChunkEmbedding bookkeeping + the shared PGVector index")
            ContainerDb(pgCatalog, "document-catalog-db", "PostgreSQL", "Document lifecycle projection")
            ContainerDb(pgAudit, "audit-db", "PostgreSQL", "Append-only compliance log")
            ContainerDb(pgLlmRouter, "llm-router-db", "PostgreSQL", "Routing policy + circuit-breaker state")
        }

        ContainerQueue(kafka, "Kafka", "Apache Kafka (KRaft)", "Write-side domain event backbone (ADR-0007)")
        ContainerDb(minio, "MinIO", "S3-compatible", "Raw uploads + claim-check payloads")
    }

    System_Ext(keycloak, "Keycloak", "OIDC Identity Provider")
    System_Ext(ollama, "Ollama / Cloud LLM Providers", "Chat + embedding models")
    System_Ext(doclingServe, "Docling Serve", "Document parsing/chunking engine")
    System_Ext(otel, "Observability Stack", "Prometheus / Grafana / Tempo / Loki")

    Rel(user, gateway, "HTTPS/SSE")
    Rel(gateway, ingestion, "REST", "upload")
    Rel(gateway, catalog, "REST", "status/list/delete")
    Rel(gateway, queryProcessor, "gRPC server-stream, translated to SSE", "chat")
    Rel(gateway, keycloak, "JWKS validation")

    Rel(ingestion, validator, "gRPC")
    Rel(ingestion, authz, "gRPC")
    Rel(catalog, authz, "gRPC")

    Rel(ingestion, kafka, "publish DocumentUploaded")
    Rel(validator, kafka, "publish DocumentUploadRejected")
    Rel(parsing, kafka, "consume/publish")
    Rel(chunking, kafka, "consume/publish")
    Rel(embedding, kafka, "consume/publish")
    Rel(catalog, kafka, "consume (all lifecycle events) / publish (deletion saga)")
    Rel(audit, kafka, "consume (enumerated topics, reviewed on addition — ADR-0011)")

    Rel(parsing, doclingServe, "convert", "docling-serve-client")
    Rel(chunking, doclingServe, "chunk", "docling-serve-client")
    Rel(embedding, ollama, "embed")
    Rel(embedding, pgEmbedding, "write vectors + bookkeeping", "PGVector + Postgres")

    Rel(queryProcessor, retrieval, "gRPC unary")
    Rel(queryProcessor, reranker, "gRPC unary")
    Rel(queryProcessor, responseFormatter, "gRPC bidi")
    Rel(responseFormatter, llmRouter, "gRPC server-stream")
    Rel(retrieval, pgEmbedding, "read vectors (read-only, cross-service)", "PGVector")
    Rel(retrieval, ollama, "embed query")
    Rel(retrieval, kafka, "publish ChunksRetrieved (async audit)")
    Rel(llmRouter, ollama, "chat completion")

    Rel(ingestion, minio, "stream upload")
    Rel(parsing, minio, "read source / write DoclingDocument")
    Rel(chunking, minio, "read source")

    Rel(authz, pgAuthz, "policy data")
    Rel(validator, pgValidator, "config data")
    Rel(ingestion, pgIngestion, "submission bookkeeping")
    Rel(parsing, pgParsing, "job bookkeeping")
    Rel(chunking, pgChunking, "ChunkSet/Chunk entities")
    Rel(catalog, pgCatalog, "Document projection")
    Rel(audit, pgAudit, "append-only log")
    Rel(llmRouter, pgLlmRouter, "routing policy/circuit-breaker state")

    Rel(gateway, otel, "traces/metrics")
    Rel(ingestion, otel, "traces/metrics")
    Rel(queryProcessor, otel, "traces/metrics")
```

## Notes

- Boundary grouping (write side / read side) mirrors ADR-0002's CQRS topology split, not a deployment/network boundary — both groups run in the same Compose network segment; see ADR-0013 for the Docker Compose topology and network segmentation.
- Every data-owning service gets its own dedicated **physical Postgres instance** (ADR-0012, revised from an initial shared-cluster/schema-per-service draft once weighed against this project's own stance against consolidating bounded contexts for operational convenience). No service ever connects to another service's database.
- `embedding-db` is the one deliberate cross-instance exception: it hosts both Embedding Service's own bookkeeping and the shared PGVector index (ADR-0003, ADR-0012). Embedding Service is PGVector's sole writer; Retrieval Service connects to `embedding-db` as a strictly read-only client — the only case in this system where a service reaches into another service's database, and it's read-only by DB role, not by convention alone.
- The release-blocking cross-tenant ACL test and the reranked-retrieval latency budget are documented in `docs/architecture/c4-component-retrieval-service.md` and `docs/architecture/c4-component-query-processor-service.md` respectively — see those files directly rather than an external plan document.

# Domain Event Catalog

All events use a standard envelope: `eventId` (dedup key), `occurredAt`, `producedBy`, `correlationId`, `causationId`, `schemaVersion`. Serialized via Avro/JSON Schema through a self-hosted schema registry (Apicurio). Additive changes stay on `*.v1`; breaking changes ship as `*.v2` with a dual-publish migration window. See ADR-0007 for why Kafka, ADR-0002 for the write/read-side split this catalog belongs to (write-side only — read-side audit events are listed separately below).

## Write-side events (Kafka)

| Event | Published by | Key fields | Consumed by |
|---|---|---|---|
| `DocumentUploaded` | Ingestion Service | documentId, tenantId, corpusId, storageKey, contentHash | Parsing, Document Catalog, Audit |
| `DocumentUploadRejected` | Request Validator | submissionId, tenantId, reason | Document Catalog, Audit |
| `DocumentParsed` | Parsing Service | documentId, parseVersion, parseJobId, extractedContentStorageKey (claim-check), pageCount, parserImplementation, originalStorageKey | Chunking, Document Catalog, Audit |
| `DocumentParsingFailed` | Parsing Service | documentId, failureReason, retryable | Document Catalog, Audit |
| `DocumentChunked` | Chunking Service | documentId, chunkSetId, chunkCount, chunkManifestStorageKey (claim-check) | Document Catalog, Audit |
| `ChunkCreated` | Chunking Service | documentId, chunkId, sequenceNumber, text (inlined), sourceAnchor (headings/page) | Embedding Service |
| `DocumentChunkingFailed` | Chunking Service | documentId, failureReason, retryable | Document Catalog, Audit |
| `ChunkEmbedded` | Embedding Service | chunkId, documentId, vector (inlined), embeddingModelId/Version, dimension | Terminal for indexing — PGVector write already done by Embedding Service itself |
| `ChunkEmbeddingFailed` | Embedding Service | chunkId, documentId, failureReason, retryable | Document Catalog, Audit |
| `DocumentEmbeddingCompleted` | Embedding Service | documentId, totalChunks, successfullyEmbedded, failed | Document Catalog (-> terminal `INDEXED` when successfullyEmbedded > 0), Audit |
| `AccessGranted` / `AccessDenied` | Authorization & Identity-Context Service | subjectId, tenantId, resourceType/Id, action, decision, policyId | Audit |
| `DocumentDeletionRequested` | Document Catalog | documentId, tenantId, requestedBy | Ingestion, Parsing, Chunking, Embedding (each purges + confirms) |
| `DocumentDeleted` | Document Catalog | documentId, confirmedPurges[] | Audit |

**Resolved coordination point**: since Embedding Service writes PGVector directly (no separate read-side "indexing" step — Retrieval Service only ever reads), `DocumentEmbeddingCompleted` *is* the terminal "queryable" signal. Document Catalog transitions `Document.currentStage` to `INDEXED` on that event; no additional event is needed from the read side.

## Read-side events (Kafka, fire-and-forget audit/analytics only — never on the critical path)

| Event | Published by | Key fields |
|---|---|---|
| `QueryReceived` | Query Processor | correlationId, tenantId, rawQueryText |
| `QueryRewritten` | Query Processor | correlationId, originalQuery, rewrittenQuery, intentClassification, extractedFilterHint |
| `ChunksRetrieved` | Retrieval Service | correlationId, candidateCount, topK, similarityScores[], retrievalLatencyMs, embeddingModelUsed |
| `RerankPerformed` | Reranker Service | correlationId, inputCount, outputCount, rerankModelUsed, rerankLatencyMs |
| `LlmInvoked` | LLM Router Service | correlationId, providerUsed, modelUsed, routingReason, promptTokenCount, completionTokenCount, latencyMs |
| `ResponseFormatted` | Response Formatter | correlationId, citationCount, streamDurationMs |
| `QueryAnswered` | Query Processor (published last) | correlationId, tenantId, totalLatencyMs, success, errorCode |

## Delivery semantics

Idempotent producers; consumers commit offsets only after successful persistence (at-least-once + `eventId` dedup = effectively-once). Poison messages escalate through retry topics (`retry-5s` → `retry-30s` → `retry-5m`) before landing in a per-topic DLQ (Prometheus-alertable, manually replayable). All write-side producers use the **transactional outbox pattern** — event row written in the same DB transaction as the business write, relayed via poller — never a naked commit-then-publish (see `c4-component-ingestion-service.md` for a concrete example).

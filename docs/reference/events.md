# Domain event reference

Reference for the domain events carried on Kafka. This page is hand-written because no AsyncAPI file or schema registry content exists yet (design phase, no service code). Once the contracts exist, generate this page from them and delete the tables below.

Concepts behind these events: [arc42 §8.2 Event contracts](../architecture/arc42/08-crosscutting-concepts.md#82-event-contracts-and-schema-evolution) and [§8.3 Messaging reliability](../architecture/arc42/08-crosscutting-concepts.md#83-messaging-reliability).

## Envelope

Every event carries these fields.

| Field | Meaning |
|---|---|
| `eventId` | Deduplication key |
| `occurredAt` | Time the event occurred |
| `producedBy` | Producing service |
| `correlationId` | Ties one document's write-side journey, or one chat request's read-side chain, together |
| `causationId` | Event or request that caused this event |
| `schemaVersion` | Version of the payload schema |

## Write-side events

Published through the transactional outbox of the producing service.

| Event | Published by | Key fields | Consumed by |
|---|---|---|---|
| `DocumentUploaded` | Ingestion Service | documentId, tenantId, corpusId, storageKey, contentHash | Parsing Service, Document Catalog & Lifecycle Service, Audit Service |
| `DocumentUploadRejected` | Request Validator Service | submissionId, tenantId, reason | Document Catalog & Lifecycle Service, Audit Service |
| `DocumentParsed` | Parsing Service | documentId, parseVersion, parseJobId, extractedContentStorageKey (claim-check), pageCount, parserImplementation, originalStorageKey | Chunking Service, Document Catalog & Lifecycle Service, Audit Service |
| `DocumentParsingFailed` | Parsing Service | documentId, failureReason, retryable | Document Catalog & Lifecycle Service, Audit Service |
| `DocumentChunked` | Chunking Service | documentId, chunkSetId, chunkCount, chunkManifestStorageKey (claim-check) | Document Catalog & Lifecycle Service, Audit Service |
| `ChunkCreated` | Chunking Service | documentId, chunkId, sequenceNumber, text (inlined), sourceAnchor (headings, page) | Embedding Service |
| `DocumentChunkingFailed` | Chunking Service | documentId, failureReason, retryable | Document Catalog & Lifecycle Service, Audit Service |
| `ChunkEmbedded` | Embedding Service | chunkId, documentId, vector (inlined), embeddingModelId, embeddingModelVersion, dimension | None specified |
| `ChunkEmbeddingFailed` | Embedding Service | chunkId, documentId, failureReason, retryable | Document Catalog & Lifecycle Service, Audit Service |
| `DocumentEmbeddingCompleted` | Embedding Service | documentId, totalChunks, successfullyEmbedded, failed | Document Catalog & Lifecycle Service, Audit Service |
| `AccessGranted`, `AccessDenied` | Authorization & Identity-Context Service | subjectId, tenantId, resourceType, resourceId, action, decision, policyId | Audit Service |
| `DocumentDeletionRequested` | Document Catalog & Lifecycle Service | documentId, tenantId, requestedBy | Ingestion Service, Parsing Service, Chunking Service, Embedding Service |
| `DocumentDeleted` | Document Catalog & Lifecycle Service | documentId, confirmedPurges[] | Audit Service |

## Read-side events

Audit and analytics only. Published fire-and-forget; never on the critical path of a response.

| Event | Published by | Key fields |
|---|---|---|
| `QueryReceived` | Query Processor Service | correlationId, tenantId, rawQueryText |
| `QueryRewritten` | Query Processor Service | correlationId, originalQuery, rewrittenQuery, intentClassification, extractedFilterHint |
| `ChunksRetrieved` | Retrieval Service | correlationId, candidateCount, topK, similarityScores[], retrievalLatencyMs, embeddingModelUsed |
| `RerankPerformed` | Reranker Service | correlationId, inputCount, outputCount, rerankModelUsed, rerankLatencyMs |
| `LlmInvoked` | LLM Router Service | correlationId, providerUsed, modelUsed, routingReason, promptTokenCount, completionTokenCount, latencyMs |
| `ResponseFormatted` | Response Formatter Service | correlationId, citationCount, streamDurationMs |
| `QueryAnswered` | Query Processor Service (published last) | correlationId, tenantId, totalLatencyMs, success, errorCode |

## Topics, versions, and delivery

| Property | Value |
|---|---|
| Serialization | Avro or JSON Schema, registered in the schema registry (Apicurio) |
| Partition key | `documentId` (write side) |
| Version policy | Additive changes stay on `*.v1`. Breaking changes ship as `*.v2` with a dual-publish migration window |
| Producer guarantee | Idempotent producers. Write-side producers relay from a transactional outbox |
| Consumer guarantee | Offsets committed only after successful persistence. At-least-once delivery plus `eventId` deduplication |
| Retry path | `retry-5s`, then `retry-30s`, then `retry-5m`, then a per-topic DLQ |
| Topic names | Unknown. ADR-0011 gives examples only: `document.uploaded.v1`, `document.parsed.v1`, `access.granted.v1` |
| Partition counts, retention | Unknown, except that audit-relevant topics use long or never-delete retention (ADR-0011) |

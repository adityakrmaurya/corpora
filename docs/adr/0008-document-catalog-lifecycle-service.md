# ADR-0008: Add Document Catalog & Lifecycle Service as a Bounded Context

## Status

Accepted

## Context and Problem Statement

The user's named service list (Gateway, Authentication, Request Validator, Ingestion, Parsing, Chunking, Embedding, Retrieval, Query Processor, Reranker, LLM Router, Response Formatter, Audit) has no service that owns "what is the current state of document X across its whole journey." Ingestion Service's jurisdiction ends at intake; Parsing/Chunking/Embedding each know only their own slice. Without a dedicated owner, a client would need to reassemble four services' Kafka event streams itself just to answer "is my upload done yet," leaking event-plumbing into a user-facing concern.

## Decision Drivers

- DDD analysis surfaced a genuine gap, not requested scope creep — flagged explicitly rather than silently added.
- Distinct from Audit Service: this context projects **current state** (mutable, one row per document), Audit projects **immutable history** (append-only, every event including superseded/rejected/failed ones). Conflating the two was identified as a common mistake worth avoiding explicitly.
- Document deletion is a genuine multi-service saga (blob, chunk rows, vector rows must all be purged) that needs a coordinator.

## Considered Options

1. No dedicated service — clients/UI reassemble state from Kafka topics directly.
2. Fold lifecycle projection into Audit Service.
3. Add a dedicated **Document Catalog & Lifecycle Service** owning the `Document` aggregate (current-state projection) and the deletion saga.

## Decision Outcome

Chosen option: **3**. Document Catalog consumes the write-side lifecycle events (`DocumentUploaded`, `DocumentUploadRejected`, `DocumentParsed`/`Failed`, `DocumentChunked`/`Failed`, `DocumentEmbeddingCompleted`) and projects a single `Document` row per document with `currentStage` (`UPLOADED → PROCESSING → CHUNKED → EMBEDDING → INDEXED`, or `FAILED`/`DELETED`). It is the sole writer of this projection (single-writer discipline — no other service writes to `document_catalog_service`). It also owns document deletion: publishing `DocumentDeletionRequested`, which Ingestion/Parsing/Chunking/Embedding each consume, purge their own data for, and confirm — Parsing Service included, since it persists both parse-job bookkeeping and the parsed `DoclingDocument` blob in MinIO and would otherwise retain deleted documents' data indefinitely — before Document Catalog publishes the terminal `DocumentDeleted`.

## Consequences

**Good:**
- One authoritative, queryable answer to "what's the status of my document" via a simple REST API, with no event-plumbing leaking to clients.
- Deletion is a real, coordinated saga rather than an ad hoc per-service delete with no completion guarantee.

**Bad:**
- One more service and one more Kafka consumer group to operate; justified by the concrete gap it closes.

## Alternatives Considered (detail)

### Fold into Audit Service
Rejected — Audit's aggregate is an immutable append-only log; Document Catalog's aggregate is a mutable current-state projection. Merging them would conflate two different consistency/retention models under one roof.

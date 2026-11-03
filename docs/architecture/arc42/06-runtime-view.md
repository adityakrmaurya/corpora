---
section: 6
title: Runtime view
owner: Unknown (to be assigned)
last-verified: 2026-11-03
verified-against: ADR-0002, ADR-0005, ADR-0006, ADR-0007, ADR-0008, ADR-0011; the previous event catalog and component designs
---

# 6. Runtime view

Four scenarios, chosen because each shows a different consistency or failure property. Participants are the building blocks of [§5](05-building-block-view.md). Key for the C4 dynamic diagrams: numbers give the order of calls; dashed arrow = asynchronous event through Kafka; solid arrow = synchronous call.

## 6.1 A document is uploaded and indexed

Part 1: acceptance and the outbox.

<!-- generated from docs/architecture/workspace.dsl, view "document-upload"; do not edit by hand -->
```mermaid
graph LR
  linkStyle default fill:#ffffff

  subgraph diagram ["Dynamic diagram: upload a document (Corpora)"]
    style diagram fill:#ffffff,stroke:#ffffff

    subgraph 7 ["Corpora"]
      style 7 fill:#ffffff,stroke:#0b4884,color:#0b4884

      subgraph group1 ["Write side (Kafka events)"]
        style group1 fill:#ffffff,stroke:#cccccc,color:#cccccc,stroke-dasharray:5

        10["<div style='font-weight: bold'>Request Validator Service</div><div style='font-size: 70%; margin-top: 0px'>[Container: Java 25, Spring Boot, gRPC]</div><div style='font-size: 80%; margin-top:10px'>Applies submission policy to<br />candidate uploads: quota,<br />MIME allow-list, malware scan<br />result, content-hash dedup.</div>"]
        style 10 fill:#438dd5,stroke:#2e6295,color:#ffffff
        11["<div style='font-weight: bold'>Ingestion Service</div><div style='font-size: 70%; margin-top: 0px'>[Container: Java 25, Spring Boot, WebFlux]</div><div style='font-size: 80%; margin-top:10px'>Accepts streamed uploads,<br />stages raw bytes in MinIO,<br />mints the documentId, and<br />publishes DocumentUploaded.</div>"]
        style 11 fill:#438dd5,stroke:#2e6295,color:#ffffff
        9["<div style='font-weight: bold'>Authorization & Identity-Context Service</div><div style='font-size: 70%; margin-top: 0px'>[Container: Java 25, Spring Boot, gRPC]</div><div style='font-size: 80%; margin-top:10px'>Decides whether a principal<br />may act on a corpus or<br />document; owns corpus- and<br />document-level grants.</div>"]
        style 9 fill:#438dd5,stroke:#2e6295,color:#ffffff
      end

      44["<div style='font-weight: bold'>Kafka</div><div style='font-size: 70%; margin-top: 0px'>[Container: Apache Kafka (KRaft)]</div><div style='font-size: 80%; margin-top:10px'>Event backbone. Retains<br />events for replay; documentId<br />is the partition key. Hosts<br />retry topics and per-topic<br />DLQs.</div>"]
      style 44 fill:#438dd5,stroke:#2e6295,color:#ffffff
      46["<div style='font-weight: bold'>MinIO</div><div style='font-size: 70%; margin-top: 0px'>[Container: MinIO (S3 API)]</div><div style='font-size: 80%; margin-top:10px'>Object storage for raw<br />uploads, extracted content,<br />and chunk manifests.</div>"]
      style 46 fill:#438dd5,stroke:#2e6295,color:#ffffff
      51[("<div style='font-weight: bold'>ingestion-db</div><div style='font-size: 70%; margin-top: 0px'>[Container: PostgreSQL]</div><div style='font-size: 80%; margin-top:10px'>Private store of Ingestion<br />Service: Upload aggregate and<br />its outbox.</div>")]
      style 51 fill:#438dd5,stroke:#2e6295,color:#ffffff
      8["<div style='font-weight: bold'>API Gateway</div><div style='font-size: 70%; margin-top: 0px'>[Container: Java 25, Spring Cloud Gateway]</div><div style='font-size: 80%; margin-top:10px'>Single entry point: TLS<br />termination, edge JWT<br />validation, routing, CORS,<br />rate limiting, correlation-ID<br />injection, SSE-to-gRPC<br />translation for chat.</div>"]
      style 8 fill:#438dd5,stroke:#2e6295,color:#ffffff
    end

    1["<div style='font-weight: bold'>Knowledge Worker</div><div style='font-size: 70%; margin-top: 0px'>[Person]</div><div style='font-size: 80%; margin-top:10px'>Uploads documents and asks<br />questions against the corpus.</div>"]
    style 1 fill:#08427b,stroke:#052e56,color:#ffffff

    1-- "<div>1. Uploads a document</div><div style='font-size: 70%'>[HTTPS]</div>" -->8
    8-- "<div>2. Forwards the upload</div><div style='font-size: 70%'>[HTTP (multipart)]</div>" -->11
    11-- "<div>3. Streams raw bytes</div><div style='font-size: 70%'>[S3 API]</div>" -->46
    11-- "<div>4. Validates quota, MIME<br />type, malware result, and<br />duplicate hash</div><div style='font-size: 70%'>[gRPC]</div>" -->10
    11-- "<div>5. Checks upload permission</div><div style='font-size: 70%'>[gRPC]</div>" -->9
    11-- "<div>6. Writes the Upload and the<br />DocumentUploaded outbox row<br />in one transaction</div><div style='font-size: 70%'>[JDBC]</div>" -->51
    11-. "<div>7. Relays DocumentUploaded<br />from the outbox</div><div style='font-size: 70%'>[Kafka protocol]</div>" .->44

  end
```

View key `document-upload`.

Part 2: processing, driven only by Kafka events.

<!-- generated from docs/architecture/workspace.dsl, view "document-processing"; do not edit by hand -->
```mermaid
graph LR
  linkStyle default fill:#ffffff

  subgraph diagram ["Dynamic diagram: process an uploaded document (Corpora)"]
    style diagram fill:#ffffff,stroke:#ffffff

    subgraph 7 ["Corpora"]
      style 7 fill:#ffffff,stroke:#0b4884,color:#0b4884

      subgraph group1 ["Write side (Kafka events)"]
        style group1 fill:#ffffff,stroke:#cccccc,color:#cccccc,stroke-dasharray:5

        18["<div style='font-weight: bold'>Parsing Service</div><div style='font-size: 70%; margin-top: 0px'>[Container: Java 25, Spring Boot]</div><div style='font-size: 80%; margin-top:10px'>Converts documents into<br />structured content (headings,<br />tables, page provenance) via<br />Docling Serve and persists<br />the result.</div>"]
        style 18 fill:#438dd5,stroke:#2e6295,color:#ffffff
        19["<div style='font-weight: bold'>Chunking Service</div><div style='font-size: 70%; margin-top: 0px'>[Container: Java 25, Spring Boot]</div><div style='font-size: 80%; margin-top:10px'>Splits documents into<br />retrieval-sized chunks<br />carrying a heading path and<br />source anchor, via Docling<br />Serve.</div>"]
        style 19 fill:#438dd5,stroke:#2e6295,color:#ffffff
        20["<div style='font-weight: bold'>Embedding Service</div><div style='font-size: 70%; margin-top: 0px'>[Container: Java 25, Spring Boot, Spring AI]</div><div style='font-size: 80%; margin-top:10px'>Embeds chunks with the active<br />embedding provider. Sole<br />writer of the PGVector index.</div>"]
        style 20 fill:#438dd5,stroke:#2e6295,color:#ffffff
        21["<div style='font-weight: bold'>Document Catalog & Lifecycle Service</div><div style='font-size: 70%; margin-top: 0px'>[Container: Java 25, Spring Boot]</div><div style='font-size: 80%; margin-top:10px'>Projects each document's<br />current lifecycle stage and<br />coordinates document<br />deletion.</div>"]
        style 21 fill:#438dd5,stroke:#2e6295,color:#ffffff
      end

      44["<div style='font-weight: bold'>Kafka</div><div style='font-size: 70%; margin-top: 0px'>[Container: Apache Kafka (KRaft)]</div><div style='font-size: 80%; margin-top:10px'>Event backbone. Retains<br />events for replay; documentId<br />is the partition key. Hosts<br />retry topics and per-topic<br />DLQs.</div>"]
      style 44 fill:#438dd5,stroke:#2e6295,color:#ffffff
      46["<div style='font-weight: bold'>MinIO</div><div style='font-size: 70%; margin-top: 0px'>[Container: MinIO (S3 API)]</div><div style='font-size: 80%; margin-top:10px'>Object storage for raw<br />uploads, extracted content,<br />and chunk manifests.</div>"]
      style 46 fill:#438dd5,stroke:#2e6295,color:#ffffff
      47["<div style='font-weight: bold'>Docling Serve</div><div style='font-size: 70%; margin-top: 0px'>[Container: Docling Serve (Python, vendored image)]</div><div style='font-size: 80%; margin-top:10px'>Vendored<br />document-understanding<br />engine: converts and chunks<br />documents. Official image, no<br />owned code.</div>"]
      style 47 fill:#438dd5,stroke:#2e6295,color:#ffffff
      48["<div style='font-weight: bold'>Ollama</div><div style='font-size: 70%; margin-top: 0px'>[Container: Ollama]</div><div style='font-size: 80%; margin-top:10px'>Default self-hosted chat and<br />embedding model runtime.</div>"]
      style 48 fill:#438dd5,stroke:#2e6295,color:#ffffff
      54[("<div style='font-weight: bold'>embedding-db</div><div style='font-size: 70%; margin-top: 0px'>[Container: PostgreSQL, pgvector]</div><div style='font-size: 80%; margin-top:10px'>Embedding Service bookkeeping<br />and its outbox, plus the<br />shared PGVector index.<br />Written by Embedding Service<br />only; read by Retrieval<br />Service.</div>")]
      style 54 fill:#438dd5,stroke:#2e6295,color:#ffffff
    end

    44-. "<div>1. Delivers DocumentUploaded</div><div style='font-size: 70%'>[Kafka protocol]</div>" .->18
    18-- "<div>2. Requests conversion</div><div style='font-size: 70%'>[HTTP/REST]</div>" -->47
    18-- "<div>3. Stores extracted content<br />(claim-check)</div><div style='font-size: 70%'>[S3 API]</div>" -->46
    18-. "<div>4. Publishes DocumentParsed</div><div style='font-size: 70%'>[Kafka protocol]</div>" .->44
    44-. "<div>5. Delivers DocumentParsed</div><div style='font-size: 70%'>[Kafka protocol]</div>" .->19
    19-- "<div>6. Requests hybrid chunking</div><div style='font-size: 70%'>[HTTP/REST]</div>" -->47
    19-. "<div>7. Publishes ChunkCreated per<br />chunk, then DocumentChunked</div><div style='font-size: 70%'>[Kafka protocol]</div>" .->44
    44-. "<div>8. Delivers ChunkCreated</div><div style='font-size: 70%'>[Kafka protocol]</div>" .->20
    20-- "<div>9. Embeds chunk text</div><div style='font-size: 70%'>[HTTP/REST]</div>" -->48
    20-- "<div>10. Writes the vector to the<br />PGVector index</div><div style='font-size: 70%'>[JDBC]</div>" -->54
    20-. "<div>11. Publishes<br />DocumentEmbeddingCompleted</div><div style='font-size: 70%'>[Kafka protocol]</div>" .->44
    44-. "<div>12. Delivers<br />DocumentEmbeddingCompleted:<br />stage becomes INDEXED</div><div style='font-size: 70%'>[Kafka protocol]</div>" .->21

  end
```

View key `document-processing`. Failure events (`DocumentParsingFailed`, `DocumentChunkingFailed`, `ChunkEmbeddingFailed`) and the audit fan-out to Audit Service are left out of the picture; see [§6.3](#63-a-processing-stage-keeps-failing) and the [event reference](../../reference/events.md).

Notable aspects:

- **Where atomicity ends.** The `Upload` aggregate and its `DocumentUploaded` outbox row commit in one database transaction. Everything after the relay is eventually consistent.
- **Ordering.** `documentId` is the partition key, so all events of one document are ordered.
- **Claim-check.** Parsed content and chunk manifests are stored in MinIO and referenced by storage key; `ChunkCreated` carries its text inline.
- **Terminal signal.** Embedding Service writes PGVector itself, so `DocumentEmbeddingCompleted` is the terminal "queryable" signal. Document Catalog moves the document to `INDEXED` on that event when `successfullyEmbedded > 0`. A document with some failed chunks is therefore `INDEXED` (R-5 in [§11](11-risks-and-technical-debt.md)).
- **Rejected uploads.** If Request Validator Service rejects a submission it publishes `DocumentUploadRejected`, consumed by Document Catalog and Audit Service.

## 6.2 A question is answered

<!-- generated from docs/architecture/workspace.dsl, view "ask-question"; do not edit by hand -->
```mermaid
graph LR
  linkStyle default fill:#ffffff

  subgraph diagram ["Dynamic diagram: ask a question (Corpora)"]
    style diagram fill:#ffffff,stroke:#ffffff

    subgraph 7 ["Corpora"]
      style 7 fill:#ffffff,stroke:#0b4884,color:#0b4884

      subgraph group1 ["Read side (gRPC)"]
        style group1 fill:#ffffff,stroke:#cccccc,color:#cccccc,stroke-dasharray:5

        23["<div style='font-weight: bold'>Query Processor Service</div><div style='font-size: 70%; margin-top: 0px'>[Container: Java 25, Spring Boot, gRPC]</div><div style='font-size: 80%; margin-top:10px'>Orchestrates one question end<br />to end and owns the total<br />deadline budget.</div>"]
        style 23 fill:#438dd5,stroke:#2e6295,color:#ffffff
        34["<div style='font-weight: bold'>Retrieval Service</div><div style='font-size: 70%; margin-top: 0px'>[Container: Java 25, Spring Boot, Spring AI, gRPC]</div><div style='font-size: 80%; margin-top:10px'>Embeds the query and runs an<br />ACL-filtered similarity<br />search over PGVector.</div>"]
        style 34 fill:#438dd5,stroke:#2e6295,color:#ffffff
        41["<div style='font-weight: bold'>Reranker Service</div><div style='font-size: 70%; margin-top: 0px'>[Container: Java 25, DJL, gRPC]</div><div style='font-size: 80%; margin-top:10px'>Re-scores candidate chunks<br />with a cross-encoder and<br />removes near-duplicates with<br />MMR.</div>"]
        style 41 fill:#438dd5,stroke:#2e6295,color:#ffffff
        42["<div style='font-weight: bold'>Response Formatter Service</div><div style='font-size: 70%; margin-top: 0px'>[Container: Java 25, Spring Boot, gRPC]</div><div style='font-size: 80%; margin-top:10px'>Assembles citations and<br />shapes the answer into a<br />typed stream of citations,<br />token, done, and error<br />events.</div>"]
        style 42 fill:#438dd5,stroke:#2e6295,color:#ffffff
        43["<div style='font-weight: bold'>LLM Router Service</div><div style='font-size: 70%; margin-top: 0px'>[Container: Java 25, Spring Boot, Spring AI, gRPC]</div><div style='font-size: 80%; margin-top:10px'>Chooses the chat provider and<br />model per request by tenant<br />tier, capability, and<br />provider health; falls back<br />on failure.</div>"]
        style 43 fill:#438dd5,stroke:#2e6295,color:#ffffff
      end

      48["<div style='font-weight: bold'>Ollama</div><div style='font-size: 70%; margin-top: 0px'>[Container: Ollama]</div><div style='font-size: 80%; margin-top:10px'>Default self-hosted chat and<br />embedding model runtime.</div>"]
      style 48 fill:#438dd5,stroke:#2e6295,color:#ffffff
      54[("<div style='font-weight: bold'>embedding-db</div><div style='font-size: 70%; margin-top: 0px'>[Container: PostgreSQL, pgvector]</div><div style='font-size: 80%; margin-top:10px'>Embedding Service bookkeeping<br />and its outbox, plus the<br />shared PGVector index.<br />Written by Embedding Service<br />only; read by Retrieval<br />Service.</div>")]
      style 54 fill:#438dd5,stroke:#2e6295,color:#ffffff
      8["<div style='font-weight: bold'>API Gateway</div><div style='font-size: 70%; margin-top: 0px'>[Container: Java 25, Spring Cloud Gateway]</div><div style='font-size: 80%; margin-top:10px'>Single entry point: TLS<br />termination, edge JWT<br />validation, routing, CORS,<br />rate limiting, correlation-ID<br />injection, SSE-to-gRPC<br />translation for chat.</div>"]
      style 8 fill:#438dd5,stroke:#2e6295,color:#ffffff
    end

    1["<div style='font-weight: bold'>Knowledge Worker</div><div style='font-size: 70%; margin-top: 0px'>[Person]</div><div style='font-size: 80%; margin-top:10px'>Uploads documents and asks<br />questions against the corpus.</div>"]
    style 1 fill:#08427b,stroke:#052e56,color:#ffffff

    1-- "<div>1. Asks a question</div><div style='font-size: 70%'>[HTTPS]</div>" -->8
    8-- "<div>2. Forwards the request with<br />trusted tenant and ACL claims</div><div style='font-size: 70%'>[gRPC]</div>" -->23
    23-- "<div>3. Requests candidate chunks</div><div style='font-size: 70%'>[gRPC]</div>" -->34
    34-- "<div>4. Embeds the query</div><div style='font-size: 70%'>[HTTP/REST]</div>" -->48
    34-- "<div>5. Runs the ACL-filtered<br />similarity search</div><div style='font-size: 70%'>[JDBC]</div>" -->54
    23-- "<div>6. Requests reranking</div><div style='font-size: 70%'>[gRPC]</div>" -->41
    23-- "<div>7. Opens FormatStream with<br />the reranked context</div><div style='font-size: 70%'>[gRPC (bidirectional streaming)]</div>" -->42
    42-- "<div>8. Requests streamed chat<br />completion</div><div style='font-size: 70%'>[gRPC]</div>" -->43
    43-- "<div>9. Requests chat completion<br />from the selected provider</div><div style='font-size: 70%'>[HTTP/REST]</div>" -->48

  end
```

View key `ask-question`.

Notable aspects:

- **Trust boundary.** The Gateway validates the JWT. Tenant, ACL groups, and classification ceiling reach Query Processor and Retrieval as trusted gRPC metadata. Retrieval builds the ACL filter from them; the user's own filter hint can only narrow it ([§8.5](08-crosscutting-concepts.md#85-security-and-access-control)).
- **One deadline.** Query Processor owns the total budget and propagates the remaining deadline on every downstream call. The budget value is `TBD` (QS-3).
- **Streaming order.** The `citations` event reaches the client before token streaming begins.
- **Request lifecycle.** An `AnswerRequest` moves through received, understood, retrieved, reranked, generation in progress, answered. It is request-scoped and not persisted.
- **Audit.** Each read-side service publishes its audit event fire-and-forget. Kafka unavailability never fails or delays the answer.

## 6.3 A processing stage keeps failing

Shown for Parsing Service; every write-side consumer follows the same path.

```mermaid
sequenceDiagram
    autonumber
    participant K as Kafka (topic of the event)
    participant P as Parsing Service
    participant R as Retry topics (retry-5s, retry-30s, retry-5m)
    participant D as DLQ (per topic)
    participant C as Document Catalog & Lifecycle Service
    participant O as Operator
    K->>P: DocumentUploaded
    P->>P: processing fails, offset not committed
    P->>R: escalate to retry-5s
    R->>P: redeliver after the delay, still failing
    P->>R: escalate to retry-30s, then retry-5m
    R->>D: retries exhausted, dead-letter (depth is alertable)
    Note over P,C: DocumentParsingFailed (failureReason, retryable) is published and Catalog sets FAILED. Timing is Unknown
    O->>D: replay manually after the cause is fixed
    D->>P: reprocess from the stored raw bytes, no re-upload
```

Notable aspects:

- Offsets are committed only after successful persistence. Delivery is at-least-once; `eventId` deduplication makes the effect once.
- Raw bytes are durable in MinIO before processing starts, so recovery never needs a re-upload.
- **Unknown:** the exact moment `DocumentParsingFailed` is published (per attempt or after exhaustion), who moves a message between retry topics, and the replay procedure. The design states only the topic sequence, the DLQ, and that replay is manual. A how-to page is due once the procedure exists.

## 6.4 A document is deleted

Deletion is a saga coordinated by Document Catalog & Lifecycle Service. No diagram is drawn because the confirmation step is not specified.

1. The Gateway forwards the delete request to Document Catalog & Lifecycle Service, which asks Authorization & Identity-Context Service whether the caller may delete the document.
2. Document Catalog publishes `DocumentDeletionRequested`.
3. Ingestion, Parsing, Chunking, and Embedding each consume it, purge their own data (raw bytes, parse and chunk records, extracted content, vectors), and confirm.
4. Document Catalog publishes `DocumentDeleted` with `confirmedPurges[]`; the document becomes `DELETED`. Audit Service records the event.

**Unknown:** how a purge confirmation travels. The event catalog lists no confirmation event, yet `DocumentDeleted` carries `confirmedPurges[]`. See R-8 in [§11](11-risks-and-technical-debt.md).

# C4 Model — Level 3: Component Diagram — Ingestion Service

Representative write-side service. Bounded context: `Upload`/`Submission` — see ADR-0001, ADR-0008.

```mermaid
C4Component
    title Component Diagram — Ingestion Service

    Container_Boundary(ingestion, "Ingestion Service") {
        Component(uploadController, "UploadController", "Spring WebFlux Controller", "Accepts reactive multipart upload (a Flux of PartEvent/FilePartEvent), streams to MinIO without buffering the whole file")
        Component(validatorClient, "RequestValidatorClient", "gRPC stub", "Synchronous pre-commit policy check (quota/mime/malware/dedup)")
        Component(authzClient, "AuthorizationClient", "gRPC stub", "Synchronous fine-grained authz check (can this principal upload to this corpus)")
        Component(uploadService, "UploadService", "Domain service", "Owns the Upload aggregate: stages bytes, mints documentId, transitions PENDING->UPLOADED")
        Component(outbox, "TransactionalOutbox", "Spring Data JPA + poller", "Writes DocumentUploaded in the same DB transaction as the Upload row; relays to Kafka")
        Component(kafkaProducer, "DocumentUploadedProducer", "spring-kafka", "Publishes DocumentUploaded (partition key: documentId)")
        ComponentDb(ingestionSchema, "ingestion-db", "Dedicated Postgres instance (ADR-0012)", "Submission/staging bookkeeping only — no parsed content, no chunks")
    }

    Container(minio, "MinIO", "Object Storage")
    Container(validatorSvc, "Request Validator Service")
    Container(authzSvc, "Authorization & Identity-Context Service")
    ContainerQueue(kafka, "Kafka")

    Rel(uploadController, minio, "stream raw bytes", "S3 API, non-blocking")
    Rel(uploadController, validatorClient, "validate before commit")
    Rel(validatorClient, validatorSvc, "gRPC")
    Rel(uploadController, authzClient, "authorize upload")
    Rel(authzClient, authzSvc, "gRPC")
    Rel(uploadController, uploadService, "on validation+authz success")
    Rel(uploadService, ingestionSchema, "persist Upload row")
    Rel(uploadService, outbox, "same-transaction event write")
    Rel(outbox, kafkaProducer, "relay")
    Rel(kafkaProducer, kafka, "publish document.uploaded.v1")
```

## Notes

- **Transactional outbox, not commit-then-publish**: the `DocumentUploaded` event row is written in the same DB transaction as the `Upload` aggregate write, then relayed by a poller — avoids the dual-write problem (a crash between DB commit and Kafka publish silently losing the event). Every write-side producer follows this same pattern.
- **Retry semantics**: bounded retry with exponential backoff+jitter for transient connectivity failures to Validator/Authorization; 4xx application errors (bad format, denied) fail fast, never retried.
- Because raw bytes are durable in MinIO before any downstream processing begins, retrying a failed `PROCESSING` stage later (Parsing Service) never requires re-upload.

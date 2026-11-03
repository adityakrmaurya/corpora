---
section: 12
title: Glossary
owner: Unknown (to be assigned)
last-verified: 2026-11-03
verified-against: the previous ubiquitous-language document; ADR-0001 to ADR-0014
---

# 12. Glossary

One group of entries per bounded context (ADR-0001). A term has the meaning given here only within its own context; the same word may differ in another context, and that is not a naming bug. Entries marked *(inferred)* are used in the design without a definition; the owner confirms them.

## Bounded-context terms

| Term | Context | Definition |
|---|---|---|
| AuthorizationDecision, PolicyEvaluation (aggregate root) | Authorization & Identity-Context Service | Result of evaluating whether a subject may perform an action on a resource |
| Policy | Authorization & Identity-Context Service | A corpus- or document-level grant rule, distinct from Keycloak's coarse realm roles |
| Submission Policy | Request Validator Service | Domain rules a candidate upload must pass before Ingestion creates an `Upload`: quota, MIME allow-list, malware scan result, content-hash dedup |
| Upload, Submission (aggregate root) | Ingestion Service | The act of intake: staging bytes and minting the canonical `documentId`. Its jurisdiction ends at handoff; it does not track parse, chunk, or embed status |
| Staging Reference | Ingestion Service | Object-storage pointer to durably persisted raw bytes |
| ParsedDocument (aggregate root, keyed by `documentId` and `parseVersion`) | Parsing Service | Structured representation returned by Docling Serve: headings, tables, page provenance |
| Extracted Content | Parsing Service | Normalized structural output, stored in object storage by claim-check and never inlined in an event |
| ChunkSet, Chunk (aggregate root and entities) | Chunking Service | A document's retrieval-sized segments, each with a `headings[]` path and a `sourceAnchor` (page or heading provenance for citation) |
| Chunking Strategy | Chunking Service | `hybrid` (token-budget-aware, default) or `hierarchical` (pure structure, no token ceiling, opt-in for short well-bounded document types) |
| ChunkEmbedding (aggregate root, identity = `chunkId` and `embeddingModelVersion`) | Embedding Service | A computed vector with the model and version that produced it. Model version is part of identity on purpose |
| Document (aggregate root) | Document Catalog & Lifecycle Service | Current-state projection of a document's journey: `currentStage`, `currentVersion`. Mutable, one row per document |
| Lifecycle Stage | Document Catalog & Lifecycle Service | `UPLOADED`, `PROCESSING`, `CHUNKED`, `EMBEDDING`, `INDEXED`; or `FAILED`, `DELETED` |
| AuditLogEntry | Audit Service | Immutable, append-only compliance record. The aggregate is the log itself |
| AnswerRequest (aggregate root, request-scoped) | Query Processor Service | One question's lifecycle: received, understood, retrieved, reranked, generation in progress, answered |
| RetrievalPlan | Query Processor Service | The rewritten query plus decomposition and intent that drive retrieval |
| ExtractedFilterHint | Query Processor Service | A user-stated, natural-language-derived constraint. **Untrusted: it can only narrow the ACL-permitted result set, never widen it.** This entry is the canonical statement of that guarantee |
| CandidateSet (aggregate root, request-scoped) | Retrieval Service | The bounded result of one similarity search |
| ACLFilterExpression | Retrieval Service | The mandatory, server-derived Spring AI `Filter.Expression` built from trusted JWT claims. Never confuse with `ExtractedFilterHint` |
| RerankedSet (aggregate root, request-scoped) | Reranker Service | The cross-encoder-reordered, MMR-diversity-filtered subset of a `CandidateSet` |
| RoutingDecision (aggregate root) | LLM Router Service | Which configured chat model and provider was selected for a request, and why (tenant tier, capability, health fallback) |
| FallbackChain | LLM Router Service | Ordered list of providers a tenant falls back to when the primary fails |
| FormattedAnswer (aggregate root, request-scoped) | Response Formatter Service | The citation-annotated, provider-shape-normalized answer as a typed `AnswerEvent` stream (`citations`, `token`, `done`, `error`) |
| Citation | Response Formatter Service | Structured pointer (`documentId`, `chunkId`, heading path, page) back to source material used for an answer |
| API Gateway | none | Purely technical edge concern with no bounded context, aggregate, or domain event |

## Cross-cutting terms

| Term | Definition |
|---|---|
| Tenant | Top-level access-control boundary. Every chunk, event, and query carries a `tenantId` |
| Corpus *(inferred)* | A named collection of documents against which grants and queries are scoped; carried as `corpusId` on `DocumentUploaded` |
| Correlation ID | Identifier tying one document's write-side journey, or one chat request's read-side chain, across every service and every Kafka hop |
| Claim-check | Storing a large payload in object storage and passing only its storage key in the event |
| Transactional outbox | Writing the event row in the same database transaction as the business change, then relaying it to Kafka, so no event is lost between commit and publish |
| DLQ | Per-topic dead-letter queue holding messages that exhausted their retries; depth is alertable, replay is manual |
| MMR | Maximal marginal relevance: diversity filtering that removes near-duplicate chunks |
| ACL | Access control list attached to chunk metadata (`acl_groups`), evaluated at query time |
| Bounded context | A service-sized area of the domain with its own model and language (ADR-0001) |

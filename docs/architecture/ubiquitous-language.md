# Ubiquitous Language Glossary

One entry per bounded context (ADR-0001). Each service's terms should only be used with this meaning within that service's own code and documentation — the same English word can mean different things in different contexts, which is expected in DDD and not a naming bug to "fix" globally.

## API Gateway
- No bounded context, no aggregate, no domain event — a purely technical edge concern (TLS termination, edge JWT validation, routing, CORS, rate limiting, correlation-ID injection). Deliberately excluded from the rest of this glossary's "one entry per bounded context" scope for the same reason ADR-0005 gives plain authentication no domain of its own: a component that only relays/validates has nothing to name in the ubiquitous language.

## Authorization & Identity-Context Service
- **AuthorizationDecision / PolicyEvaluation** (aggregate root) — the result of evaluating whether a subject may perform an action on a resource.
- **Policy** — a corpus/document-level grant rule, distinct from Keycloak's coarse realm roles.

## Request Validator Service
- **Submission Policy** — the set of domain rules (quota, mime allow-list, malware scan result, content-hash dedup) a candidate upload must pass before Ingestion Service creates an `Upload`.

## Ingestion Service
- **Upload / Submission** (aggregate root) — the act of intake: staging bytes, minting the canonical `documentId`. Jurisdiction ends at handoff — this context does not track parse/chunk/embed status.
- **Staging Reference** — the object-storage pointer to durably-persisted raw bytes.

## Parsing Service
- **ParsedDocument** (aggregate root, keyed by documentId + parseVersion) — the structured representation Docling Serve returns: headings, tables, page provenance.
- **Extracted Content** — the normalized structural output, persisted to object storage via claim-check (never inlined in an event).

## Chunking Service
- **ChunkSet / Chunk** (aggregate root + entities) — a document's retrieval-sized segments, each carrying a `headings[]` path (structural depth) and a `sourceAnchor` (page/heading provenance for citation).
- **Chunking Strategy** — `hybrid` (token-budget-aware, default) vs `hierarchical` (pure structure, no token ceiling, opt-in for short well-bounded document types).

## Embedding Service
- **ChunkEmbedding** (aggregate root, identity = chunkId + embeddingModelVersion — deliberately, since model version is part of identity) — a computed vector plus the model/version that produced it.

## Document Catalog & Lifecycle Service
- **Document** (aggregate root) — the current-state projection of a document's journey: `currentStage`, `currentVersion`. Distinct from Audit's immutable history — Catalog is mutable, one row per document.
- **Lifecycle Stage** — `UPLOADED → PROCESSING → CHUNKED → EMBEDDING → INDEXED`, or `FAILED`/`DELETED`.

## Audit Service
- **AuditLogEntry** — an immutable, append-only compliance record. The aggregate here is the log itself, not a business entity.

## Query Processor Service
- **AnswerRequest** (aggregate root, request-scoped/ephemeral) — one user question's full lifecycle: received → understood → retrieved → reranked → generation-in-progress → answered.
- **RetrievalPlan** — the rewritten query plus decomposition/intent used to drive downstream retrieval.
- **ExtractedFilterHint** — a user-stated, natural-language-derived constraint. Explicitly untrusted: can only narrow the ACL-permitted result set, never widen it. **This is the canonical statement of that guarantee** — the component diagrams reference this entry rather than re-deriving it in their own words.

## Retrieval Service
- **CandidateSet** (aggregate root, request-scoped) — the bounded result of one similarity search.
- **ACLFilterExpression** — the mandatory, server-derived Spring AI `Filter.Expression` built from trusted JWT claims. Never confuse with `ExtractedFilterHint` (untrusted, narrowing-only).

## Reranker Service
- **RerankedSet** (aggregate root, request-scoped) — the cross-encoder-reordered, MMR-diversity-filtered subset of a `CandidateSet`.

## LLM Router Service
- **RoutingDecision** (aggregate root) — which configured chat model/provider was selected for a request, and why (tenant tier, capability requirement, or health-based fallback).
- **FallbackChain** — the ordered list of providers a tenant falls back to on primary-provider failure.

## Response Formatter Service
- **FormattedAnswer** (aggregate root, request-scoped) — the citation-annotated, provider-shape-normalized answer, expressed as a typed `AnswerEvent` stream (`citations`/`token`/`done`/`error`).
- **Citation** — a structured pointer (documentId, chunkId, heading path, page) back to the source material used for an answer.

## Cross-cutting terms (used the same way everywhere)
- **Tenant** — the top-level access-control boundary; every chunk, event, and query carries a `tenantId`.
- **Correlation ID** — the identifier tying one document's full write-side journey, or one chat request's full read-side chain, across every service and (for the write side) every Kafka hop.

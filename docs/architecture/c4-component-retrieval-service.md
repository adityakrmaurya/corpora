# C4 Model — Level 3: Component Diagram — Retrieval Service

Owns the single highest-risk piece of logic in the system: ACL enforcement at query time. Bounded context: `CandidateSet` — see ADR-0003, ADR-0012.

```mermaid
C4Component
    title Component Diagram — Retrieval Service

    Container_Boundary(retrieval, "Retrieval Service") {
        Component(findCandidates, "FindCandidatesEndpoint", "gRPC unary", "Entry point from Query Processor")
        Component(queryEmbedder, "QueryEmbedder", "Spring AI EmbeddingModel", "Turns rewritten_query_text into a vector using the currently active embedding provider")
        Component(aclFilterBuilder, "AccessControlFilterExpressionBuilder", "Domain service — HIGHEST RISK LOGIC", "Builds the mandatory Spring AI Filter.Expression from trusted tenant_id/acl_groups gRPC metadata: tenant_id == ':t' AND (acl_groups in [...] OR owner == ':sub')")
        Component(hintMerger, "UserHintMerger", "Domain service", "ANDs the untrusted ExtractedFilterHint onto the ACL expression — can only narrow, structurally cannot widen past it")
        Component(similaritySearch, "SimilaritySearchService", "PgVectorStore.similaritySearch", "Executes the ANN query with the combined Filter.Expression")
        ComponentDb(pgvectorReader, "PGVector (read-only)", "embedding-db (ADR-0012)", "This service NEVER writes here — Embedding Service is the sole writer, this is the one deliberate cross-instance connection in the system")
        Component(auditPublisher, "AsyncAuditPublisher", "Kafka producer, fire-and-forget", "Publishes ChunksRetrieved — never blocks the response, mirrors Query Processor's own AsyncAuditPublisher")
    }

    Container(ollama, "Ollama / active embedding provider")
    ContainerQueue(kafka, "Kafka")

    Rel(findCandidates, queryEmbedder, "1. embed query")
    Rel(queryEmbedder, ollama, "gRPC/REST per active provider")
    Rel(findCandidates, aclFilterBuilder, "2. build mandatory ACL filter")
    Rel(aclFilterBuilder, hintMerger, "3. AND-merge user's narrowing hint")
    Rel(hintMerger, similaritySearch, "4. execute filtered search")
    Rel(similaritySearch, pgvectorReader, "SELECT ... WHERE filter (read-only)")
    Rel(similaritySearch, auditPublisher, "5. fire-and-forget, alongside returning candidates")
    Rel(auditPublisher, kafka, "publish ChunksRetrieved")
```

## Notes

- **Why the `Filter.Expression` is built here, not in Query Processor**: `Filter.Expression` is a `VectorStore`-specific construct; keeping the translation inside Retrieval Service avoids leaking PGVector/Spring AI `VectorStore` API knowledge into a service that has no business knowing it.
- **The one test that must never regress**: user A (group X) and user B (not in X) query the same corpus — B must receive zero candidates/citations from anything ACL'd to X. This is a release-blocking test (see `docs/architecture/implementation-order.md`'s Verification section), and `AccessControlFilterExpressionBuilder` is the component it's testing.
- **Defense in depth**: an optional post-retrieval re-check of each returned chunk's `acl_groups` against the caller's groups is recommended in application code, guarding against any filter-expression bug or partial filter-DSL support, independent of this component's correctness.
- The embedding provider used here must match the one used at index time (Embedding Service) — see ADR-0004's dimension-mismatch fail-fast check, which is enforced at service startup, not per-query.

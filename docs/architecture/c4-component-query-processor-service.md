# C4 Model — Level 3: Component Diagram — Query Processor Service

Read-side orchestrator. Bounded context: `AnswerRequest` — see ADR-0002 for why this chain is synchronous gRPC, not event-driven.

```mermaid
C4Component
    title Component Diagram — Query Processor Service

    Container_Boundary(qp, "Query Processor Service") {
        Component(chatEntrypoint, "ChatStreamEndpoint", "gRPC server-streaming", "Entry point from the Gateway; receives RawQuery, returns a stream of AnswerEvent")
        Component(rewriter, "QueryRewriter", "Domain service", "Pronoun/ellipsis resolution against ConversationContext, typo correction, multi-part decomposition into a RetrievalPlan")
        Component(intentClassifier, "IntentClassifier", "Domain service", "factual QA vs summarization vs comparison — affects top_k, rerank aggressiveness, prompt template")
        Component(filterHintExtractor, "FilterHintExtractor", "Domain service", "Parses user-stated constraints into ExtractedFilterHint — explicitly untrusted, narrows only")
        Component(orchestrator, "AnswerOrchestrator", "Saga-style coordinator", "Owns the AnswerRequest aggregate + the total gRPC deadline budget across every downstream call")
        Component(deadlineManager, "DeadlineManager", "gRPC Context deadline propagation", "Sets/propagates the total latency budget; enables deterministic cutoffs (e.g. skip rerank under time pressure)")
        Component(retrievalClient, "RetrievalClient", "gRPC stub")
        Component(rerankerClient, "RerankerClient", "gRPC stub")
        Component(formatterClient, "ResponseFormatterClient", "gRPC bidi stub")
        Component(auditPublisher, "AsyncAuditPublisher", "Kafka producer, fire-and-forget", "QueryReceived/QueryRewritten/QueryAnswered — never blocks the response")
    }

    Container(retrieval, "Retrieval Service")
    Container(reranker, "Reranker Service")
    Container(responseFormatter, "Response Formatter Service")
    ContainerQueue(kafka, "Kafka")

    Rel(chatEntrypoint, rewriter, "1. rewrite")
    Rel(chatEntrypoint, intentClassifier, "2. classify intent")
    Rel(chatEntrypoint, filterHintExtractor, "3. extract filter hints")
    Rel(chatEntrypoint, orchestrator, "4. orchestrate")
    Rel(orchestrator, deadlineManager, "enforces budget across all calls")
    Rel(orchestrator, retrievalClient, "FindCandidates (unary)")
    Rel(retrievalClient, retrieval, "gRPC")
    Rel(orchestrator, rerankerClient, "Rerank (unary)")
    Rel(rerankerClient, reranker, "gRPC")
    Rel(orchestrator, formatterClient, "FormatStream (bidi) — relays reranked context + LLM tokens")
    Rel(formatterClient, responseFormatter, "gRPC")
    Rel(chatEntrypoint, auditPublisher, "fire-and-forget, after/alongside response")
    Rel(auditPublisher, kafka, "publish read-side audit events")
```

## Notes

- **Orchestration, not choreography** (ADR-0002 rationale applied concretely here): `AnswerOrchestrator` is the single owner of the total latency budget, retry/circuit-breaking logic, and the root trace span — a choreographed chain (Retrieval calling Reranker directly, etc.) would have no single place to enforce a bounded total response time.
- **Security invariant enforced at the boundary, not here**: `tenant_id`/`acl_groups`/`classification_ceiling` arrive already-resolved from the Gateway/Keycloak as trusted gRPC metadata. `FilterHintExtractor`'s output is an `ExtractedFilterHint` — see `docs/architecture/ubiquitous-language.md` for the canonical narrow-only guarantee that term carries. The actual ACL `Filter.Expression` is built inside Retrieval Service (see `c4-component-retrieval-service.md`), never here.
- Async audit events (`auditPublisher`) are fire-and-forget: if Kafka is unavailable, the publish is logged and dropped/buffered locally — it never throws or blocks the synchronous response path.

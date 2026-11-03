---
section: 3
title: Context and scope
owner: Unknown (to be assigned)
last-verified: 2026-11-03
verified-against: ADR-0003, ADR-0004, ADR-0005, ADR-0006, ADR-0013; the previous context design
---

# 3. Context and scope

## 3.1 Business context

<!-- generated from docs/architecture/workspace.dsl, view "context"; do not edit by hand -->
```mermaid
graph TB
  linkStyle default fill:#ffffff

  subgraph diagram ["System Context diagram for Corpora"]
    style diagram fill:#ffffff,stroke:#ffffff

    1["<div style='font-weight: bold'>Knowledge Worker</div><div style='font-size: 70%; margin-top: 0px'>[Person]</div><div style='font-size: 80%; margin-top:10px'>Uploads documents and asks<br />questions against the corpus.</div>"]
    style 1 fill:#08427b,stroke:#052e56,color:#ffffff
    2["<div style='font-weight: bold'>Corpus Administrator</div><div style='font-size: 70%; margin-top: 0px'>[Person]</div><div style='font-size: 80%; margin-top:10px'>Manages corpora, document<br />ACLs, and tenant and routing<br />policy.</div>"]
    style 2 fill:#08427b,stroke:#052e56,color:#ffffff
    3["<div style='font-weight: bold'>Compliance / Audit Officer</div><div style='font-size: 70%; margin-top: 0px'>[Person]</div><div style='font-size: 80%; margin-top:10px'>Reviews the audit trail: who<br />accessed what, and why.</div>"]
    style 3 fill:#08427b,stroke:#052e56,color:#ffffff
    4["<div style='font-weight: bold'>Keycloak</div><div style='font-size: 70%; margin-top: 0px'>[Software System]</div><div style='font-size: 80%; margin-top:10px'>OIDC identity provider.<br />Source of truth for users,<br />groups, and tenants.</div>"]
    style 4 fill:#6b6b6b,stroke:#4a4a4a,color:#ffffff
    5["<div style='font-weight: bold'>Cloud LLM Providers</div><div style='font-size: 70%; margin-top: 0px'>[Software System]</div><div style='font-size: 80%; margin-top:10px'>Opt-in Azure OpenAI, AWS<br />Bedrock, or Anthropic,<br />selected by Spring profile<br />instead of the default<br />Ollama.</div>"]
    style 5 fill:#6b6b6b,stroke:#4a4a4a,color:#ffffff
    6["<div style='font-weight: bold'>Observability Stack</div><div style='font-size: 70%; margin-top: 0px'>[Software System]</div><div style='font-size: 80%; margin-top:10px'>Prometheus, Grafana, Tempo,<br />and Loki: receives metrics,<br />traces, and logs.</div>"]
    style 6 fill:#6b6b6b,stroke:#4a4a4a,color:#ffffff
    7["<div style='font-weight: bold'>Corpora</div><div style='font-size: 70%; margin-top: 0px'>[Software System]</div><div style='font-size: 80%; margin-top:10px'>Ingests, indexes, and answers<br />questions over enterprise<br />documents, enforcing access<br />control per document.</div>"]
    style 7 fill:#1168bd,stroke:#0b4884,color:#ffffff

    1-- "<div>Uploads documents, tracks<br />status, and asks questions<br />using</div><div style='font-size: 70%'>[HTTPS]</div>" -->7
    2-- "<div>Manages corpora, document<br />ACLs, and routing policy<br />using</div><div style='font-size: 70%'>[HTTPS]</div>" -->7
    3-- "<div>Queries the audit trail using</div><div style='font-size: 70%'>[HTTPS]</div>" -->7
    7-- "<div>Validates JWTs and resolves<br />claims with</div><div style='font-size: 70%'>[OIDC, JWKS]</div>" -->4
    7-- "<div>Requests chat completions and<br />embeddings from (opt-in<br />profiles)</div><div style='font-size: 70%'>[HTTPS]</div>" -->5
    7-- "<div>Exports metrics, traces, and<br />logs to</div><div style='font-size: 70%'>[OTLP]</div>" -->6

  end
```

Key: each box prints its type. Dark blue = person. Blue = Corpora. Grey = external system. Arrow = dependency from the initiator to the target, labelled with intent and `[protocol]`.

View key `context` in [`workspace.dsl`](../workspace.dsl).

### Where the system boundary lies

Rule used throughout this documentation:

- A **container of Corpora** is a separately runnable application or data store that Corpora's own Docker Compose deployment runs and that Corpora cannot work without. This includes vendored images (Kafka, MinIO, Docling Serve, Ollama, Apicurio Registry) and every Postgres instance.
- An **external system** is a platform capability that holds no Corpora domain data and takes no part in Corpora's own processing: the identity provider, the observability stack, and the opt-in cloud model providers.

Consequence: Keycloak is external because it is the source of truth for users, groups, and tenants (ADR-0005), not for documents. MinIO, Docling Serve, and Ollama are containers because Corpora's documents and processing steps live in them.

### Communication partners

| Partner | Input to Corpora | Output from Corpora | Channel |
|---|---|---|---|
| Knowledge Worker | Documents to upload; chat questions; status and delete requests | Upload outcome; document status; streamed answer with citations | HTTPS through the API Gateway; chat answers as server-sent events |
| Corpus Administrator | Management of corpora, document ACLs, tenant and routing policy | Unknown | HTTPS. **Unknown:** no API or service for these functions is defined in the design (see [§11](11-risks-and-technical-debt.md), R-8) |
| Compliance / Audit Officer | Audit queries | Audit records: who accessed what, and why | HTTPS. Audit Service offers a read-only query API; **Unknown:** how a caller reaches it, because the design defines no gateway route (R-8) |
| Keycloak | Signing keys (JWKS); user, group, and tenant claims inside the JWT presented by the user | Nothing beyond key requests | OIDC, HTTPS (JWKS), requested by the API Gateway |
| Cloud LLM Providers (opt-in) | Chat completions and embeddings | Prompts and chunk or query text | HTTPS, active only after a Spring profile change (ADR-0004) |
| Observability Stack | Nothing | Metrics, traces, logs | OTLP |

Risky interfaces:

- **Cloud LLM Providers.** With a cloud profile active, document text and queries leave the self-hosted boundary. The default profile uses Ollama and makes no external calls (ADR-0004).
- **Corpus Administrator and Compliance Officer.** Both are drawn as users, but their entry path into the system is undefined.

## 3.2 Technical context

| Interface | Between | Protocol | Notes |
|---|---|---|---|
| User traffic | Users and API Gateway | HTTPS | Gateway terminates TLS and validates the JWT at the edge |
| Token key retrieval | API Gateway and Keycloak | HTTPS (JWKS) | |
| Upload | API Gateway and Ingestion Service | HTTP multipart | Reactive, streamed to MinIO without buffering |
| Status, list, delete | API Gateway and Document Catalog & Lifecycle Service | HTTP/REST | |
| Chat | API Gateway and Query Processor Service | gRPC server streaming | The Gateway translates SSE to gRPC streaming. Tenant, ACL groups, and classification ceiling travel as trusted gRPC metadata |
| Write-side events | Services and Kafka | Kafka protocol | Schemas in the registry; see [events reference](../../reference/events.md) |
| Read-side calls | Query Processor Service and downstream services | gRPC | One propagated deadline |
| Model calls | Services and Ollama or cloud providers | HTTP/REST, HTTPS | Provider chosen by `spring.ai.model.chat` and `spring.ai.model.embedding` (ADR-0004) |
| Telemetry | All application containers and the observability stack | OTLP | |

Internal topology is in [§5](05-building-block-view.md) and [§7](07-deployment-view.md).

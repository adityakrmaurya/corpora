---
section: 11
title: Risks and technical debt
owner: Unknown (to be assigned)
last-verified: 2026-11-03
verified-against: ADR-0001 to ADR-0014; the previous container, component, and event designs
---

# 11. Risks and technical debt

Ordered by the author's assessment of impact. Urgency is also the author's assessment; the owner re-ranks. Owners are `Unknown` because the project defines none.

| ID | Risk or debt | Impact | Urgency | Mitigation or remediation | Owner |
|---|---|---|---|---|---|
| R-1 | Query-time ACL enforcement is the highest-risk logic. A bug in `AccessControlFilterExpressionBuilder`, or partial filter-DSL support in Spring AI, leaks documents across users or tenants | Confidentiality breach | High | Release-blocking cross-tenant test (QS-1). Decide on the post-retrieval `acl_groups` re-check (recommended, not decided) and on Postgres Row-Level Security (possible, not decided) | Unknown |
| R-2 | The whole architecture is unimplemented. Component views are design intent and no rule enforces them | Docs may drift from code from the first commit | High | Re-verify each section as each service lands; add ArchUnit rules; update "Where the code lives" in [§5](05-building-block-view.md) | Unknown |
| R-3 | Retrieval Service reads `embedding-db`, so Embedding Service's schema, pgvector index, and embedding dimension are a shared contract. An `embedding-db` outage stops both indexing and answering. Switching embedding provider forces a full manual re-embed with no runbook | Coupling; long recovery after provider switch | Medium | Read-only DB role; startup dimension check. Write a how-to for re-embedding | Unknown |
| R-4 | Read-side audit events are fire-and-forget and may be dropped when Kafka is unavailable, while audit completeness is a compliance requirement (ADR-0011) | Missing audit records for queries | High | Decide which read-side events are compliance-critical; use a local buffer or outbox for them, or accept and document the loss | Unknown |
| R-5 | A document moves to `INDEXED` when `successfullyEmbedded > 0`, so a document with failed chunks is queryable but incomplete, silently | Answers omit parts of a document | Medium | Expose `failed` count in the status API; define a completeness threshold | Unknown |
| R-6 | Compose deployment: one instance of each service, one Docling Serve shared by Parsing and Chunking, one Ollama, Kafka broker count Unknown, nine Postgres instances. About twenty infrastructure containers to operate | Single points of failure; large operational footprint (ADR-0012, ADR-0013) | Medium | Define HA and backup per component in [§7](07-deployment-view.md); revisit Kubernetes when a scale requirement appears | Unknown |
| R-7 | Synchronous dependency chains. Upload depends on Request Validator and Authorization; chat depends on five services in a row, then a model provider | One failing hop fails the request | Medium | Deadline propagation; circuit breakers in LLM Router; define per-hop budgets (QS-3) | Unknown |
| R-8 | Design gaps and unknowns (list below) | Unbuildable or inconsistent areas | High | Resolve the listed items with the owner, then update the model and docs | Unknown |
| R-9 | `ChunkCreated` carries chunk text and `ChunkEmbedded` carries the full vector inline, with hundreds of chunk events per large document (ADR-0007). `ChunkEmbedded` has no named consumer | Large messages and retained log volume for no consumer | Low | Check broker message size limits; drop `ChunkEmbedded` or its vector if truly terminal | Unknown |
| R-10 | Parsing Service and Chunking Service each call Docling Serve for the same source (accepted in ADR-0006) | Redundant computation, a load multiplier on Docling Serve | Low | Revisit if Docling Serve accepts a pre-parsed document | Unknown |
| R-11 | Quality goals, owners, requirements source, retention, and capacity numbers are not recorded; the goals in §1.2 are assumed | Wrong priorities; unmeasurable scenarios | Medium | Review with stakeholders; fill `TBD` values in [§10](10-quality-requirements.md) | Unknown |

## R-8: open design items

1. No API or service is defined for Corpus Administrator functions: managing corpora, document ACLs, and tenant routing policy. Authorization Service owns grants and LLM Router Service owns routing policy, but no write path to them is drawn.
2. Audit Service has a read-only query API, but the Gateway has no route to it. How the Compliance Officer reaches it is undefined.
3. `DocumentDeleted` carries `confirmedPurges[]`, but the event catalog has no purge-confirmation event.
4. Topic names, partition counts, replication, and retention values are not specified (examples only in ADR-0011).
5. How downstream services trust the claims in gRPC metadata is not specified.
6. Whether Keycloak is part of this deployment or an existing enterprise instance is not settled (ADR-0013 lists it in the Compose stack; the earlier context design called it an existing external system).
7. When `Document*Failed` events are published relative to the retry topics, and the replay procedure, are not specified.
8. Migration tool, pgvector index type, and architecture-rule enforcement are not chosen.
9. Who consumes `ChunkEmbedded`, if anyone, and whether Audit Service's enumerated list includes it, is not specified.

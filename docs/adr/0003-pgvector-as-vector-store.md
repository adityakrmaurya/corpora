# ADR-0003: PGVector as the Vector Store

## Status

Accepted

## Context and Problem Statement

The system needs a vector store for chunk embeddings, supporting similarity search, per-chunk metadata (for ACL filtering — see the Retrieval Service component doc), and self-hosted/on-prem deployment (data sovereignty is a hard constraint).

## Decision Drivers

- Self-hosted/on-prem only — no managed cloud-only vector DBs.
- Native, indexable metadata filtering (needed for mandatory ACL enforcement on every query).
- Enterprise operational familiarity — minimizing net-new infrastructure classes that must clear security/ops review.
- Spring AI's `VectorStore` abstraction support maturity.

## Considered Options

1. PGVector (Postgres + `pgvector` extension).
2. Qdrant.
3. Milvus.
4. Weaviate.

## Decision Outcome

Chosen option: **1 — PGVector**. Postgres is near-universally already approved, operated, and backed up in enterprise environments; standing up any of the alternatives means onboarding an entirely new class of infrastructure through security/ops review for a system that is already introducing 14 new services. Metadata (tenant, ACL groups, owner, classification, heading path, page span) lives as ordinary Postgres JSONB/columns — filterable, indexable (GIN/B-tree), and fully auditable via SQL. Spring AI's `PgVectorStore` is one of its most mature vector store integrations.

## Consequences

**Good:**
- No new infrastructure class to operationalize.
- ACL metadata filtering is plain SQL, auditable, and can be reinforced with Postgres Row-Level Security as defense-in-depth.
- The `VectorStore` interface is portable — migrating to Qdrant/Milvus later, if scale ever demands it, is a config-and-reindex operation, not a rewrite.

**Bad:**
- `pgvector`'s HNSW/IVFFlat ANN indexes don't horizontally scale to billions of vectors as gracefully as a purpose-built vector database. Acceptable trade-off at the realistic scale here (enterprise document corpora, likely millions of chunks, not billions).
- No turnkey native hybrid (dense+sparse) search API — hybrid search would be a composed SQL query (`pgvector` KNN + Postgres full-text search), not out-of-the-box.

## Alternatives Considered (detail)

### Qdrant / Milvus / Weaviate
All have more purpose-built hybrid search and horizontal scale characteristics. Rejected as the *default* for the reasons above, but Qdrant is the documented second choice if/when scale or native hybrid search becomes a real, measured requirement — enabled by the fact that `VectorStore` is a Spring AI abstraction, not a hard dependency on Postgres-specific code.

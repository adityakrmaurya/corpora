# ADR-0012: Database-per-Service — One Physical Postgres Instance per Data-Owning Service

## Status

Accepted (revises an earlier draft of this same ADR that chose schema-per-service in a shared cluster — see Alternatives Considered)

## Context and Problem Statement

Nine services own data requiring durable storage: Ingestion, Parsing, Chunking, Embedding, Document Catalog, Request Validator, Authorization, Audit, and LLM Router. (Retrieval Service owns no schema of its own — it is a strictly read-only consumer of Embedding Service's data; see ADR-0003 and `docs/architecture/c4-component-retrieval-service.md`.) An earlier draft of this ADR proposed schema-per-service within one shared Postgres cluster, reasoning that a self-hosted deployment at initial scale didn't justify the infrastructure footprint of N physical clusters. That trade-off was revisited: microservices orthodoxy (Sam Newman's *Building Microservices* et al.) specifically calls for a *physically separate* data store per service, precisely because schema-level isolation still leaves every service sharing one failure domain, one resource pool, and one scaling/tuning profile — undermining the fault-isolation and independent-scalability properties this system's whole DDD/event-driven design (ADR-0001) is built around.

## Decision Drivers

- True fault isolation: no single Postgres outage, corruption, or major-version upgrade should be able to take down more than one service.
- Independent scaling and tuning: Embedding Service's vector-adjacent bookkeeping will grow far faster than Authorization's policy table; they shouldn't be forced onto the same storage/backup/HA profile.
- No noisy-neighbor risk: one service's runaway query must never degrade another service's latency.
- Consistency with this project's repeated stance (ADR-0001, ADR-0009) against consolidating distinct bounded contexts for operational convenience — a shared cluster is exactly that kind of consolidation, applied to data instead of services.

## Considered Options

1. Schema-per-service in one shared Postgres cluster (the original draft of this ADR).
2. Database-per-service: one dedicated physical Postgres instance per data-owning service.
3. A middle ground isolating only the highest-blast-radius stores (Embedding/PGVector and Audit) while the remaining six share one instance.

## Decision Outcome

Chosen option: **2 — database-per-service**. Each of the nine data-owning services gets its own dedicated Postgres instance: `authorization-db`, `request-validator-db`, `ingestion-db`, `parsing-db`, `chunking-db`, `embedding-db`, `document-catalog-db`, `audit-db`, `llm-router-db`. Least-privilege DB roles are scoped per instance (simpler than per-schema now, since each instance holds exactly one service's data). PGVector (ADR-0003) remains the one deliberate shared-store exception: it lives on `embedding-db` (Embedding Service already owns that instance and is PGVector's sole writer), and Retrieval Service connects to `embedding-db` as a strictly read-only client — the same single-writer/read-only-reader pattern as the original draft, just hosted on a dedicated instance rather than a shared cluster. No service ever connects to another service's database outside this one documented exception.

## Consequences

**Good:**

- A Postgres outage, corruption, or major-version upgrade on one service's instance cannot cascade to any other service.
- Each service can be scaled, tuned, backed up, and put on its own HA topology independently — e.g. `embedding-db` can get more aggressive vertical scaling and more frequent backups than `authorization-db` without over-provisioning everything else.
- Consistent with this project's repeated stance against consolidating distinct bounded contexts for pragmatic convenience — extended here from service boundaries to data boundaries.

**Bad:**

- Materially larger infrastructure footprint: nine Postgres instances instead of one, each needing its own connection pool, backup job, and monitoring target — a real operational cost multiplier, notable given this system's self-hosted, resource-constrained deployment target (see ADR-0013).
- Provisioning is more involved (nine sets of credentials/connection strings instead of one), though this is a one-time Docker Compose/deployment-manifest cost, not an ongoing one.

## Alternatives Considered (detail)

### Schema-per-service in one shared cluster (original decision, reversed)

This was the initial decision, justified on infrastructure-footprint/YAGNI grounds: one Postgres cluster, one schema per service, least-privilege roles scoped per schema, with cross-schema access forbidden. Reversed after weighing it against this project's own stated production-grade, no-shortcuts direction: a shared cluster is a single failure domain and a shared resource pool regardless of how cleanly the schemas are separated logically — precisely the coupling database-per-service exists to eliminate. Kept here as an honest record of what was tried first and why it didn't hold up under scrutiny, rather than silently deleted.

### Middle ground (isolate only Embedding/PGVector and Audit)

A defensible partial step — those two are the highest-consequence stores (PGVector backs the entire read path; Audit's compliance data must never contend with operational writes) — but not chosen because it still leaves six lower-volume services sharing a failure domain, reintroducing the exact problem this ADR exists to solve for those six, just at a smaller blast radius.

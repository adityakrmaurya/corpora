# ADR-0011: Audit Service as a Pure Event-Sourced Consumer

## Status

Accepted

## Context and Problem Statement

The system requires a compliance-grade audit trail: who queried what, which documents/chunks were retrieved and used as LLM context, what was ingested/deleted and by whom, and every authorization decision. This must be reliable (no missed events) and must not become a dependency any other service's normal operation waits on.

## Decision Drivers

- Audit completeness is itself a compliance requirement — a missed event is a compliance gap, not just a bug.
- No other service should depend on Audit Service's uptime to do its own work (it must be a pure sink, never called synchronously).
- Retention requirements for compliance data often exceed typical operational log retention.

## Considered Options

1. Audit as a synchronously-called logging API other services invoke.
2. Audit as a pure Kafka consumer across every domain event topic (write-side and read-side), with its own durable, queryable projection.

## Decision Outcome

Chosen option: **2**. Audit Service explicitly enumerates every event topic it consumes (`document.uploaded.v1`, `document.parsed.v1`, `access.granted.v1`, etc. — a deliberate governance choice: new event types are added to audit scope on review, not silently auto-included, so nothing leaks into audit inappropriately and no new event type is silently missed). Manual offset commit only after successful persistence (at-least-once + `eventId` dedup = effectively-once). Long/compaction-never-delete retention on audit-relevant topics so the service can be rebuilt from offset zero after extended downtime. Per-topic DLQ with alerting on depth — audit completeness is a feature of the DLQ, not a shortcut around it. Its own store (`audit_service` schema, append-only, `REVOKE UPDATE, DELETE` grants enforced at the DB level for tamper-evidence) serves a read-only REST query API for compliance/admin tooling. Its one synchronous edge is that read-only query API — it is never called synchronously to gate anyone else's work.

## Consequences

**Good:**
- Zero coupling: every other service's normal operation is entirely independent of whether Audit Service is up.
- Full replay/backfill capability if Audit Service is down or needs rebuilding.
- DB-level tamper-evidence (revoked UPDATE/DELETE grants) on the audit log itself.

**Bad:**
- Retention costs (Kafka log + DB projection) for compliance-grade retention windows, which can be materially longer than typical operational log retention.

## Alternatives Considered (detail)

### Synchronous audit-logging API
Rejected — would make every other service's request path depend on Audit Service's availability/latency, directly contradicting the "never gate the response" principle established in ADR-0002 for read-side domain events.

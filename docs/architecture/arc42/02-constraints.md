---
section: 2
title: Architecture constraints
owner: Unknown (to be assigned)
last-verified: 2026-11-03
verified-against: ADR-0003, ADR-0004, ADR-0006, ADR-0012, ADR-0013, ADR-0014, README.md, build.gradle.kts
---

# 2. Architecture constraints

"Negotiable" is the author's reading of the ADR. The ADR owner confirms it.

## 2.1 Technical constraints

| Constraint | Consequence | Negotiable | Source |
|---|---|---|---|
| All code the team writes is Java 25 on Spring Boot; no hand-written Python | Docling is consumed as a vendored container through its official Java client; the reranker runs in-JVM (DJL) | No (explicit team preference) | ADR-0014, ADR-0006, ADR-0009 |
| Spring Boot 4, Spring AI 2, Gradle multi-module build | One build toolchain; one instrumentation convention (Micrometer, OpenTelemetry) | Version numbers recorded in README only | README.md, ADR-0014 |
| Self-hosted, on-prem capable; air-gapped-safe default | No managed cloud-only components; default model provider is Ollama; PGVector instead of a cloud vector database | Cloud providers are opt-in per profile | ADR-0003, ADR-0004 |
| Docker Compose deployment, single node or small fixed cluster | No native autoscaling, canary, or multi-node scheduling | Yes, when a concrete scale requirement appears | ADR-0013 |
| One dedicated Postgres instance per data-owning service | Nine instances; no cross-service database access except the documented read-only exception | No (decided as revision of an earlier draft) | ADR-0012 |
| Kafka for the write side, gRPC for the read side | Two communication paradigms to maintain | No | ADR-0002, ADR-0007 |
| Checkstyle with Google style, zero warnings, on every service module | Build fails on style violations | Yes | build.gradle.kts |

## 2.2 Organisational constraints

| Constraint | Consequence | Negotiable |
|---|---|---|
| Team size, ownership, and deadlines | Unknown. ADR-0001 states that bounded contexts map to team boundaries "if this grows past one team", which suggests a single team today | Unknown |
| Compliance and retention requirements | Unknown. ADR-0011 notes that audit retention can exceed operational log retention; no retention period is given | Unknown |

## 2.3 Conventions

| Convention | Source |
|---|---|
| Every event carries `eventId`, `occurredAt`, `producedBy`, `correlationId`, `causationId`, `schemaVersion`; additive changes stay on `*.v1`, breaking changes ship as `*.v2` with a dual-publish window | [Event reference](../../reference/events.md) |
| No service connects to another service's database, except Retrieval Service reading `embedding-db` through a read-only role | ADR-0012 |
| A service is introduced only with an aggregate root and a statement of what it does not own | ADR-0001 |
| Terms keep the meaning of their bounded context | [§12](12-glossary.md) |

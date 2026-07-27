# ADR-0014: Single-Language (Java) Service Implementation Stack

## Status

Accepted

## Context and Problem Statement

With Docling's core ML capability being Python-only, an early instinct was to introduce a hand-written Python service for parsing/chunking. The team's explicit preference is that all *code we write* stay in one language (Java 25) to minimize cross-language operational and hiring/maintenance overhead, while still being able to use best-of-breed capability where it genuinely only exists elsewhere.

## Decision Drivers

- Minimize the number of languages/runtimes the team must operate and debug in production.
- Distinguish "code we write and own" from "vendored infrastructure we call via a client library" — the latter is not a violation of a single-language codebase (the same way depending on Postgres, written in C, isn't considered "polyglot" for a Java shop).
- Distributed tracing/observability (a consequence of ADR-0001) is materially simpler when every owned service shares one runtime's instrumentation conventions (Micrometer/OpenTelemetry via Spring Boot).

## Considered Options

1. Polyglot: hand-written Python services wherever a Python-first library (Docling) or ML-serving stack is the best tool.
2. Single-language: every service we write is Java/Spring Boot; capabilities that only exist as external ML tooling are consumed via official client libraries/vendored containers, never reimplemented as owned Python code.

## Decision Outcome

Chosen option: **2**. Concretely: Parsing/Chunking Service call a vendored `docling-serve` container via the official Java client (ADR-0006) rather than us writing Python. Reranker Service defaults to an in-JVM DJL cross-encoder rather than a hand-written Python inference service, with a dedicated inference runtime (still called via a client, not owned code) as a documented scale-out option only if GPU throughput later demands it. Every one of the 14 services is Java 25/Spring Boot: WebFlux where reactive I/O matters (Ingestion Service's streamed uploads), `grpc-java` for the read-side chain (ADR-0002), `spring-kafka` for the write side (ADR-0007).

## Consequences

**Good:**
- One runtime, one build toolchain (Gradle), one observability instrumentation convention across all 14 owned services.
- No Python dependency-management, packaging, or on-call expertise required for code the team itself maintains.

**Bad:**
- Where a Python-native library's *client* still requires the vendored service to be operated (Docling Serve container), the team accrues operational responsibility for that container even though it owns no code inside it. This is judged an acceptable, well-understood category of dependency (equivalent to operating Postgres/Keycloak/Ollama).

## Alternatives Considered (detail)

### Polyglot (hand-written Python where convenient)
Rejected per explicit team preference and reinforced by ADR-0006's discovery that an official Java client path exists for Docling specifically — removing the strongest argument for a hand-written Python service in this system.

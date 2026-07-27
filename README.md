# Corpora — Enterprise Document RAG System

A self-hosted, enterprise-grade Retrieval-Augmented Generation (RAG) platform for document Q&A, built as a set of event-driven microservices following Domain-Driven Design.

## Documentation

- [`docs/architecture/c4-context.md`](docs/architecture/c4-context.md) — System Context (who uses this, what it talks to)
- [`docs/architecture/c4-container.md`](docs/architecture/c4-container.md) — Container diagram (all 14 services + infrastructure)
- [`docs/architecture/c4-component-*.md`](docs/architecture) — Component diagrams for the write-side, read-side, and retrieval/ACL internals
- [`docs/architecture/event-catalog.md`](docs/architecture/event-catalog.md) — Full Kafka domain event catalog
- [`docs/architecture/ubiquitous-language.md`](docs/architecture/ubiquitous-language.md) — DDD glossary, one entry per bounded context
- [`docs/adr/`](docs/adr) — Architecture Decision Records for every major design choice

## Status

Architecture and documentation phase. No service implementation has started yet — see `docs/adr/` for what's been decided and why, and `docs/architecture/implementation-order.md` for the phased build order.

## Stack at a glance

Java 25 · Spring Boot 4 · Spring AI 2 · gRPC (read path) · Apache Kafka (write path) · PGVector (Postgres) · Keycloak (OIDC) · Docling Serve (document parsing/chunking) · Ollama (self-hosted LLM/embeddings, provider-agnostic) · Docker Compose (self-hosted deployment)

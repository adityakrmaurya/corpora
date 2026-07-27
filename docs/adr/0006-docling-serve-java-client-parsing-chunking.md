# ADR-0006: Parsing and Chunking via Docling Serve, Called from Java

## Status

Accepted

## Context and Problem Statement

The system needs real structural extraction from documents (heading hierarchy, tables, page provenance) — not flat text — feeding a structure-aware chunker. Docling (IBM/DS4SD) has genuine ML-based layout/table understanding and a purpose-built `HybridChunker`, but its core library is Python-only. The team's stated preference is a single-language (Java) codebase; an earlier pass planned a pure-Java fallback (Tika structural output + PDFBox heuristics + tabula-java) accepting materially lower fidelity on PDFs. That plan was superseded after discovering `docling-project/docling-java` — an official Java client project — via direct GitHub search (`gh search repos`), which Context7/web research had missed.

## Decision Drivers

- Full ML-grade structural fidelity (headings, tables, page provenance) was the entire reason Docling was proposed.
- No hand-written Python in the codebase.
- Prefer an officially maintained client over hand-rolling HTTP integration against a third-party service.

## Considered Options

1. Pure Java: Tika (native structure for DOCX/PPTX/HTML) + PDFBox heuristics + `tabula-java` for PDF tables. No Python anywhere, but measurably lower fidelity on complex/scanned PDFs (no ML layout model).
2. Hand-written Python Parsing/Chunking services using `docling`/`docling-core` directly.
3. Java Parsing/Chunking services calling a self-hosted **Docling Serve** container via the official `docling-serve-api`/`docling-serve-client` Java libraries (Maven Central, `ai.docling:*`), including its `/chunk` endpoint (`HybridChunkDocumentRequest`) which returns real `HybridChunker` output with typed Java response objects (`Chunk`, `ChunkDocumentResponse`).

## Decision Outcome

Chosen option: **3**. Parsing Service and Chunking Service are ordinary Spring Boot services with zero Python code; the only Python in the entire system is the official, unmodified `docling-serve` container image — architecturally the same category of dependency as Postgres, Keycloak, or Ollama (a vendored infra dependency called via a client library), not code the team owns or maintains in a second language. This restores full ML fidelity (confirmed: real layout analysis, table structure, heading hierarchy, `HybridChunker`'s heading-path-aware chunking) while keeping 100% of our own code in Java. `docling-testcontainers` (also official) is used for integration testing against a real Docling Serve instance.

## Consequences

**Good:**
- No fidelity trade-off versus option 1 — full Docling ML capability.
- No hand-written Python versus option 2 — Docling Serve is vendored infrastructure, not owned code.
- Typed Java request/response objects (`docling-core`'s Java types, `docling-serve-api`) eliminate hand-parsing of generic JSON.

**Bad:**
- Docling Serve's `/chunk` endpoint parses-and-chunks from the raw source in one call; it does not accept a pre-parsed `DoclingDocument` as input. Parsing Service and Chunking Service therefore each call Docling Serve independently against the same source, accepting a minor redundant-reparse cost in exchange for keeping them as clean, independently-configurable bounded contexts (see the Parsing/Chunking component doc). Acceptable because this is the async write side, not a latency-sensitive path.
- Introduces an operational dependency on a self-hosted Docling Serve container (resource sizing, availability) that a pure-Java option would not have.

## Alternatives Considered (detail)

### Pure Java (Tika + PDFBox heuristics + tabula-java)
Was the interim decision before `docling-java` was found. Superseded once a direct GitHub search (`gh search repos`) — rather than Context7/web search alone — surfaced `docling-project/docling-java`, an official Java client that Context7's index had missed. Lesson applied going forward: verify "no Java port exists"-style claims against GitHub directly before treating them as settled.

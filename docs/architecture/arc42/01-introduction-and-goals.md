---
section: 1
title: Introduction and goals
owner: Unknown (to be assigned)
last-verified: 2026-11-03
verified-against: README.md, ADR-0001 to ADR-0014; the previous design documents
---

# 1. Introduction and goals

## 1.1 Requirements overview

Corpora is a self-hosted enterprise platform for question answering over documents (retrieval-augmented generation). Users upload documents, the platform makes them searchable, and users ask questions and receive answers with citations back to the source material. Access control applies per document.

Essential functions, as recorded in the design:

| Function | Summary |
|---|---|
| Ingest | Streamed upload, submission policy check, fine-grained authorization, durable staging of the raw bytes |
| Index | Structure-aware parsing and chunking via Docling Serve, embedding, storage in PGVector |
| Track | One current-state record per document (`UPLOADED`, `PROCESSING`, `CHUNKED`, `EMBEDDING`, `INDEXED`, `FAILED`, `DELETED`) and coordinated deletion across stores |
| Answer | Query rewriting, ACL-filtered retrieval, reranking, provider-routed generation, citation-annotated streaming response |
| Audit | Append-only compliance record of ingestion, deletion, authorization decisions, and queries |
| Operate | Provider-agnostic chat and embedding models, self-hosted by default |

Source of requirements: Unknown. The repository contains no requirements document; the functions above come from the ADRs and the earlier design documents.

## 1.2 Quality goals

The stakeholders have not stated a ranked list of quality goals. The goals below are **assumed**, derived from the decision drivers recorded in the ADRs. The owner confirms or replaces them.

| # | Quality goal | Scenario | Priority |
|---|---|---|---|
| Q1 | Security: tenant and document isolation (assumed) | A user outside the access group of a document never receives a chunk or citation from it, even when asking about the same corpus as a permitted user (QS-1) | 1 |
| Q2 | Data sovereignty (assumed) | With the default profile, Corpora makes no calls to external providers; a cloud provider is used only after an explicit profile change (ADR-0003, ADR-0004) | 2 |
| Q3 | Auditability (assumed) | Every audited domain event is recorded, and the audit log can be rebuilt from the retained event log after downtime (ADR-0011, QS-5) | 3 |
| Q4 | Reliability of ingestion (assumed) | A failed processing stage is retried, surfaced as `FAILED`, and resumed without re-uploading the document (QS-4) | 4 |
| Q5 | Responsiveness of chat (assumed) | A chat answer completes within one propagated deadline budget; citations arrive before tokens (QS-3). The budget value is `TBD` | 5 |

Measurable scenarios are in [§10](10-quality-requirements.md).

## 1.3 Stakeholders

| Role | Contact | Expectation of the architecture and its documentation |
|---|---|---|
| Knowledge Worker | Unknown | Finds only documents they may see; receives cited answers |
| Corpus Administrator | Unknown | Can manage corpora, document ACLs, and routing policy. The interface is not yet designed (see [§11](11-risks-and-technical-debt.md), R-8) |
| Compliance / Audit Officer | Unknown | Can answer who accessed what, and why. The interface path is not yet designed (see [§11](11-risks-and-technical-debt.md), R-8) |
| Development and operations team | Unknown | Independent deployability per service, traceability across services, an operable Docker Compose deployment |

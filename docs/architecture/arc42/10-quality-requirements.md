---
section: 10
title: Quality requirements
owner: Unknown (to be assigned)
last-verified: 2026-11-03
verified-against: ADR-0002, ADR-0004, ADR-0007, ADR-0011; the previous implementation-order verification list
---

# 10. Quality requirements

## 10.1 Overview

| Goal in [§1.2](01-introduction-and-goals.md#12-quality-goals) | ISO/IEC 25010 category | Scenarios |
|---|---|---|
| Q1 Security: isolation | Security | QS-1 |
| Q2 Data sovereignty | Security, flexibility | QS-9, QS-6 |
| Q3 Auditability | Reliability, security | QS-5, QS-8 |
| Q4 Reliability of ingestion | Reliability | QS-2, QS-4, QS-8 |
| Q5 Responsiveness of chat | Performance efficiency | QS-3 |
| Supporting: diagnosability | Maintainability | QS-7 |

## 10.2 Quality scenarios

Scenarios QS-1 to QS-5 and QS-7 come from the end-to-end verification list of the earlier design. Their acceptance behaviour is recorded; numeric measures were not, and are marked `TBD`. The owner supplies them.

| ID | Type | Source and stimulus | Response | Measure |
|---|---|---|---|---|
| QS-1 | Security | User A (group X) and user B (not in X) query the same corpus; a document is restricted to group X | B receives no chunk and no citation from that document | Zero candidates and zero citations. Release-blocking test |
| QS-2 | Use | A mixed batch is uploaded: a PDF with a table and nested headings, a DOCX, a PPTX, an HTML page | Events `DocumentUploaded`, `DocumentParsed`, `DocumentChunked`, `ChunkEmbedded`, `DocumentEmbeddingCompleted` are observable; Document Catalog reaches `INDEXED`; table structure survives chunking | Every document `INDEXED`; structure and table-chunking test passes. Time to `INDEXED`: TBD |
| QS-3 | Performance | A chat request arrives while LLM Router Service is slow (simulated) | The gRPC chain respects its total deadline; the `citations` event arrives before tokens | Total deadline: TBD (owner, date). Reranked-retrieval latency budget: TBD |
| QS-4 | Failure | A write-side service is killed mid-job | The message dead-letters after retry exhaustion; Document Catalog shows `FAILED` with the `retryable` flag; reprocessing resumes without a re-upload | No re-upload needed; retry tiers 5 s, 30 s, 5 min, then DLQ; alert on DLQ depth |
| QS-5 | Failure and recovery | Audit Service is down for an extended time, then restarted or rebuilt | It consumes the retained log from the stored offset or from zero and records every audited event | Zero missed audited events. Maximum downtime covered by retention: TBD |
| QS-6 | Change | Operator sets `SPRING_PROFILES_ACTIVE` to a cloud profile, or changes the embedding provider | Chat provider changes with no rebuild. A mismatching embedding dimension makes startup fail | No rebuild; fail-fast on dimension mismatch. Corpus re-embedding is manual |
| QS-7 | Diagnosability | An operator follows one document's journey and one chat request | Both appear as end-to-end traces in Grafana and Tempo, including across Kafka hops | Complete trace per document and per chat request. Time to diagnose: TBD |
| QS-8 | Consistency | The same event is delivered twice (relay retry or redelivery) | The consumer ignores the second delivery by `eventId` | Zero duplicate side effects |
| QS-9 | Sovereignty | The system runs with the default profile | No call leaves for an external model provider | Zero outbound calls to cloud providers. How this is measured: Unknown |

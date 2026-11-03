---
title: Corpora architecture documentation (arc42)
owner: Unknown (to be assigned)
last-verified: 2026-11-03
verified-against: ADR-0001 to ADR-0014, the previous design documents (facts only), README.md, build.gradle.kts, settings.gradle.kts. No service code exists.
---

# Corpora architecture documentation

Architecture description of Corpora, a self-hosted enterprise document RAG platform, structured by [arc42](https://arc42.org) in its lean form. One document for the whole system. Diagrams are C4 views exported from one model, [`../workspace.dsl`](../workspace.dsl).

## Status of this documentation

Corpora is in the design phase. No service has been implemented, so every statement here describes **intended** architecture taken from the ADRs in [`docs/adr/`](../../adr) and from the earlier design documents (replaced by this rewrite; they remain in git history). Nothing has been verified against running code. Each section carries its own `last-verified` date and `verified-against` field. When a service lands, re-verify the sections that mention it and update "Where the code lives" in §5.

Anything that is not decided or not known is written as `Unknown`, `TBD`, or `assumed`. §11 lists the open points.

## Sections

| § | Page | Reader question it answers |
|---|---|---|
| 1 | [Introduction and goals](01-introduction-and-goals.md) | What is Corpora for, and which qualities matter most? |
| 2 | [Constraints](02-constraints.md) | What limits the design freedom? |
| 3 | [Context and scope](03-context-and-scope.md) | Who and what is outside Corpora, and how does it connect? |
| 4 | [Solution strategy](04-solution-strategy.md) | Which approach serves each quality goal? |
| 5 | [Building block view](05-building-block-view.md) | What are the pieces, and who talks to whom? |
| 6 | [Runtime view](06-runtime-view.md) | How do the important flows and failures behave? |
| 7 | [Deployment view](07-deployment-view.md) | Where does each container run? |
| 8 | [Crosscutting concepts](08-crosscutting-concepts.md) | Which rules apply across services? |
| 9 | [Architecture decisions](09-architecture-decisions.md) | Which decisions were made, and where are they recorded? |
| 10 | [Quality requirements](10-quality-requirements.md) | How is each quality goal made testable? |
| 11 | [Risks and technical debt](11-risks-and-technical-debt.md) | What is risky, unknown, or unfinished? |
| 12 | [Glossary](12-glossary.md) | What do the domain terms mean? |

## Related pages

| Page | Type | Purpose |
|---|---|---|
| [`../workspace.dsl`](../workspace.dsl) | Model | Source of truth for every diagram |
| [`../diagrams/`](../diagrams) | Generated | One Mermaid file per C4 view |
| [`../../reference/events.md`](../../reference/events.md) | Reference | Event catalog |
| [`../../explanation/build-order.md`](../../explanation/build-order.md) | Explanation | Why the services are built in this order |
| [`../../how-to/regenerate-architecture-diagrams.md`](../../how-to/regenerate-architecture-diagrams.md) | How-to | Validate the model and refresh the diagrams |

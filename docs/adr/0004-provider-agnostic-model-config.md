# ADR-0004: Provider-Agnostic Chat/Embedding Model Configuration via Spring AI

## Status

Accepted

## Context and Problem Statement

The system must support swapping the underlying LLM/embedding provider without code changes, defaulting to a fully self-hosted provider (data sovereignty), while allowing opt-in cloud providers for organizations that permit them.

## Decision Drivers

- Self-hosted/on-prem/air-gapped default requirement.
- No rebuild required to change providers — an operational config change only.
- Chat and embedding providers must be independently selectable (some providers, e.g. Anthropic, have no embeddings API).

## Considered Options

1. Hard-code a single provider integration.
2. Build a custom provider-abstraction layer from scratch.
3. Use Spring AI's `ChatModel`/`EmbeddingModel` interfaces with all provider starters bundled, selected via `spring.ai.model.chat`/`spring.ai.model.embedding` properties + Spring profiles.

## Decision Outcome

Chosen option: **3**. Ollama is the default active profile (fully self-hosted, no external network calls — matches the air-gapped-safe default). Azure OpenAI, AWS Bedrock, and Anthropic are opt-in via alternate Spring profiles that flip `spring.ai.model.chat`/`.embedding` plus provider-specific endpoint/credential properties. All four provider starters are bundled in the deployable artifact so switching is a pure `SPRING_PROFILES_ACTIVE` change, not a rebuild. A startup validator fails fast if the active `EmbeddingModel`'s output dimension doesn't match the configured PGVector column dimension, since switching embedding providers requires a full re-embed/reindex (a sharp, easy-to-miss operoperational edge, documented explicitly so it fails loud rather than silently corrupting retrieval quality).

## Consequences

**Good:**
- Zero-code-change provider swap; matches the stated requirement exactly.
- Chat and embedding providers can be mixed independently (e.g., a cloud chat model with self-hosted embeddings) since they're separately configured selectors.

**Bad:**
- Bundling all four starters increases the deployable artifact size versus a build-time-only inclusion strategy.
- The dimension-mismatch fail-fast check is necessary but does not eliminate the operational burden of re-embedding the whole corpus after a provider switch — that remains a manual, documented runbook step.

## Alternatives Considered (detail)

### Build-time provider selection (only the desired starter included per build)
Rejected as the default because it requires a rebuild to switch providers, failing the "config only" requirement — documented as a possible future optimization if artifact size becomes a real concern.

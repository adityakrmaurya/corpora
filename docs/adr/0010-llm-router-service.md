# ADR-0010: LLM Router Service as a Distinct Policy Layer over Spring AI's ChatModel

## Status

Accepted

## Context and Problem Statement

ADR-0004 already gives the system a provider-agnostic `ChatModel` abstraction via Spring AI, selected by static configuration/profile. The user's service list additionally names an "LLM Router Service." The question is what unique domain responsibility justifies a *service*, distinct from what's already static config.

## Decision Drivers

- Spring AI's `ChatModel` abstraction answers "how do I generically talk to *a* configured provider" — a technical adapter.
- The system needs a live, runtime-mutable business decision: *which* configured provider/model to invoke for *this specific request*, given tenant policy, cost, capability needs, and live provider health — none of which belongs in a static config file.

## Considered Options

1. No separate service — provider selection stays purely static (one active profile for the whole deployment).
2. A distinct **LLM Router Service** wrapping Spring AI's `ChatModel`, owning tenant-tier routing, capability-based routing, and health/circuit-breaker-based fallback as live, mutable policy and state.

## Decision Outcome

Chosen option: **2**, justified with concrete routing scenarios that a static profile cannot express: (a) tenant-tier routing — enterprise-tier tenants route to a higher-accuracy hosted model under an SLA, standard-tier tenants route to self-hosted Ollama for cost control, changeable per-tenant without a redeploy; (b) fallback on provider failure — a circuit breaker per provider, transparently rerouting to a secondary provider in a tenant's fallback chain, invisible to callers; (c) capability routing — a query needing a very large context window routes to a model with sufficient context length even if it isn't the tenant's default. Prompt/message assembly stays in Query Processor (which holds full orchestration context), keeping LLM Router's domain uncontaminated by prompt engineering — it only decides *which* model, never *what to say to it*.

## Consequences

**Good:**
- Tenant policy and provider health become live, queryable, independently-updatable state (`llm_router_service` schema) rather than buried in deployment config.
- Callers (Query Processor, Response Formatter) never need to know a fallback occurred — the contract is identical either way.

**Bad:**
- One more service and one more piece of state (circuit-breaker status, routing policy) to operate and keep consistent.

## Alternatives Considered (detail)

### No separate service, static config only
Rejected — cannot express live, per-tenant, per-request routing decisions or automatic failure-driven fallback without a redeploy, which defeats the purpose of naming this as its own service.

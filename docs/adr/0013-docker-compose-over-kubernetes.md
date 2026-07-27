# ADR-0013: Docker Compose over Kubernetes for Initial Deployment

## Status

Accepted

## Context and Problem Statement

The system now comprises 14 application services plus significant infrastructure — nine dedicated Postgres instances (one per data-owning service, ADR-0012), Kafka, Keycloak, Ollama, Docling Serve, MinIO, an observability stack. A natural instinct at this service and container count is to reach for Kubernetes. The question is whether that operational step-up is justified now.

## Decision Drivers

- Self-hosted/on-prem deployment target, not a multi-node cloud-native environment by default.
- Service count alone is not, by itself, sufficient justification for Kubernetes-grade orchestration complexity (etcd, ingress controllers, a platform team to operate it).
- No stated requirement yet for multi-node horizontal auto-scaling or canary deploys.

## Considered Options

1. Kubernetes (Helm charts, one deployment per service).
2. Docker Compose, single-node or small fixed cluster.

## Decision Outcome

Chosen option: **2 — Docker Compose**. Fourteen application services plus roughly twenty infrastructure containers (nine Postgres instances plus Kafka, Keycloak, Ollama, MinIO, Docling Serve, and the observability stack) is not, by itself, a trigger for Kubernetes-grade complexity — Compose handles this container count without difficulty, and introducing Kubernetes now would be premature relative to any stated scale requirement (the "shiny new toy where a boring solution suffices" trap). Network segmentation is handled via Compose networks: only the API Gateway (and Keycloak's user-facing endpoints, if exposed directly) reach the public network; every Postgres instance, Kafka, Ollama, MinIO, and Docling Serve are internal-only.

## Consequences

**Good:**
- Materially lower operational burden for a self-hosted deployment of this scale.
- A well-structured Compose setup (one service = one container, explicit internal/external network segmentation) migrates mechanically to Kubernetes later if real multi-node scaling or canary-deploy requirements emerge — this decision does not block that path.

**Bad:**
- No native horizontal auto-scaling, rolling canary deploys, or multi-node scheduling — accepted as out of scope until a concrete requirement for them exists.

## Alternatives Considered (detail)

### Kubernetes from day one
Rejected as premature given no stated multi-node scale requirement; revisit if/when the deployment genuinely needs auto-scaling or canary rollout across multiple physical nodes.

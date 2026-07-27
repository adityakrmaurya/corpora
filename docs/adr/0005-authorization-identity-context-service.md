# ADR-0005: Refocus "Authentication Service" to "Authorization & Identity-Context Service"

## Status

Accepted

## Context and Problem Statement

The initial service list named an "Authentication Service." Keycloak (the identity provider) already owns authentication end-to-end — issuing and validating OIDC/OAuth2 tokens, managing users/realms/credentials — and the API Gateway already performs edge JWT validation against Keycloak's JWKS. A service that only re-validates a JWT would own no unique domain: no aggregate, no unique event, no unique data — a network hop wrapping a library call.

## Decision Drivers

- DDD requires every bounded context to own a genuine domain concept — a service with nothing to own is a smell, not a context.
- Fine-grained, resource-scoped authorization (can this principal act on *this* corpus/document) is genuinely unclaimed territory: Keycloak's realm roles are coarse-grained and don't model per-corpus/per-document ACLs.
- The user's original service list should not be silently overridden — any DDD tension found must be surfaced as an explicit recommendation, not unilaterally decided.

## Considered Options

1. Keep a literal "Authentication Service" duplicating Gateway/Keycloak JWT validation.
2. Fold authentication entirely into the Gateway, no separate service.
3. Refocus the service to **Authorization & Identity-Context**: fine-grained resource-scoped authorization decisions plus internal identity-context propagation, with its own policy data and `AccessGranted`/`AccessDenied` domain events.

## Decision Outcome

Chosen option: **3**, confirmed with the user after the tension was surfaced explicitly (not decided unilaterally). Coarse-grained role checks stay in the JWT, validated at the Gateway. Fine-grained, resource-scoped checks (upload to this corpus, delete this document) go through this service via gRPC, called synchronously by Ingestion Service and Document Catalog. It owns its own dedicated `authorization-db` Postgres instance (ADR-0012) for corpus/document-level grants beyond generic Keycloak realm roles, and publishes `AccessGranted`/`AccessDenied` as genuine, audit-worthy domain events consumed by the Audit Service (ADR-0011).

## Consequences

**Good:**
- Every service in the catalog now has a genuine, non-overlapping bounded context.
- `AccessGranted`/`AccessDenied` become first-class, replayable compliance facts rather than being buried in Gateway access logs.

**Bad:**
- One more synchronous gRPC dependency in the critical path of uploads and deletions (mitigated: it's a fast, in-network call, not a chained multi-hop operation).

## Alternatives Considered (detail)

### Fold into the Gateway
Documented as the fallback if this renaming were ever rejected — a Gateway filter with no separate deployable is preferable to keeping an empty microservice that owns nothing. Not chosen here because the fine-grained-authorization domain is real and worth its own bounded context.

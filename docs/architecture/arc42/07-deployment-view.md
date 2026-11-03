---
section: 7
title: Deployment view
owner: Unknown (to be assigned)
last-verified: 2026-11-03
verified-against: ADR-0012, ADR-0013; the previous implementation-order design
---

# 7. Deployment view

## 7.1 Self-hosted (Docker Compose)

The only environment documented in the design. Other environments (development, staging, production as separate stacks) are `Unknown`.

<!-- generated from docs/architecture/workspace.dsl, view "deployment-self-hosted"; do not edit by hand -->
```mermaid
graph LR
  linkStyle default fill:#ffffff

  subgraph diagram ["Deployment diagram for Corpora: self-hosted (Docker Compose)"]
    style diagram fill:#ffffff,stroke:#ffffff

    subgraph 178 ["Docker host"]
      style 178 fill:#ffffff,stroke:#444444,color:#ffffff

      subgraph 179 ["Public network"]
        style 179 fill:#ffffff,stroke:#444444,color:#ffffff

        subgraph 180 ["API Gateway"]
          style 180 fill:#ffffff,stroke:#444444,color:#ffffff

          181["<div style='font-weight: bold'>API Gateway</div><div style='font-size: 70%; margin-top: 0px'>[Container: Java 25, Spring Cloud Gateway]</div><div style='font-size: 80%; margin-top:10px'>Single entry point: TLS<br />termination, edge JWT<br />validation, routing, CORS,<br />rate limiting, correlation-ID<br />injection, SSE-to-gRPC<br />translation for chat.</div>"]
          style 181 fill:#438dd5,stroke:#2e6295,color:#ffffff
        end

        subgraph 182 ["Keycloak"]
          style 182 fill:#ffffff,stroke:#444444,color:#ffffff

          183["<div style='font-weight: bold'>Keycloak</div><div style='font-size: 70%; margin-top: 0px'>[Software System]</div><div style='font-size: 80%; margin-top:10px'>OIDC identity provider.<br />Source of truth for users,<br />groups, and tenants.</div>"]
          style 183 fill:#6b6b6b,stroke:#4a4a4a,color:#ffffff
        end

      end

      subgraph 185 ["Application services"]
        style 185 fill:#ffffff,stroke:#444444,color:#ffffff

        subgraph 186 ["Authorization & Identity-Context Service"]
          style 186 fill:#ffffff,stroke:#444444,color:#ffffff

          187["<div style='font-weight: bold'>Authorization & Identity-Context Service</div><div style='font-size: 70%; margin-top: 0px'>[Container: Java 25, Spring Boot, gRPC]</div><div style='font-size: 80%; margin-top:10px'>Decides whether a principal<br />may act on a corpus or<br />document; owns corpus- and<br />document-level grants.</div>"]
          style 187 fill:#438dd5,stroke:#2e6295,color:#ffffff
        end

        subgraph 188 ["Request Validator Service"]
          style 188 fill:#ffffff,stroke:#444444,color:#ffffff

          189["<div style='font-weight: bold'>Request Validator Service</div><div style='font-size: 70%; margin-top: 0px'>[Container: Java 25, Spring Boot, gRPC]</div><div style='font-size: 80%; margin-top:10px'>Applies submission policy to<br />candidate uploads: quota,<br />MIME allow-list, malware scan<br />result, content-hash dedup.</div>"]
          style 189 fill:#438dd5,stroke:#2e6295,color:#ffffff
        end

        subgraph 190 ["Ingestion Service"]
          style 190 fill:#ffffff,stroke:#444444,color:#ffffff

          191["<div style='font-weight: bold'>Ingestion Service</div><div style='font-size: 70%; margin-top: 0px'>[Container: Java 25, Spring Boot, WebFlux]</div><div style='font-size: 80%; margin-top:10px'>Accepts streamed uploads,<br />stages raw bytes in MinIO,<br />mints the documentId, and<br />publishes DocumentUploaded.</div>"]
          style 191 fill:#438dd5,stroke:#2e6295,color:#ffffff
        end

        subgraph 195 ["Parsing Service"]
          style 195 fill:#ffffff,stroke:#444444,color:#ffffff

          196["<div style='font-weight: bold'>Parsing Service</div><div style='font-size: 70%; margin-top: 0px'>[Container: Java 25, Spring Boot]</div><div style='font-size: 80%; margin-top:10px'>Converts documents into<br />structured content (headings,<br />tables, page provenance) via<br />Docling Serve and persists<br />the result.</div>"]
          style 196 fill:#438dd5,stroke:#2e6295,color:#ffffff
        end

        subgraph 197 ["Chunking Service"]
          style 197 fill:#ffffff,stroke:#444444,color:#ffffff

          198["<div style='font-weight: bold'>Chunking Service</div><div style='font-size: 70%; margin-top: 0px'>[Container: Java 25, Spring Boot]</div><div style='font-size: 80%; margin-top:10px'>Splits documents into<br />retrieval-sized chunks<br />carrying a heading path and<br />source anchor, via Docling<br />Serve.</div>"]
          style 198 fill:#438dd5,stroke:#2e6295,color:#ffffff
        end

        subgraph 199 ["Embedding Service"]
          style 199 fill:#ffffff,stroke:#444444,color:#ffffff

          200["<div style='font-weight: bold'>Embedding Service</div><div style='font-size: 70%; margin-top: 0px'>[Container: Java 25, Spring Boot, Spring AI]</div><div style='font-size: 80%; margin-top:10px'>Embeds chunks with the active<br />embedding provider. Sole<br />writer of the PGVector index.</div>"]
          style 200 fill:#438dd5,stroke:#2e6295,color:#ffffff
        end

        subgraph 201 ["Document Catalog & Lifecycle Service"]
          style 201 fill:#ffffff,stroke:#444444,color:#ffffff

          202["<div style='font-weight: bold'>Document Catalog & Lifecycle Service</div><div style='font-size: 70%; margin-top: 0px'>[Container: Java 25, Spring Boot]</div><div style='font-size: 80%; margin-top:10px'>Projects each document's<br />current lifecycle stage and<br />coordinates document<br />deletion.</div>"]
          style 202 fill:#438dd5,stroke:#2e6295,color:#ffffff
        end

        subgraph 205 ["Audit Service"]
          style 205 fill:#ffffff,stroke:#444444,color:#ffffff

          206["<div style='font-weight: bold'>Audit Service</div><div style='font-size: 70%; margin-top: 0px'>[Container: Java 25, Spring Boot]</div><div style='font-size: 80%; margin-top:10px'>Builds an append-only<br />compliance log from every<br />enumerated domain event<br />topic. Offers a read-only<br />query API.</div>"]
          style 206 fill:#438dd5,stroke:#2e6295,color:#ffffff
        end

        subgraph 207 ["Query Processor Service"]
          style 207 fill:#ffffff,stroke:#444444,color:#ffffff

          208["<div style='font-weight: bold'>Query Processor Service</div><div style='font-size: 70%; margin-top: 0px'>[Container: Java 25, Spring Boot, gRPC]</div><div style='font-size: 80%; margin-top:10px'>Orchestrates one question end<br />to end and owns the total<br />deadline budget.</div>"]
          style 208 fill:#438dd5,stroke:#2e6295,color:#ffffff
        end

        subgraph 210 ["Retrieval Service"]
          style 210 fill:#ffffff,stroke:#444444,color:#ffffff

          211["<div style='font-weight: bold'>Retrieval Service</div><div style='font-size: 70%; margin-top: 0px'>[Container: Java 25, Spring Boot, Spring AI, gRPC]</div><div style='font-size: 80%; margin-top:10px'>Embeds the query and runs an<br />ACL-filtered similarity<br />search over PGVector.</div>"]
          style 211 fill:#438dd5,stroke:#2e6295,color:#ffffff
        end

        subgraph 213 ["Reranker Service"]
          style 213 fill:#ffffff,stroke:#444444,color:#ffffff

          214["<div style='font-weight: bold'>Reranker Service</div><div style='font-size: 70%; margin-top: 0px'>[Container: Java 25, DJL, gRPC]</div><div style='font-size: 80%; margin-top:10px'>Re-scores candidate chunks<br />with a cross-encoder and<br />removes near-duplicates with<br />MMR.</div>"]
          style 214 fill:#438dd5,stroke:#2e6295,color:#ffffff
        end

        subgraph 216 ["Response Formatter Service"]
          style 216 fill:#ffffff,stroke:#444444,color:#ffffff

          217["<div style='font-weight: bold'>Response Formatter Service</div><div style='font-size: 70%; margin-top: 0px'>[Container: Java 25, Spring Boot, gRPC]</div><div style='font-size: 80%; margin-top:10px'>Assembles citations and<br />shapes the answer into a<br />typed stream of citations,<br />token, done, and error<br />events.</div>"]
          style 217 fill:#438dd5,stroke:#2e6295,color:#ffffff
        end

        subgraph 219 ["LLM Router Service"]
          style 219 fill:#ffffff,stroke:#444444,color:#ffffff

          220["<div style='font-weight: bold'>LLM Router Service</div><div style='font-size: 70%; margin-top: 0px'>[Container: Java 25, Spring Boot, Spring AI, gRPC]</div><div style='font-size: 80%; margin-top:10px'>Chooses the chat provider and<br />model per request by tenant<br />tier, capability, and<br />provider health; falls back<br />on failure.</div>"]
          style 220 fill:#438dd5,stroke:#2e6295,color:#ffffff
        end

      end

      subgraph 222 ["Infrastructure"]
        style 222 fill:#ffffff,stroke:#444444,color:#ffffff

        subgraph 223 ["Kafka"]
          style 223 fill:#ffffff,stroke:#444444,color:#ffffff

          224["<div style='font-weight: bold'>Kafka</div><div style='font-size: 70%; margin-top: 0px'>[Container: Apache Kafka (KRaft)]</div><div style='font-size: 80%; margin-top:10px'>Event backbone. Retains<br />events for replay; documentId<br />is the partition key. Hosts<br />retry topics and per-topic<br />DLQs.</div>"]
          style 224 fill:#438dd5,stroke:#2e6295,color:#ffffff
        end

        subgraph 243 ["Schema Registry"]
          style 243 fill:#ffffff,stroke:#444444,color:#ffffff

          244["<div style='font-weight: bold'>Schema Registry</div><div style='font-size: 70%; margin-top: 0px'>[Container: Apicurio Registry]</div><div style='font-size: 80%; margin-top:10px'>Stores Avro and JSON Schema<br />definitions of the event<br />contracts.</div>"]
          style 244 fill:#438dd5,stroke:#2e6295,color:#ffffff
        end

        subgraph 258 ["MinIO"]
          style 258 fill:#ffffff,stroke:#444444,color:#ffffff

          259["<div style='font-weight: bold'>MinIO</div><div style='font-size: 70%; margin-top: 0px'>[Container: MinIO (S3 API)]</div><div style='font-size: 80%; margin-top:10px'>Object storage for raw<br />uploads, extracted content,<br />and chunk manifests.</div>"]
          style 259 fill:#438dd5,stroke:#2e6295,color:#ffffff
        end

        subgraph 263 ["Docling Serve"]
          style 263 fill:#ffffff,stroke:#444444,color:#ffffff

          264["<div style='font-weight: bold'>Docling Serve</div><div style='font-size: 70%; margin-top: 0px'>[Container: Docling Serve (Python, vendored image)]</div><div style='font-size: 80%; margin-top:10px'>Vendored<br />document-understanding<br />engine: converts and chunks<br />documents. Official image, no<br />owned code.</div>"]
          style 264 fill:#438dd5,stroke:#2e6295,color:#ffffff
        end

        subgraph 267 ["Ollama"]
          style 267 fill:#ffffff,stroke:#444444,color:#ffffff

          268["<div style='font-weight: bold'>Ollama</div><div style='font-size: 70%; margin-top: 0px'>[Container: Ollama]</div><div style='font-size: 80%; margin-top:10px'>Default self-hosted chat and<br />embedding model runtime.</div>"]
          style 268 fill:#438dd5,stroke:#2e6295,color:#ffffff
        end

        subgraph 272 ["Observability Stack"]
          style 272 fill:#ffffff,stroke:#444444,color:#ffffff

          273["<div style='font-weight: bold'>Observability Stack</div><div style='font-size: 70%; margin-top: 0px'>[Software System]</div><div style='font-size: 80%; margin-top:10px'>Prometheus, Grafana, Tempo,<br />and Loki: receives metrics,<br />traces, and logs.</div>"]
          style 273 fill:#6b6b6b,stroke:#4a4a4a,color:#ffffff
        end

      end

      subgraph 288 ["Postgres instances"]
        style 288 fill:#ffffff,stroke:#444444,color:#ffffff

        subgraph 289 ["authorization-db"]
          style 289 fill:#ffffff,stroke:#444444,color:#ffffff

          290[("<div style='font-weight: bold'>authorization-db</div><div style='font-size: 70%; margin-top: 0px'>[Container: PostgreSQL]</div><div style='font-size: 80%; margin-top:10px'>Private store of<br />Authorization &<br />Identity-Context Service:<br />corpus- and document-level<br />grants and its outbox.</div>")]
          style 290 fill:#438dd5,stroke:#2e6295,color:#ffffff
        end

        subgraph 292 ["request-validator-db"]
          style 292 fill:#ffffff,stroke:#444444,color:#ffffff

          293[("<div style='font-weight: bold'>request-validator-db</div><div style='font-size: 70%; margin-top: 0px'>[Container: PostgreSQL]</div><div style='font-size: 80%; margin-top:10px'>Private store of Request<br />Validator Service and its<br />outbox.</div>")]
          style 293 fill:#438dd5,stroke:#2e6295,color:#ffffff
        end

        subgraph 295 ["ingestion-db"]
          style 295 fill:#ffffff,stroke:#444444,color:#ffffff

          296[("<div style='font-weight: bold'>ingestion-db</div><div style='font-size: 70%; margin-top: 0px'>[Container: PostgreSQL]</div><div style='font-size: 80%; margin-top:10px'>Private store of Ingestion<br />Service: Upload aggregate and<br />its outbox.</div>")]
          style 296 fill:#438dd5,stroke:#2e6295,color:#ffffff
        end

        subgraph 298 ["parsing-db"]
          style 298 fill:#ffffff,stroke:#444444,color:#ffffff

          299[("<div style='font-weight: bold'>parsing-db</div><div style='font-size: 70%; margin-top: 0px'>[Container: PostgreSQL]</div><div style='font-size: 80%; margin-top:10px'>Private store of Parsing<br />Service: parse-job<br />bookkeeping and its outbox.</div>")]
          style 299 fill:#438dd5,stroke:#2e6295,color:#ffffff
        end

        subgraph 301 ["chunking-db"]
          style 301 fill:#ffffff,stroke:#444444,color:#ffffff

          302[("<div style='font-weight: bold'>chunking-db</div><div style='font-size: 70%; margin-top: 0px'>[Container: PostgreSQL]</div><div style='font-size: 80%; margin-top:10px'>Private store of Chunking<br />Service and its outbox.</div>")]
          style 302 fill:#438dd5,stroke:#2e6295,color:#ffffff
        end

        subgraph 304 ["embedding-db"]
          style 304 fill:#ffffff,stroke:#444444,color:#ffffff

          305[("<div style='font-weight: bold'>embedding-db</div><div style='font-size: 70%; margin-top: 0px'>[Container: PostgreSQL, pgvector]</div><div style='font-size: 80%; margin-top:10px'>Embedding Service bookkeeping<br />and its outbox, plus the<br />shared PGVector index.<br />Written by Embedding Service<br />only; read by Retrieval<br />Service.</div>")]
          style 305 fill:#438dd5,stroke:#2e6295,color:#ffffff
        end

        subgraph 308 ["document-catalog-db"]
          style 308 fill:#ffffff,stroke:#444444,color:#ffffff

          309[("<div style='font-weight: bold'>document-catalog-db</div><div style='font-size: 70%; margin-top: 0px'>[Container: PostgreSQL]</div><div style='font-size: 80%; margin-top:10px'>Private store of Document<br />Catalog & Lifecycle Service:<br />one current-state row per<br />document, and its outbox.</div>")]
          style 309 fill:#438dd5,stroke:#2e6295,color:#ffffff
        end

        subgraph 311 ["audit-db"]
          style 311 fill:#ffffff,stroke:#444444,color:#ffffff

          312[("<div style='font-weight: bold'>audit-db</div><div style='font-size: 70%; margin-top: 0px'>[Container: PostgreSQL]</div><div style='font-size: 80%; margin-top:10px'>Append-only audit log. UPDATE<br />and DELETE grants are<br />revoked.</div>")]
          style 312 fill:#438dd5,stroke:#2e6295,color:#ffffff
        end

        subgraph 314 ["llm-router-db"]
          style 314 fill:#ffffff,stroke:#444444,color:#ffffff

          315[("<div style='font-weight: bold'>llm-router-db</div><div style='font-size: 70%; margin-top: 0px'>[Container: PostgreSQL]</div><div style='font-size: 80%; margin-top:10px'>Private store of LLM Router<br />Service: tenant routing<br />policy and circuit-breaker<br />state.</div>")]
          style 315 fill:#438dd5,stroke:#2e6295,color:#ffffff
        end

      end

    end

    181-- "<div>Fetches signing keys to<br />validate access tokens from</div><div style='font-size: 70%'>[HTTPS (JWKS)]</div>" -->183
    181-- "<div>Forwards document uploads to</div><div style='font-size: 70%'>[HTTP (multipart)]</div>" -->191
    191-- "<div>Checks upload permission with</div><div style='font-size: 70%'>[gRPC]</div>" -->187
    191-- "<div>Validates candidate uploads<br />with</div><div style='font-size: 70%'>[gRPC]</div>" -->189
    181-- "<div>Forwards status, list, and<br />delete requests to</div><div style='font-size: 70%'>[HTTP/REST]</div>" -->202
    202-- "<div>Checks permission on<br />documents with</div><div style='font-size: 70%'>[gRPC]</div>" -->187
    181-- "<div>Forwards chat requests to,<br />translating SSE to gRPC<br />streaming</div><div style='font-size: 70%'>[gRPC]</div>" -->208
    208-- "<div>Requests candidate chunks<br />(FindCandidates) from</div><div style='font-size: 70%'>[gRPC]</div>" -->211
    208-- "<div>Requests reranking (Rerank)<br />from</div><div style='font-size: 70%'>[gRPC]</div>" -->214
    208-- "<div>Calls FormatStream on</div><div style='font-size: 70%'>[gRPC (bidirectional streaming)]</div>" -->217
    217-- "<div>Requests streamed chat<br />completions from</div><div style='font-size: 70%'>[gRPC]</div>" -->220
    191-- "<div>Streams raw uploads to</div><div style='font-size: 70%'>[S3 API]</div>" -->259
    196-- "<div>Reads originals from and<br />stores extracted content in</div><div style='font-size: 70%'>[S3 API]</div>" -->259
    198-- "<div>Reads originals from and<br />stores chunk manifests in</div><div style='font-size: 70%'>[S3 API]</div>" -->259
    196-- "<div>Requests document conversion<br />from</div><div style='font-size: 70%'>[HTTP/REST]</div>" -->264
    198-- "<div>Requests hybrid chunking from</div><div style='font-size: 70%'>[HTTP/REST]</div>" -->264
    200-- "<div>Requests chunk embeddings<br />from</div><div style='font-size: 70%'>[HTTP/REST]</div>" -->268
    211-- "<div>Requests query embeddings<br />from</div><div style='font-size: 70%'>[HTTP/REST]</div>" -->268
    220-- "<div>Requests chat completions<br />from</div><div style='font-size: 70%'>[HTTP/REST]</div>" -->268
    187-- "<div>Reads and writes grants and<br />outbox rows in</div><div style='font-size: 70%'>[JDBC]</div>" -->290
    189-- "<div>Reads and writes submission<br />state and outbox rows in</div><div style='font-size: 70%'>[JDBC]</div>" -->293
    191-- "<div>Reads and writes uploads and<br />outbox rows in</div><div style='font-size: 70%'>[JDBC]</div>" -->296
    196-- "<div>Reads and writes parse jobs<br />and outbox rows in</div><div style='font-size: 70%'>[JDBC]</div>" -->299
    198-- "<div>Reads and writes chunk state<br />and outbox rows in</div><div style='font-size: 70%'>[JDBC]</div>" -->302
    200-- "<div>Writes chunk vectors and<br />bookkeeping to</div><div style='font-size: 70%'>[JDBC]</div>" -->305
    211-- "<div>Reads vectors by ACL-filtered<br />similarity search from<br />(read-only DB role)</div><div style='font-size: 70%'>[JDBC]</div>" -->305
    202-- "<div>Reads and writes the document<br />projection and outbox rows in</div><div style='font-size: 70%'>[JDBC]</div>" -->309
    206-- "<div>Appends audit entries to and<br />queries</div><div style='font-size: 70%'>[JDBC]</div>" -->312
    220-- "<div>Reads and writes routing<br />policy and circuit-breaker<br />state in</div><div style='font-size: 70%'>[JDBC]</div>" -->315

  end
```

View key `deployment-self-hosted`. Key: nested frames are deployment nodes; each box inside is a container instance with its type and technology in brackets; grey = external system. Only synchronous relationships are drawn. Event and schema-registry relationships are left off to keep the picture readable. The grouping nodes (`Application services`, `Infrastructure`, `Postgres instances`) are presentational; the real Compose file may organise services differently.

### Mapping

| Node | Contains | Network |
|---|---|---|
| API Gateway | API Gateway | Public, and internal to reach services |
| Keycloak | Keycloak (external system) | Public if its user-facing endpoints are exposed directly (ADR-0013) |
| Thirteen service nodes | Every application container except the Gateway | Internal only |
| Infrastructure nodes | Kafka, Schema Registry, MinIO, Docling Serve, Ollama, observability stack | Internal only |
| Nine Postgres nodes | `authorization-db`, `request-validator-db`, `ingestion-db`, `parsing-db`, `chunking-db`, `embedding-db`, `document-catalog-db`, `audit-db`, `llm-router-db` | Internal only |

### Motivation

Fourteen application services plus roughly twenty infrastructure containers are, by themselves, no trigger for Kubernetes-grade orchestration. Compose handles this count, and a well-structured Compose file (one service, one container; explicit internal and public networks) migrates mechanically to Kubernetes if multi-node scaling or canary rollout becomes a requirement (ADR-0013).

### Quality-relevant properties

| Property | Value |
|---|---|
| Instances per service | One; no replicas specified |
| Scaling mechanism | None. No horizontal autoscaling or canary deployment (ADR-0013) |
| Network segmentation | Compose networks. Only the Gateway, and Keycloak's user-facing endpoints if exposed, reach the public network |
| Observability | Services export OTLP to Prometheus, Grafana, Tempo, and Loki |

### Unknown

- Number of hosts, and whether Compose runs on one node or a small fixed cluster.
- Kafka broker count, partition counts, replication factor, retention values.
- Volumes, backup jobs, restore procedure, high availability for the nine Postgres instances.
- Secret storage and rotation; sources of Spring profile and provider credentials.
- Whether Keycloak is shipped in this stack or is an existing enterprise instance.
- Resource sizing for Ollama, Docling Serve, and the in-JVM reranker (GPU use is mentioned as a scale-out trigger only, ADR-0009).

No operating how-tos exist yet. Link them here when they do.

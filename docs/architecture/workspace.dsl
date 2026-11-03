/*
 * Corpora: Structurizr workspace. Single source of truth for every C4 diagram in this repo.
 *
 * Status: design phase. No service code exists yet, so every element and relationship below traces
 * to an ADR in docs/adr/ or to the design statements recorded in docs/architecture/arc42/ (the facts
 * of the earlier design documents were carried over; their format and conventions were not).
 *
 * Modelling rules used (also stated in arc42 section 3 and 5):
 *  - Container = a separately runnable application or data store that this system's Docker Compose
 *    deployment runs and that the system cannot work without. That includes vendored images
 *    (Kafka, MinIO, Docling Serve, Ollama, Apicurio Registry) and every Postgres instance.
 *  - External software system = a platform capability that holds no Corpora domain data and is not
 *    part of Corpora's processing: identity provider, observability stack, opt-in cloud LLM providers.
 *  - Kafka topics and events appear in relationship labels, not as elements.
 *  - Async relationships are tagged "Async" (dashed). Cross-service database access is "CrossServiceRead".
 *
 * Regenerate diagrams (from the repo root) with the Structurizr tooling:
 *   structurizr validate -workspace docs/architecture/workspace.dsl
 *   structurizr export   -workspace docs/architecture/workspace.dsl -format mermaid -output docs/architecture/diagrams
 */
workspace "Corpora" "Self-hosted enterprise document RAG platform: ingests documents, indexes them, and answers questions over them with per-document access control." {

    !identifiers hierarchical

    model {

        // ---- People ---------------------------------------------------------------------------
        knowledgeWorker   = person "Knowledge Worker" "Uploads documents and asks questions against the corpus."
        corpusAdmin       = person "Corpus Administrator" "Manages corpora, document ACLs, and tenant and routing policy."
        complianceOfficer = person "Compliance / Audit Officer" "Reviews the audit trail: who accessed what, and why."

        // ---- External systems -----------------------------------------------------------------
        keycloak      = softwareSystem "Keycloak" "OIDC identity provider. Source of truth for users, groups, and tenants." "External"
        cloudLlm      = softwareSystem "Cloud LLM Providers" "Opt-in Azure OpenAI, AWS Bedrock, or Anthropic, selected by Spring profile instead of the default Ollama." "External"
        observability = softwareSystem "Observability Stack" "Prometheus, Grafana, Tempo, and Loki: receives metrics, traces, and logs." "External"

        // ---- The system in scope --------------------------------------------------------------
        corpora = softwareSystem "Corpora" "Ingests, indexes, and answers questions over enterprise documents, enforcing access control per document." {

            gateway = container "API Gateway" "Single entry point: TLS termination, edge JWT validation, routing, CORS, rate limiting, correlation-ID injection, SSE-to-gRPC translation for chat." "Java 25, Spring Cloud Gateway"

            group "Write side (Kafka events)" {
                authz = container "Authorization & Identity-Context Service" "Decides whether a principal may act on a corpus or document; owns corpus- and document-level grants." "Java 25, Spring Boot, gRPC"
                validator = container "Request Validator Service" "Applies submission policy to candidate uploads: quota, MIME allow-list, malware scan result, content-hash dedup." "Java 25, Spring Boot, gRPC"
                ingestion = container "Ingestion Service" "Accepts streamed uploads, stages raw bytes in MinIO, mints the documentId, and publishes DocumentUploaded." "Java 25, Spring Boot, WebFlux" {
                    uploadController = component "UploadController" "Streams multipart bytes to MinIO without buffering, then validates, authorizes, and commits the upload." "Spring WebFlux controller"
                    validatorClient = component "RequestValidatorClient" "Calls Request Validator Service before the upload commits." "gRPC stub"
                    authorizationClient = component "AuthorizationClient" "Asks Authorization & Identity-Context Service whether the caller may upload to the corpus." "gRPC stub"
                    uploadService = component "UploadService" "Owns the Upload aggregate. Stores the aggregate and its event row in one transaction." "Domain service"
                    outbox = component "TransactionalOutbox" "Writes events to the outbox table inside the aggregate's transaction; a poller relays them." "Spring Data JPA, poller"
                    uploadedProducer = component "DocumentUploadedProducer" "Publishes relayed outbox rows to Kafka." "spring-kafka"
                }
                parsing = container "Parsing Service" "Converts documents into structured content (headings, tables, page provenance) via Docling Serve and persists the result." "Java 25, Spring Boot"
                chunking = container "Chunking Service" "Splits documents into retrieval-sized chunks carrying a heading path and source anchor, via Docling Serve." "Java 25, Spring Boot"
                embedding = container "Embedding Service" "Embeds chunks with the active embedding provider. Sole writer of the PGVector index." "Java 25, Spring Boot, Spring AI"
                catalog = container "Document Catalog & Lifecycle Service" "Projects each document's current lifecycle stage and coordinates document deletion." "Java 25, Spring Boot"
                audit = container "Audit Service" "Builds an append-only compliance log from every enumerated domain event topic. Offers a read-only query API." "Java 25, Spring Boot"
            }

            group "Read side (gRPC)" {
                queryProcessor = container "Query Processor Service" "Orchestrates one question end to end and owns the total deadline budget." "Java 25, Spring Boot, gRPC" {
                    chatEndpoint = component "ChatStreamEndpoint" "Entry point from the Gateway. Receives trusted tenant and ACL claims as gRPC metadata." "gRPC server-streaming"
                    queryRewriter = component "QueryRewriter" "Resolves pronouns and ellipsis; decomposes the question." "Domain service"
                    intentClassifier = component "IntentClassifier" "Classifies intent: factual, summarization, or comparison." "Domain service"
                    filterHintExtractor = component "FilterHintExtractor" "Derives an untrusted ExtractedFilterHint that can only narrow results." "Domain service"
                    orchestrator = component "AnswerOrchestrator" "Single owner of the total deadline budget, retry and circuit-breaking logic, and the root trace span." "Saga-style coordinator"
                    deadlineManager = component "DeadlineManager" "Propagates the remaining deadline on every downstream gRPC call." "gRPC deadlines"
                    retrievalClient = component "RetrievalClient" "Calls FindCandidates on Retrieval Service." "gRPC stub"
                    rerankerClient = component "RerankerClient" "Calls Rerank on Reranker Service." "gRPC stub"
                    formatterClient = component "ResponseFormatterClient" "Calls FormatStream on Response Formatter Service." "gRPC bidirectional stub"
                    auditPublisher = component "AsyncAuditPublisher" "Publishes QueryReceived, QueryRewritten, QueryAnswered without ever blocking the response." "spring-kafka, fire-and-forget"
                }
                retrieval = container "Retrieval Service" "Embeds the query and runs an ACL-filtered similarity search over PGVector." "Java 25, Spring Boot, Spring AI, gRPC" {
                    findCandidates = component "FindCandidatesEndpoint" "Entry point from Query Processor. Receives trusted tenant and ACL claims as gRPC metadata." "gRPC unary"
                    queryEmbedder = component "QueryEmbedder" "Embeds the query with the active embedding provider." "Spring AI EmbeddingModel"
                    aclFilterBuilder = component "AccessControlFilterExpressionBuilder" "Builds the mandatory ACL Filter.Expression from trusted JWT claims. Highest-risk logic in the system." "Java"
                    hintMerger = component "UserHintMerger" "AND-merges the untrusted, narrowing-only ExtractedFilterHint into the ACL filter. Cannot widen it." "Domain service"
                    similaritySearch = component "SimilaritySearchService" "Executes the filtered similarity search." "Spring AI PgVectorStore"
                    auditPublisher = component "AsyncAuditPublisher" "Publishes ChunksRetrieved without blocking the response." "spring-kafka, fire-and-forget"
                }
                reranker = container "Reranker Service" "Re-scores candidate chunks with a cross-encoder and removes near-duplicates with MMR." "Java 25, DJL, gRPC"
                formatter = container "Response Formatter Service" "Assembles citations and shapes the answer into a typed stream of citations, token, done, and error events." "Java 25, Spring Boot, gRPC"
                llmRouter = container "LLM Router Service" "Chooses the chat provider and model per request by tenant tier, capability, and provider health; falls back on failure." "Java 25, Spring Boot, Spring AI, gRPC"
            }

            kafka = container "Kafka" "Event backbone. Retains events for replay; documentId is the partition key. Hosts retry topics and per-topic DLQs." "Apache Kafka (KRaft)" "Broker"
            schemaRegistry = container "Schema Registry" "Stores Avro and JSON Schema definitions of the event contracts." "Apicurio Registry"
            minio = container "MinIO" "Object storage for raw uploads, extracted content, and chunk manifests." "MinIO (S3 API)" "ObjectStore"
            doclingServe = container "Docling Serve" "Vendored document-understanding engine: converts and chunks documents. Official image, no owned code." "Docling Serve (Python, vendored image)"
            ollama = container "Ollama" "Default self-hosted chat and embedding model runtime." "Ollama"

            authorizationDb = container "authorization-db" "Private store of Authorization & Identity-Context Service: corpus- and document-level grants and its outbox." "PostgreSQL" "Database"
            requestValidatorDb = container "request-validator-db" "Private store of Request Validator Service and its outbox." "PostgreSQL" "Database"
            ingestionDb = container "ingestion-db" "Private store of Ingestion Service: Upload aggregate and its outbox." "PostgreSQL" "Database"
            parsingDb = container "parsing-db" "Private store of Parsing Service: parse-job bookkeeping and its outbox." "PostgreSQL" "Database"
            chunkingDb = container "chunking-db" "Private store of Chunking Service and its outbox." "PostgreSQL" "Database"
            embeddingDb = container "embedding-db" "Embedding Service bookkeeping and its outbox, plus the shared PGVector index. Written by Embedding Service only; read by Retrieval Service." "PostgreSQL, pgvector" "Database"
            documentCatalogDb = container "document-catalog-db" "Private store of Document Catalog & Lifecycle Service: one current-state row per document, and its outbox." "PostgreSQL" "Database"
            auditDb = container "audit-db" "Append-only audit log. UPDATE and DELETE grants are revoked." "PostgreSQL" "Database"
            llmRouterDb = container "llm-router-db" "Private store of LLM Router Service: tenant routing policy and circuit-breaker state." "PostgreSQL" "Database"
        }

        // ---- People and external systems ------------------------------------------------------
        knowledgeWorker   -> corpora "Uploads documents, tracks status, and asks questions using" "HTTPS"
        corpusAdmin       -> corpora "Manages corpora, document ACLs, and routing policy using" "HTTPS"
        complianceOfficer -> corpora "Queries the audit trail using" "HTTPS"
        corpora -> keycloak "Validates JWTs and resolves claims with" "OIDC, JWKS"
        corpora -> cloudLlm "Requests chat completions and embeddings from (opt-in profiles)" "HTTPS"
        corpora -> observability "Exports metrics, traces, and logs to" "OTLP"

        knowledgeWorker -> corpora.gateway "Uploads documents, tracks status, and asks questions via" "HTTPS"
        corpora.gateway -> keycloak "Fetches signing keys to validate access tokens from" "HTTPS (JWKS)"

        // ---- Edge ----------------------------------------------------------------------------
        corpora.gateway -> corpora.ingestion "Forwards document uploads to" "HTTP (multipart)"
        corpora.gateway -> corpora.catalog "Forwards status, list, and delete requests to" "HTTP/REST"
        corpora.gateway -> corpora.queryProcessor "Forwards chat requests to, translating SSE to gRPC streaming" "gRPC"

        // ---- Synchronous calls, write side ---------------------------------------------------
        corpora.ingestion -> corpora.validator "Validates candidate uploads with" "gRPC" "ServiceCall"
        corpora.ingestion -> corpora.authz "Checks upload permission with" "gRPC" "ServiceCall"
        corpora.catalog -> corpora.authz "Checks permission on documents with" "gRPC" "ServiceCall"
        corpora.ingestion -> corpora.minio "Streams raw uploads to" "S3 API"
        corpora.parsing -> corpora.minio "Reads originals from and stores extracted content in" "S3 API"
        corpora.chunking -> corpora.minio "Reads originals from and stores chunk manifests in" "S3 API"
        corpora.parsing -> corpora.doclingServe "Requests document conversion from" "HTTP/REST"
        corpora.chunking -> corpora.doclingServe "Requests hybrid chunking from" "HTTP/REST"
        corpora.embedding -> corpora.ollama "Requests chunk embeddings from" "HTTP/REST"
        corpora.embedding -> cloudLlm "Requests chunk embeddings from (opt-in profile)" "HTTPS"
        corpora.embedding -> corpora.embeddingDb "Writes chunk vectors and bookkeeping to" "JDBC"

        // ---- Synchronous calls, read side ----------------------------------------------------
        corpora.queryProcessor -> corpora.retrieval "Requests candidate chunks (FindCandidates) from" "gRPC"
        corpora.queryProcessor -> corpora.reranker "Requests reranking (Rerank) from" "gRPC"
        corpora.queryProcessor -> corpora.formatter "Calls FormatStream on" "gRPC (bidirectional streaming)"
        corpora.formatter -> corpora.llmRouter "Requests streamed chat completions from" "gRPC"
        corpora.retrieval -> corpora.ollama "Requests query embeddings from" "HTTP/REST"
        corpora.retrieval -> cloudLlm "Requests query embeddings from (opt-in profile)" "HTTPS"
        corpora.retrieval -> corpora.embeddingDb "Reads vectors by ACL-filtered similarity search from (read-only DB role)" "JDBC" "CrossServiceRead"
        corpora.llmRouter -> corpora.ollama "Requests chat completions from" "HTTP/REST"
        corpora.llmRouter -> cloudLlm "Requests chat completions from (opt-in profile)" "HTTPS"

        // ---- Database per service ------------------------------------------------------------
        corpora.authz -> corpora.authorizationDb "Reads and writes grants and outbox rows in" "JDBC"
        corpora.validator -> corpora.requestValidatorDb "Reads and writes submission state and outbox rows in" "JDBC"
        corpora.ingestion -> corpora.ingestionDb "Reads and writes uploads and outbox rows in" "JDBC"
        corpora.parsing -> corpora.parsingDb "Reads and writes parse jobs and outbox rows in" "JDBC"
        corpora.chunking -> corpora.chunkingDb "Reads and writes chunk state and outbox rows in" "JDBC"
        corpora.catalog -> corpora.documentCatalogDb "Reads and writes the document projection and outbox rows in" "JDBC"
        corpora.audit -> corpora.auditDb "Appends audit entries to and queries" "JDBC"
        corpora.llmRouter -> corpora.llmRouterDb "Reads and writes routing policy and circuit-breaker state in" "JDBC"

        // ---- Kafka: publishers (write-side producers relay from their outbox) -----------------
        corpora.ingestion -> corpora.kafka "Publishes DocumentUploaded via outbox relay to" "Kafka protocol" "Async"
        corpora.validator -> corpora.kafka "Publishes DocumentUploadRejected via outbox relay to" "Kafka protocol" "Async"
        corpora.authz -> corpora.kafka "Publishes AccessGranted and AccessDenied via outbox relay to" "Kafka protocol" "Async"
        corpora.parsing -> corpora.kafka "Publishes DocumentParsed and DocumentParsingFailed via outbox relay to" "Kafka protocol" "Async"
        corpora.chunking -> corpora.kafka "Publishes ChunkCreated, DocumentChunked, and DocumentChunkingFailed via outbox relay to" "Kafka protocol" "Async"
        corpora.embedding -> corpora.kafka "Publishes ChunkEmbedded, ChunkEmbeddingFailed, and DocumentEmbeddingCompleted via outbox relay to" "Kafka protocol" "Async"
        corpora.catalog -> corpora.kafka "Publishes DocumentDeletionRequested and DocumentDeleted via outbox relay to" "Kafka protocol" "Async"

        // ---- Kafka: publishers (read-side audit events, fire-and-forget) ----------------------
        corpora.queryProcessor -> corpora.kafka "Publishes QueryReceived, QueryRewritten, and QueryAnswered, fire-and-forget, to" "Kafka protocol" "Async"
        corpora.retrieval -> corpora.kafka "Publishes ChunksRetrieved, fire-and-forget, to" "Kafka protocol" "Async"
        corpora.reranker -> corpora.kafka "Publishes RerankPerformed, fire-and-forget, to" "Kafka protocol" "Async"
        corpora.llmRouter -> corpora.kafka "Publishes LlmInvoked, fire-and-forget, to" "Kafka protocol" "Async"
        corpora.formatter -> corpora.kafka "Publishes ResponseFormatted, fire-and-forget, to" "Kafka protocol" "Async"

        // ---- Kafka: subscribers ----------------------------------------------------------------
        corpora.kafka -> corpora.parsing "Delivers DocumentUploaded and DocumentDeletionRequested to" "Kafka protocol" "Async"
        corpora.kafka -> corpora.chunking "Delivers DocumentParsed and DocumentDeletionRequested to" "Kafka protocol" "Async"
        corpora.kafka -> corpora.embedding "Delivers ChunkCreated and DocumentDeletionRequested to" "Kafka protocol" "Async"
        corpora.kafka -> corpora.ingestion "Delivers DocumentDeletionRequested to" "Kafka protocol" "Async"
        corpora.kafka -> corpora.catalog "Delivers upload, parse, chunk, and embedding lifecycle events and their failures to" "Kafka protocol" "Async"
        corpora.kafka -> corpora.audit "Delivers every audited domain event to" "Kafka protocol" "Async"

        // ---- Schema registry (every Kafka producer and consumer) -------------------------------
        corpora.ingestion -> corpora.schemaRegistry "Registers and fetches event schemas from" "HTTP/REST" "Schema"
        corpora.validator -> corpora.schemaRegistry "Registers and fetches event schemas from" "HTTP/REST" "Schema"
        corpora.authz -> corpora.schemaRegistry "Registers and fetches event schemas from" "HTTP/REST" "Schema"
        corpora.parsing -> corpora.schemaRegistry "Registers and fetches event schemas from" "HTTP/REST" "Schema"
        corpora.chunking -> corpora.schemaRegistry "Registers and fetches event schemas from" "HTTP/REST" "Schema"
        corpora.embedding -> corpora.schemaRegistry "Registers and fetches event schemas from" "HTTP/REST" "Schema"
        corpora.catalog -> corpora.schemaRegistry "Registers and fetches event schemas from" "HTTP/REST" "Schema"
        corpora.audit -> corpora.schemaRegistry "Fetches event schemas from" "HTTP/REST" "Schema"
        corpora.queryProcessor -> corpora.schemaRegistry "Registers and fetches event schemas from" "HTTP/REST" "Schema"
        corpora.retrieval -> corpora.schemaRegistry "Registers and fetches event schemas from" "HTTP/REST" "Schema"
        corpora.reranker -> corpora.schemaRegistry "Registers and fetches event schemas from" "HTTP/REST" "Schema"
        corpora.llmRouter -> corpora.schemaRegistry "Registers and fetches event schemas from" "HTTP/REST" "Schema"
        corpora.formatter -> corpora.schemaRegistry "Registers and fetches event schemas from" "HTTP/REST" "Schema"

        // ---- Observability (every application container) ---------------------------------------
        corpora.gateway -> observability "Exports metrics, traces, and logs to" "OTLP" "Observability"
        corpora.authz -> observability "Exports metrics, traces, and logs to" "OTLP" "Observability"
        corpora.validator -> observability "Exports metrics, traces, and logs to" "OTLP" "Observability"
        corpora.ingestion -> observability "Exports metrics, traces, and logs to" "OTLP" "Observability"
        corpora.parsing -> observability "Exports metrics, traces, and logs to" "OTLP" "Observability"
        corpora.chunking -> observability "Exports metrics, traces, and logs to" "OTLP" "Observability"
        corpora.embedding -> observability "Exports metrics, traces, and logs to" "OTLP" "Observability"
        corpora.catalog -> observability "Exports metrics, traces, and logs to" "OTLP" "Observability"
        corpora.audit -> observability "Exports metrics, traces, and logs to" "OTLP" "Observability"
        corpora.queryProcessor -> observability "Exports metrics, traces, and logs to" "OTLP" "Observability"
        corpora.retrieval -> observability "Exports metrics, traces, and logs to" "OTLP" "Observability"
        corpora.reranker -> observability "Exports metrics, traces, and logs to" "OTLP" "Observability"
        corpora.llmRouter -> observability "Exports metrics, traces, and logs to" "OTLP" "Observability"
        corpora.formatter -> observability "Exports metrics, traces, and logs to" "OTLP" "Observability"

        // ---- Components: Ingestion Service ------------------------------------------------------
        corpora.gateway -> corpora.ingestion.uploadController "Forwards document uploads to" "HTTP (multipart)"
        corpora.ingestion.uploadController -> corpora.minio "Streams raw bytes to" "S3 API"
        corpora.ingestion.uploadController -> corpora.ingestion.validatorClient "Validates before commit through"
        corpora.ingestion.uploadController -> corpora.ingestion.authorizationClient "Authorizes the upload through"
        corpora.ingestion.uploadController -> corpora.ingestion.uploadService "Commits the upload through"
        corpora.ingestion.validatorClient -> corpora.validator "Calls" "gRPC"
        corpora.ingestion.authorizationClient -> corpora.authz "Calls" "gRPC"
        corpora.ingestion.uploadService -> corpora.ingestionDb "Persists the Upload aggregate in" "JDBC"
        corpora.ingestion.uploadService -> corpora.ingestion.outbox "Records DocumentUploaded in the same transaction through"
        corpora.ingestion.outbox -> corpora.ingestionDb "Stores and polls outbox rows in" "JDBC"
        corpora.ingestion.outbox -> corpora.ingestion.uploadedProducer "Hands relayed rows to"
        corpora.ingestion.uploadedProducer -> corpora.kafka "Publishes DocumentUploaded to" "Kafka protocol" "Async"

        // ---- Components: Query Processor Service ---------------------------------------------------
        corpora.gateway -> corpora.queryProcessor.chatEndpoint "Forwards chat requests to" "gRPC"
        corpora.queryProcessor.chatEndpoint -> corpora.queryProcessor.queryRewriter "1. Rewrites the question with"
        corpora.queryProcessor.chatEndpoint -> corpora.queryProcessor.intentClassifier "2. Classifies intent with"
        corpora.queryProcessor.chatEndpoint -> corpora.queryProcessor.filterHintExtractor "3. Extracts filter hints with"
        corpora.queryProcessor.chatEndpoint -> corpora.queryProcessor.orchestrator "4. Orchestrates the answer with"
        corpora.queryProcessor.chatEndpoint -> corpora.queryProcessor.auditPublisher "Reports query lifecycle to"
        corpora.queryProcessor.orchestrator -> corpora.queryProcessor.deadlineManager "Enforces the budget with"
        corpora.queryProcessor.orchestrator -> corpora.queryProcessor.retrievalClient "Retrieves candidates through"
        corpora.queryProcessor.orchestrator -> corpora.queryProcessor.rerankerClient "Reranks through"
        corpora.queryProcessor.orchestrator -> corpora.queryProcessor.formatterClient "Streams the answer through"
        corpora.queryProcessor.retrievalClient -> corpora.retrieval "Calls FindCandidates on" "gRPC"
        corpora.queryProcessor.rerankerClient -> corpora.reranker "Calls Rerank on" "gRPC"
        corpora.queryProcessor.formatterClient -> corpora.formatter "Calls FormatStream on" "gRPC (bidirectional streaming)"
        corpora.queryProcessor.auditPublisher -> corpora.kafka "Publishes audit events, fire-and-forget, to" "Kafka protocol" "Async"

        // ---- Components: Retrieval Service -----------------------------------------------------------
        corpora.queryProcessor -> corpora.retrieval.findCandidates "Requests candidate chunks from" "gRPC"
        corpora.retrieval.findCandidates -> corpora.retrieval.queryEmbedder "1. Embeds the query with"
        corpora.retrieval.findCandidates -> corpora.retrieval.aclFilterBuilder "2. Builds the mandatory ACL filter with"
        corpora.retrieval.findCandidates -> corpora.retrieval.auditPublisher "Reports ChunksRetrieved to"
        corpora.retrieval.queryEmbedder -> corpora.ollama "Requests query embeddings from" "HTTP/REST"
        corpora.retrieval.queryEmbedder -> cloudLlm "Requests query embeddings from (opt-in profile)" "HTTPS"
        corpora.retrieval.aclFilterBuilder -> corpora.retrieval.hintMerger "3. Narrows the filter with the untrusted hint through"
        corpora.retrieval.hintMerger -> corpora.retrieval.similaritySearch "4. Executes the filtered search through"
        corpora.retrieval.similaritySearch -> corpora.embeddingDb "Reads vectors with a filtered SELECT from (read-only DB role)" "JDBC" "CrossServiceRead"
        corpora.retrieval.auditPublisher -> corpora.kafka "Publishes ChunksRetrieved, fire-and-forget, to" "Kafka protocol" "Async"

        // ---- Deployment -------------------------------------------------------------------------------
        selfHosted = deploymentEnvironment "Self-hosted (Docker Compose)" {

            deploymentNode "Docker host" "Single node or small fixed cluster. Exact topology is Unknown (ADR-0013). One service is one container; no replicas are specified." "Docker Compose" {

                deploymentNode "Public network" "The only application container reachable from the public network is the API Gateway. It also reaches internal services. Keycloak's user-facing endpoints may be exposed here too (ADR-0013)." "Compose network" {
                    deploymentNode "API Gateway" "" "Docker container" {
                        containerInstance corpora.gateway
                    }
                    deploymentNode "Keycloak" "Part of the Compose stack per ADR-0013. Whether this deployment ships its own Keycloak or uses an existing enterprise instance is Unknown." "Docker container" {
                        softwareSystemInstance keycloak
                    }
                }

                deploymentNode "Application services" "Internal network only. Presentational grouping of the thirteen non-edge services." "Compose network" {
                    deploymentNode "Authorization & Identity-Context Service" "" "Docker container" {
                        containerInstance corpora.authz
                    }
                    deploymentNode "Request Validator Service" "" "Docker container" {
                        containerInstance corpora.validator
                    }
                    deploymentNode "Ingestion Service" "" "Docker container" {
                        containerInstance corpora.ingestion
                    }
                    deploymentNode "Parsing Service" "" "Docker container" {
                        containerInstance corpora.parsing
                    }
                    deploymentNode "Chunking Service" "" "Docker container" {
                        containerInstance corpora.chunking
                    }
                    deploymentNode "Embedding Service" "" "Docker container" {
                        containerInstance corpora.embedding
                    }
                    deploymentNode "Document Catalog & Lifecycle Service" "" "Docker container" {
                        containerInstance corpora.catalog
                    }
                    deploymentNode "Audit Service" "" "Docker container" {
                        containerInstance corpora.audit
                    }
                    deploymentNode "Query Processor Service" "" "Docker container" {
                        containerInstance corpora.queryProcessor
                    }
                    deploymentNode "Retrieval Service" "" "Docker container" {
                        containerInstance corpora.retrieval
                    }
                    deploymentNode "Reranker Service" "" "Docker container" {
                        containerInstance corpora.reranker
                    }
                    deploymentNode "Response Formatter Service" "" "Docker container" {
                        containerInstance corpora.formatter
                    }
                    deploymentNode "LLM Router Service" "" "Docker container" {
                        containerInstance corpora.llmRouter
                    }
                }

                deploymentNode "Infrastructure" "Internal network only. Presentational grouping." "Compose network" {
                    deploymentNode "Kafka" "" "Docker container" {
                        containerInstance corpora.kafka
                    }
                    deploymentNode "Schema Registry" "" "Docker container" {
                        containerInstance corpora.schemaRegistry
                    }
                    deploymentNode "MinIO" "" "Docker container" {
                        containerInstance corpora.minio
                    }
                    deploymentNode "Docling Serve" "" "Docker container" {
                        containerInstance corpora.doclingServe
                    }
                    deploymentNode "Ollama" "" "Docker container" {
                        containerInstance corpora.ollama
                    }
                    deploymentNode "Observability Stack" "Prometheus, Grafana, Tempo, Loki." "Docker containers" {
                        softwareSystemInstance observability
                    }
                }

                deploymentNode "Postgres instances" "Internal network only. One dedicated instance per data-owning service (ADR-0012). Presentational grouping." "Compose network" {
                    deploymentNode "authorization-db" "" "Docker container" {
                        containerInstance corpora.authorizationDb
                    }
                    deploymentNode "request-validator-db" "" "Docker container" {
                        containerInstance corpora.requestValidatorDb
                    }
                    deploymentNode "ingestion-db" "" "Docker container" {
                        containerInstance corpora.ingestionDb
                    }
                    deploymentNode "parsing-db" "" "Docker container" {
                        containerInstance corpora.parsingDb
                    }
                    deploymentNode "chunking-db" "" "Docker container" {
                        containerInstance corpora.chunkingDb
                    }
                    deploymentNode "embedding-db" "" "Docker container" {
                        containerInstance corpora.embeddingDb
                    }
                    deploymentNode "document-catalog-db" "" "Docker container" {
                        containerInstance corpora.documentCatalogDb
                    }
                    deploymentNode "audit-db" "" "Docker container" {
                        containerInstance corpora.auditDb
                    }
                    deploymentNode "llm-router-db" "" "Docker container" {
                        containerInstance corpora.llmRouterDb
                    }
                }
            }
        }
    }

    views {

        systemContext corpora "context" "Who uses Corpora and which external systems it depends on." {
            include *
            autoLayout tb
            title "System Context diagram for Corpora"
        }

        container corpora "containers" "All fourteen application services and their synchronous calls. Events, datastores, and vendored infrastructure are on the other container views." {
            include knowledgeWorker
            include corpora.gateway corpora.authz corpora.validator corpora.ingestion corpora.parsing corpora.chunking corpora.embedding corpora.catalog corpora.audit
            include corpora.queryProcessor corpora.retrieval corpora.reranker corpora.formatter corpora.llmRouter
            autoLayout tb
            title "Container diagram for Corpora: service map (synchronous calls)"
        }

        container corpora "containers-write-events" "Write-side services and the events they publish to and consume from Kafka." {
            include corpora.authz corpora.validator corpora.ingestion corpora.parsing corpora.chunking corpora.embedding corpora.catalog corpora.audit corpora.kafka
            exclude "relationship.tag==ServiceCall"
            autoLayout lr
            title "Container diagram for Corpora: write-side events"
        }

        container corpora "containers-write-processing" "The synchronous dependencies of the document processing pipeline." {
            include corpora.ingestion corpora.parsing corpora.chunking corpora.embedding
            include corpora.minio corpora.doclingServe corpora.ollama corpora.embeddingDb cloudLlm
            autoLayout lr
            title "Container diagram for Corpora: write-side processing dependencies"
        }

        container corpora "containers-read-side" "Read-side services, the gRPC chain, and what the chat path depends on." {
            include knowledgeWorker keycloak cloudLlm
            include corpora.gateway corpora.queryProcessor corpora.retrieval corpora.reranker corpora.formatter corpora.llmRouter
            include corpora.ollama corpora.embeddingDb corpora.kafka
            autoLayout tb
            title "Container diagram for Corpora: read side"
        }

        container corpora "data-ownership" "One Postgres instance per data-owning service, and the single read-only cross-service exception." {
            include corpora.authz corpora.validator corpora.ingestion corpora.parsing corpora.chunking corpora.embedding corpora.catalog corpora.audit corpora.llmRouter corpora.retrieval
            include corpora.authorizationDb corpora.requestValidatorDb corpora.ingestionDb corpora.parsingDb corpora.chunkingDb corpora.embeddingDb corpora.documentCatalogDb corpora.auditDb corpora.llmRouterDb
            exclude "relationship.tag==ServiceCall"
            autoLayout lr
            title "Container diagram for Corpora: data ownership"
        }

        component corpora.ingestion "ingestion-components" "Transactional outbox inside Ingestion Service." {
            include *
            autoLayout tb
            title "Component diagram for Ingestion Service (Corpora)"
        }

        component corpora.queryProcessor "query-processor-components" "Orchestration and deadline budget inside Query Processor Service." {
            include *
            autoLayout tb
            title "Component diagram for Query Processor Service (Corpora)"
        }

        component corpora.retrieval "retrieval-components" "ACL enforcement inside Retrieval Service." {
            include *
            autoLayout tb
            title "Component diagram for Retrieval Service (Corpora)"
        }

        dynamic corpora "document-upload" "A document is accepted and its DocumentUploaded event is committed through the outbox and relayed to Kafka." {
            knowledgeWorker -> corpora.gateway "Uploads a document"
            corpora.gateway -> corpora.ingestion "Forwards the upload"
            corpora.ingestion -> corpora.minio "Streams raw bytes"
            corpora.ingestion -> corpora.validator "Validates quota, MIME type, malware result, and duplicate hash"
            corpora.ingestion -> corpora.authz "Checks upload permission"
            corpora.ingestion -> corpora.ingestionDb "Writes the Upload and the DocumentUploaded outbox row in one transaction"
            corpora.ingestion -> corpora.kafka "Relays DocumentUploaded from the outbox"
            autoLayout lr
            title "Dynamic diagram: upload a document (Corpora)"
        }

        dynamic corpora "document-processing" "An uploaded document is parsed, chunked, embedded, and becomes INDEXED, driven only by Kafka events." {
            corpora.kafka -> corpora.parsing "Delivers DocumentUploaded"
            corpora.parsing -> corpora.doclingServe "Requests conversion"
            corpora.parsing -> corpora.minio "Stores extracted content (claim-check)"
            corpora.parsing -> corpora.kafka "Publishes DocumentParsed"
            corpora.kafka -> corpora.chunking "Delivers DocumentParsed"
            corpora.chunking -> corpora.doclingServe "Requests hybrid chunking"
            corpora.chunking -> corpora.kafka "Publishes ChunkCreated per chunk, then DocumentChunked"
            corpora.kafka -> corpora.embedding "Delivers ChunkCreated"
            corpora.embedding -> corpora.ollama "Embeds chunk text"
            corpora.embedding -> corpora.embeddingDb "Writes the vector to the PGVector index"
            corpora.embedding -> corpora.kafka "Publishes DocumentEmbeddingCompleted"
            corpora.kafka -> corpora.catalog "Delivers DocumentEmbeddingCompleted: stage becomes INDEXED"
            autoLayout lr
            title "Dynamic diagram: process an uploaded document (Corpora)"
        }

        dynamic corpora "ask-question" "A question is answered by a synchronous gRPC chain with an ACL-filtered search." {
            knowledgeWorker -> corpora.gateway "Asks a question"
            corpora.gateway -> corpora.queryProcessor "Forwards the request with trusted tenant and ACL claims"
            corpora.queryProcessor -> corpora.retrieval "Requests candidate chunks"
            corpora.retrieval -> corpora.ollama "Embeds the query"
            corpora.retrieval -> corpora.embeddingDb "Runs the ACL-filtered similarity search"
            corpora.queryProcessor -> corpora.reranker "Requests reranking"
            corpora.queryProcessor -> corpora.formatter "Opens FormatStream with the reranked context"
            corpora.formatter -> corpora.llmRouter "Requests streamed chat completion"
            corpora.llmRouter -> corpora.ollama "Requests chat completion from the selected provider"
            autoLayout lr
            title "Dynamic diagram: ask a question (Corpora)"
        }

        deployment corpora "selfHosted" "deployment-self-hosted" "Where each container runs in the documented Docker Compose deployment." {
            include *
            exclude "relationship.tag==Async"
            exclude "relationship.tag==Schema"
            exclude "relationship.tag==Observability"
            autoLayout lr
            title "Deployment diagram for Corpora: self-hosted (Docker Compose)"
        }

        styles {
            element "Element" {
                color #ffffff
            }
            element "Person" {
                shape Person
                background #08427b
            }
            element "Software System" {
                background #1168bd
            }
            element "External" {
                background #6b6b6b
                border dashed
            }
            element "Container" {
                background #438dd5
            }
            element "Component" {
                background #85bbf0
                color #000000
            }
            element "Database" {
                shape Cylinder
            }
            element "ObjectStore" {
                shape Folder
            }
            element "Broker" {
                shape Pipe
            }
            relationship "Relationship" {
                dashed false
            }
            relationship "Async" {
                dashed true
            }
            relationship "CrossServiceRead" {
                thickness 4
            }
        }
    }
}

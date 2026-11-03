# Corpora

A self-hosted enterprise platform for question answering over documents (retrieval-augmented generation): upload documents, index them, and ask questions that return cited answers, with access control per document. Built as event-driven microservices on Java 25, Spring Boot 4, and Spring AI 2.

Owner: Unknown · On-call: Unknown · Status: design phase, no service implemented yet

## Run it locally

Not possible yet. No service exists, `settings.gradle.kts` declares no modules, and there is no `docker-compose.yml`. The planned order of work is in [About the build order](docs/explanation/build-order.md).

## Where to go next

- Architecture overview (arc42, C4 diagrams): [docs/architecture/arc42/README.md](docs/architecture/arc42/README.md)
- Architecture model, source of every diagram: [docs/architecture/workspace.dsl](docs/architecture/workspace.dsl)
- Decisions: [docs/adr/](docs/adr)
- Event reference: [docs/reference/events.md](docs/reference/events.md)
- Build order and its reasoning: [docs/explanation/build-order.md](docs/explanation/build-order.md)
- Refresh the diagrams after a model change: [docs/how-to/regenerate-architecture-diagrams.md](docs/how-to/regenerate-architecture-diagrams.md)

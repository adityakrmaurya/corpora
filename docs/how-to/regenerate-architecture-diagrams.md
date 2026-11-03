# How to regenerate the architecture diagrams

This guide shows you how to validate the C4 model in `docs/architecture/workspace.dsl`, refresh the exported diagram files, and update the diagrams embedded in the arc42 pages.

## Before you start

- You changed `workspace.dsl`. Never edit files in `docs/architecture/diagrams/` or the Mermaid blocks marked `generated from` by hand.
- You have the Structurizr tooling. Either:
  - Docker, with the `structurizr/structurizr` image (the command form documented at [docs.structurizr.com](https://docs.structurizr.com/commands)), or
  - the Structurizr CLI release `v2025.11.09` (`structurizr-cli.zip`) and a Java runtime. The repository was last validated this way, with Java 25.

## Steps

1. Validate the model. A non-zero exit code means a DSL error, and the message names the line.

   With the CLI, from the folder where you unpacked it:

   ```bash
   java -cp "lib/*" com.structurizr.cli.StructurizrCliApplication validate -workspace <repo>/docs/architecture/workspace.dsl
   ```

   With Docker, from the repository root:

   ```bash
   docker run --rm -v "$PWD":/usr/local/structurizr structurizr/structurizr validate -workspace docs/architecture/workspace.dsl
   ```

2. Export every view to Mermaid.

   ```bash
   java -cp "lib/*" com.structurizr.cli.StructurizrCliApplication export -workspace <repo>/docs/architecture/workspace.dsl -format mermaid -output <repo>/docs/architecture/diagrams
   ```

   Docker form:

   ```bash
   docker run --rm -v "$PWD":/usr/local/structurizr structurizr/structurizr export -workspace docs/architecture/workspace.dsl -format mermaid -output docs/architecture/diagrams
   ```

   One `structurizr-<view-key>.mmd` file is written per view.

3. Update the embedded copies. Each arc42 page that shows a view contains a comment `generated from docs/architecture/workspace.dsl, view "<key>"` followed by a `mermaid` block. Replace the block's content with the full content of `docs/architecture/diagrams/structurizr-<key>.mmd`.

4. Find the pages that embed a given view.

   ```bash
   grep -rn 'view "containers"' docs/architecture/arc42
   ```

5. Check that the diagram still renders. Open one changed `.mmd` file on GitHub, or render it with `npx @mermaid-js/mermaid-cli -i <file>.mmd -o <file>.png`. Structurizr's Mermaid export uses HTML labels; if a viewer shows raw `<div>` text, set Mermaid's `securityLevel` to `loose` for that viewer.

6. Commit `workspace.dsl`, the changed `.mmd` files, and the edited arc42 pages together.

## If something goes wrong

- *`The destination element "x" does not exist`*: a relationship refers to an identifier that is not defined; with `!identifiers hierarchical` use the full dotted path, for example `corpora.ingestion`.
- *A dynamic view fails*: each step needs a matching relationship in the model, in the same direction. Add it to the model first.
- *A view lists unexpected elements*: `include *` pulls in everything directly connected. Use an explicit `include` list or an `exclude "relationship.tag==..."` line, as the existing views do.

See also: [arc42 §5](../architecture/arc42/05-building-block-view.md) for what the views show.

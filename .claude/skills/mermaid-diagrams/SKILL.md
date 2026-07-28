---
name: mermaid-diagrams
description: Create or update architecture/Mermaid diagrams in this repo (docs/architecture/**). Covers why we pre-render to SVG, the validated flowchart theme/palette, and the specific dagre-layout pitfalls that make Mermaid diagrams look ugly if you don't work around them.
---

# Mermaid diagrams in this repo

Use this whenever creating or editing a diagram under `docs/architecture/diagrams/` (or anywhere else in the repo that embeds a Mermaid diagram as an image).

## Why we don't render Mermaid live on GitHub

GitHub's built-in Mermaid renderer does not support the C4 diagram type
(`C4Context` / `C4Container` / `C4Component`) — confirmed via
https://github.com/orgs/community/discussions/197898. Mermaid's own docs also
mark C4 diagrams "experimental," and in practice their automatic layout is bad
even when it does render (nodes stack in one column, edge labels collide with
boxes, arrows cross through unrelated nodes).

Because of both problems, diagrams here are **pre-rendered to SVG** with
`mermaid-cli` and embedded as images — never as a live mermaid fence.
This also means: **you are not limited to C4 syntax**. Prefer a plain
`flowchart` with `classDef` styling over `C4Context`/`C4Container`/`C4Component`
— same information, a far more mature layout engine (dagre), full control over
colors/shapes, and no GitHub-support question to worry about.

## File layout & regeneration

- `docs/architecture/<name>.md` — prose + embedded SVG, links to the `.mmd` source
- `docs/architecture/diagrams/<name>.mmd` — editable Mermaid source (source of truth)
- `docs/architecture/diagrams/<name>.svg` — rendered output, committed alongside the source

Regenerate after editing a `.mmd`:

    npx --yes @mermaid-js/mermaid-cli -i docs/architecture/diagrams/<name>.mmd -o docs/architecture/diagrams/<name>.svg -b white

Don't pass `-w`/`-H` for the real render — SVG output auto-sizes to the
content's bounding box. Only use `-w 2000 -H 1400` (or similar) when rendering
a throwaway **PNG** to visually self-check a diagram before finalizing it —
mmdc's default 800x600 puppeteer viewport otherwise squashes/scales a PNG
preview down to illegible.

Each `.md` file should link back to its source and give the exact regen
command, e.g.:

    ![Container Diagram — Corpora](diagrams/c4-container.svg)

    > Diagram source: [`diagrams/c4-container.mmd`](diagrams/c4-container.mmd). Regenerate with:
    > `npx --yes @mermaid-js/mermaid-cli -i diagrams/c4-container.mmd -o diagrams/c4-container.svg -b white`

## The validated theme + palette

Start every diagram with this init block (tune `primaryColor` per
diagram — teal `#0d9488` for write-side/pipeline diagrams, violet `#7c3aed`
for read-side, blue `#2563eb` for top-level context):

    %%{init: {
      "theme": "base",
      "themeVariables": {
        "fontFamily": "Segoe UI, Helvetica, Arial, sans-serif",
        "fontSize": "14px",
        "primaryColor": "#0d9488",
        "primaryTextColor": "#ffffff",
        "primaryBorderColor": "#0f766e",
        "lineColor": "#94a3b8",
        "secondaryColor": "#e2e8f0"
      },
      "flowchart": {
        "curve": "basis",
        "nodeSpacing": 35,
        "rankSpacing": 70,
        "padding": 10,
        "diagramPadding": 20
      },
      "htmlLabels": true
    }}%%
    flowchart TB

And always end the diagram with this line — see "edge label text is
invisible" below for why:

    linkStyle default color:#1e293b,font-weight:500;

Standard `classDef` palette (reuse these categories, don't invent new colors
per diagram):

    classDef person   fill:#1e3a5f,stroke:#0f2942,color:#ffffff   /* actor, stadium shape ([...]) */
    classDef gateway  fill:#1e293b,stroke:#0f172a,color:#ffffff   /* entry point, near-black */
    classDef writeSvc fill:#0d9488,stroke:#0f766e,color:#ffffff   /* write-side / async service */
    classDef readSvc  fill:#7c3aed,stroke:#6d28d9,color:#ffffff   /* read-side / sync service */
    classDef stub     fill:#5eead4,stroke:#0f766e,color:#0f172a,stroke-dasharray:3 2  /* thin gRPC client stub */
    classDef db       fill:#334155,stroke:#1e293b,color:#ffffff   /* cylinder shape [(...)] */
    classDef queue    fill:#ea580c,stroke:#c2410c,color:#ffffff   /* hexagon shape {{...}} */
    classDef external fill:#64748b,stroke:#475569,color:#ffffff   /* other container / external system */
    classDef risk     fill:#b91c1c,stroke:#7f1d1d,color:#ffffff,stroke-width:2px  /* flag security/risk-critical logic */

Node label convention (relies on `htmlLabels: true`): `<b>Name</b><br/><i>Tech
or type</i><br/>One-line description`. Keep edge labels **plain text, single
line** (no `<br/>`/`<i>` inside the label) — see pitfalls below.

## Layout pitfalls that will make it ugly (and the fix)

These cost real trial-and-error to find. Apply them up front, don't rediscover them.

1. **Subgraph `direction` is silently ignored.** If any node inside a
   `subgraph` has an edge to a node *outside* it, the subgraph inherits the
   parent flowchart's direction instead of the one you declared — so
   `direction LR` on a group of 3 unconnected "sibling" nodes does nothing,
   and they stack vertically instead of sitting in a row.
   **Fix: don't wrap independent sibling nodes in a subgraph at all.** Nodes
   that share a common predecessor/successor and have no edges between them
   are placed in the same rank (i.e. the same row, for `flowchart TB`)
   automatically by dagre — rely on that instead of a subgraph.

2. **Nodes with no incoming edge float to the root rank**, even if they're
   conceptually "downstream" of something. E.g. a service that only has an
   outgoing edge to a shared bus (Kafka) but no matching "bus consumed
   by this service" edge gets placed at rank 0, next to your actors — wrecking
   the whole layout into something flat and wide.
   **Fix:** add the missing edge in the other direction. If you don't want it
   visible, make it an **invisible link** (`kafka ~~~ parsing`) — it still
   affects rank computation but draws nothing.

3. **Edge labels can render with a jarring, theme-derived background**
   (often neon green). That background comes from `secondaryColor`, not from
   `edgeLabelBackground` — override `secondaryColor` to a neutral tint (e.g.
   `#e2e8f0`) instead of fighting `edgeLabelBackground` directly (setting
   `edgeLabelBackground` explicitly has caused labels to disappear entirely
   in testing — a puppeteer/foreignObject sizing quirk).

4. **Edge label text color is not controlled by `primaryTextColor` or
   `secondaryTextColor`.** The only reliable fix found: an explicit
   `linkStyle default color:#1e293b,font-weight:500;` line at the end of the
   diagram. Always include it — without it, label text can render at low/zero
   contrast against its background.

5. **Big diagrams (20+ nodes) get cluttered fast if every repeated
   infrastructure detail is its own node.** E.g. "every service has its own
   Postgres instance" doesn't need 9 near-identical DB cylinders + 9 edges —
   fold that into each service's own label as an extra description line
   ("own Postgres instance"), and keep a real, separate DB node + edge only
   for the ONE case that's actually interesting/exceptional (and give that
   edge a heavier style, e.g. a thick arrow, plus a clear label, so it reads
   as intentional rather than as layout noise).

6. Prefer color + shape as the primary way to communicate category
   (actor/entry-point/service-tier/db/queue/external/risk — see palette
   above) over drawing boundary boxes. Boundary boxes (subgraphs) are the
   single biggest source of the layout bugs above; only reach for one when
   its nodes have no edges leaving it (a legend, for instance, is safe).

## Workflow

1. Write/edit the `.mmd` source using the template + palette above.
2. Render a throwaway PNG at a large viewport to self-check:
   `npx --yes @mermaid-js/mermaid-cli -i x.mmd -o /tmp-preview.png -b white -w 2000 -H 1300`
3. View the PNG (e.g. via the `Read` tool) and check for: overlapping
   text/boxes, arrows crossing through node interiors, illegible/invisible
   edge labels, awkwardly placed nodes (usually pitfall #2).
4. Iterate on the `.mmd` until clean.
5. Render the real SVG (no `-w`/`-H`) to `docs/architecture/diagrams/<name>.svg`.
6. Embed it in the `.md` file with the source link + regen command shown above.
7. Commit both the `.mmd` and the `.svg`.

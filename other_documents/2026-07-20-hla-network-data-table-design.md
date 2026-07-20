# HLA & TCR Motifs — "Network data" table

Design spec · 2026-07-20 · status: approved, not yet implemented

## Purpose

The Motif Network shows *dots and lines* but never the rows behind them. A user
looking at the graph cannot tell what one dot **is**, why colouring by
`cell_type` paints everything one colour, or which cells the Class I / Class II
allele pickers actually pulled into scope. Give the page a plain table that lists
the **actual data behind the currently displayed network**, so the graph becomes
legible as data.

Trigger: user confusion — "所有点都是 T 细胞都是蓝色 … 我其实不太清楚数据是什么样子的。"

## Background — what the network is (so the table's columns make sense)

- **A node = one unique TCR CDR3** (of the active `Chain`, e.g. TRB). Node area ∝
  number of analysis units (cells) carrying that CDR3.
- **An edge = two CDR3s at Hamming distance 1** (one amino-acid apart). A
  connected cluster = a "motif family". Cluster id is `V(g)$cluster`.
- **Scope filters which cells build the graph.** In `pair` scope the graph is the
  CD8 cells of donors carrying the Class I allele plus the CD4 cells of donors
  carrying the Class II allele; changing an allele changes the cell subset, hence
  a different network. `hla_scoped_segments()` is that per-cell subset.
- Colouring by `cell_type` is uninformative in the synthetic demo because that
  column holds a single value ("T cells"); this table is the remedy — it shows
  the finer per-row detail the colour cannot.

### Existing surfaces (why a new one is needed)

- **Node details** (`output$hla_node_details`, on click) — inspects **one** node.
- **Data & QC tab** — HLA **typing** data (donor genotypes, coverage, mapping),
  not the network's CDR3 rows.
- Gap: nothing lists **all** rows of the current network at once. This spec fills
  exactly that gap.

## Scope

**In scope**

- A new sub-tab **"Network data"** on the HLA & TCR Motifs page, beside Motif
  Network / HLA Associations / Data & QC.
- Two switchable granularities (a radio at the top):
  - **By motif (node)** — one row per CDR3 node in the current graph.
  - **By cell** — one row per underlying cell/segment (`hla_scoped_segments()`).
- A `DT` table (built-in search / sort / pagination).
- A **Download CSV** button exporting the current view.
- The table follows the **current network state** (chain, scope, allele(s),
  min motif size, show-isolated) — same reactives that build the graph.

**Out of scope (non-goals)**

- No new analysis, no new data computation — presentation only, over existing
  reactives.
- No click-to-cross-highlight between table and graph (possible later; YAGNI now).
- Not part of PR #88 — this is an independent follow-up.

## Design

### Placement & structure

- New `tabPanel("Network data", ...)` in the HLA page UI (`UI.R`), after
  "HLA Associations".
- Inside: `radioButtons("hla_table_grain", choices = c("By motif (node)" =
  "node", "By cell" = "cell"), inline = TRUE)`, `DT::dataTableOutput`, and a
  `downloadButton`.
- Server outputs live in `visualizations.R` (or a small new `network_table.R`
  sourced by the module). **No core file** — this is inst/-only UI, so no
  `R/` ↔ `core/` duplication.

### Data sources (the key that keeps it small and exact)

- **Node view** — `igraph::as_data_frame(hla_motif_graph(), what = "vertices")`,
  then select/rename. This is the *same object the graph draws*, so the table
  matches the picture by construction. Available vertex attrs include `cdr3`,
  `v_gene`, `j_gene`, `cluster`, `samples_all`, `sample_origin`, plus the
  clone-size and colour-derived attrs already computed for the tooltip.
- **Cell view** — `hla_scoped_segments()`, the per-cell scoped rows that feed the
  graph, with columns selected below.

Because both are existing reactives, the table needs **no** new filtering logic
and cannot drift from the graph.

### Not limited by the render cap

`HLA_MOTIF_MAX_RENDER` (= 5000) is only a **render** cap — `visNetwork` stops
drawing above it, but `hla_build_motif_graph()` builds the full igraph
regardless. So the node table derives from the built graph's vertices and lists
**all** rows even when the graph is too large to draw. This is the table earning
its place: data where the canvas gives up.

### Default columns

- **Node view**: `CDR3 | V | J | cells (clone size) | motif cluster` + the
  column that matches the current scope/colour:
  - `pair` scope → allele side (CD8/Class I vs CD4/Class II, i.e. `pair_allele`)
  - `allele` scope → carrier status
  - `all` scope → sample(s) (`samples_all`)
- **Cell view**: `sample | cell_type | cell_type_fine | CDR3 | V | J` + (`pair` →
  side / `allele` → carrier). Columns absent from a given dataset are dropped
  (intersect with available columns, as the module already does elsewhere).

### Edge cases

- **Empty graph / no rows in scope** → the table renders empty with the same
  "nothing in scope" wording family the panel already uses; the Download button
  is disabled or exports a header-only CSV.
- **Graph over the render cap** → table still lists all rows (see above).
- **Column not present** (e.g. no `cell_type_fine`) → silently omitted.

### CSV export

`downloadHandler` writing the *currently shown view* (node or cell) as
`hla_network_<grain>_<dataset>.csv`. Reuses the same data frame the DT renders.

## Testing

Follows the module's existing **source-contract** style
(`test-hla-app-contract.R`, cross-line-tolerant regex per repo convention):

- The "Network data" `tabPanel` exists in `UI.R`.
- The node-view reactive reads `hla_motif_graph()` vertices (not a re-derivation),
  and the cell-view reactive reads `hla_scoped_segments()`.
- The node table is **not** gated on `HLA_MOTIF_MAX_RENDER` (assert the render cap
  does not appear in the table reactive).
- A `downloadHandler` for the table exists.

Plus one **live check** (hot-reload + Playwright), as done for #8: load the
synthetic HLA demo, open "Network data", confirm the node count in the table
equals the graph's node count for a given scope, switch grain, switch an allele,
confirm the table tracks it.

## Effort & placement

Small, self-contained, presentation-only: UI tab + 2 table reactives + 1
download, all over existing reactives. `visualizations.R` / `UI.R` +
`test-hla-app-contract.R`. Independent of PR #88.

# HLA "Network data" table — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a "Network data" sub-tab to the HLA & TCR Motifs page that lists, as a searchable/downloadable table, the actual data rows behind the currently displayed motif network — switchable between one-row-per-node (CDR3) and one-row-per-cell.

**Architecture:** Presentation-only over existing reactives. The node view reads the vertices of the SAME graph object the network draws (`hla_motif_graph()`), so it matches the picture by construction and is unaffected by the render cap. The cell view reads the per-cell scoped rows (`hla_scoped_segments()`). A radio switches grain; a `DT` renders it; a `downloadHandler` exports the current view.

**Tech Stack:** R, Shiny (module sourced with `local = TRUE`), `DT`, `igraph`, testthat (source-contract style + a Playwright live check).

---

## Background the implementer needs

- This is an **inst/-only Shiny module** at `inst/shiny/v1.4/hla_tcr_motifs/`. Its files are sourced explicitly by `server.R` into the app server scope, so `output$...`, `input$...`, `reactive(...)` at file top level all land in the server. There is **no** package namespace at runtime in a bundle — do **not** write `cerebroAppLite:::`; call bare names. These files are **not** the `R/` ↔ `core/` duplicated set, so **no core sync / document() is needed**.
- The display graph reactive is `hla_motif_graph()` ([data.R:817](../inst/shiny/v1.4/hla_tcr_motifs/data.R)). `hla_motif_graph_ok(g)` is the "is this a usable igraph" guard. `HLA_MOTIF_MAX_RENDER` (=5000) is only a **render** cap in `visualizations.R`; the graph is still built above it, so the table simply does not reference that constant.
- Node vertex attributes (from `hla_aggregate_cdr3_nodes` in `core/hla_motif_core.R`, plus `cluster` added at build): `cdr3`, `v_gene`, `j_gene`, `clone_count`, `samples_all`, `sample_origin`, `cluster`, and the active meta columns (`cell_type`, `cell_type_fine`, `mhc_context`, `pair_allele`) when present. `igraph::as_data_frame(g, what = "vertices")` also yields a `name` column.
- Per-cell rows: `hla_scoped_segments()` ([data.R:620](../inst/shiny/v1.4/hla_tcr_motifs/data.R)).
- Download pattern in this module: `downloadHandler(filename, content = function(file) utils::write.csv(df, file, row.names = FALSE, na = ""))` (see `hla_download_normalized` in `data_qc.R`).
- **Test idiom (critical):** the module is tested by **source-contract regex** in `tests/testthat/test-hla-app-contract.R` (helper `hla_inst_file()` reads the source). Run with `Rscript -e 'devtools::test(filter = "hla-app-contract")'` — under `devtools::test` `system.file()` resolves to the **source** tree, so no reinstall is needed. Match patterns with cross-line tolerance `[\\s\\S]{0,N}` because `air` reflows code (see project CLAUDE.md). `air format <files>` before every commit.

## File Structure

- **Create** `inst/shiny/v1.4/hla_tcr_motifs/network_table.R` — the whole feature's server side: grain reactive, table-data reactive, `DT` render, CSV download. One responsibility: the Network data table.
- **Modify** `inst/shiny/v1.4/hla_tcr_motifs/server.R` — add one `source(...)` block for `network_table.R` (after `visualizations.R`).
- **Modify** `inst/shiny/v1.4/hla_tcr_motifs/UI.R` — add the "Network data" `tabPanel` (radio + `DT` output + download button) inside the `tabsetPanel(id = "hla_tabs")`, between "HLA Associations" and "Data & QC".
- **Modify** `tests/testthat/test-hla-app-contract.R` — one new `test_that` block of source-contract assertions.

---

### Task 1: Add the "Network data" tab to the UI

**Files:**
- Modify: `inst/shiny/v1.4/hla_tcr_motifs/UI.R` (inside `tabsetPanel(id = "hla_tabs")`, ~line 104–113)
- Test: `tests/testthat/test-hla-app-contract.R`

- [ ] **Step 1: Write the failing test** — append to `tests/testthat/test-hla-app-contract.R`:

```r
test_that("the Network data tab exposes grain radio, table and download", {
  ui_src <- paste(
    readLines(hla_inst_file("shiny/v1.4/hla_tcr_motifs/UI.R"), warn = FALSE),
    collapse = "\n"
  )
  expect_match(ui_src, "tabPanel\\([\\s\\S]{0,40}\"Network data\"", perl = TRUE)
  expect_match(ui_src, "radioButtons\\([\\s\\S]{0,40}\"hla_table_grain\"", perl = TRUE)
  expect_match(ui_src, "dataTableOutput\\([\\s\\S]{0,20}\"hla_network_table\"", perl = TRUE)
  expect_match(ui_src, "downloadButton\\([\\s\\S]{0,20}\"hla_network_download\"", perl = TRUE)
})
```

- [ ] **Step 2: Run test to verify it fails**

Run: `Rscript -e 'devtools::test(filter = "hla-app-contract")' 2>&1 | grep -E "Network data tab|\\[ FAIL"`
Expected: FAIL (4 expect_match fail — none of these strings exist in UI.R yet).

- [ ] **Step 3: Add the tab** — in `UI.R`, insert this `tabPanel` between the "HLA Associations" tabPanel and the "Data & QC" tabPanel:

```r
          tabPanel(
            "Network data",
            br(),
            radioButtons(
              "hla_table_grain",
              "Rows:",
              choices = c(
                "By motif (node)" = "node",
                "By cell" = "cell"
              ),
              selected = "node",
              inline = TRUE
            ),
            tags$p(
              class = "text-muted",
              style = "font-size: 12px;",
              paste(
                "The rows behind the network shown on Motif Network, under the",
                "current chain / scope / allele / min-size filters. 'By motif' is",
                "one row per CDR3 node; 'By cell' is one row per cell."
              )
            ),
            DT::dataTableOutput("hla_network_table"),
            br(),
            downloadButton(
              "hla_network_download",
              "Download CSV",
              class = "btn-sm"
            )
          ),
```

- [ ] **Step 4: Run test to verify it passes**

Run: `air format inst/shiny/v1.4/hla_tcr_motifs/UI.R tests/testthat/test-hla-app-contract.R && Rscript -e 'devtools::test(filter = "hla-app-contract")' 2>&1 | grep -E "\\[ FAIL"`
Expected: `[ FAIL 0 | ... ]`.

- [ ] **Step 5: Commit**

```bash
git add inst/shiny/v1.4/hla_tcr_motifs/UI.R tests/testthat/test-hla-app-contract.R
git commit -m "feat(hla): add Network data tab shell"
```

---

### Task 2: Table-data reactive (node + cell) and source wiring

**Files:**
- Create: `inst/shiny/v1.4/hla_tcr_motifs/network_table.R`
- Modify: `inst/shiny/v1.4/hla_tcr_motifs/server.R` (add a `source()` after the `visualizations.R` block, ~line 38)
- Test: `tests/testthat/test-hla-app-contract.R`

- [ ] **Step 1: Write the failing test** — append:

```r
test_that("the network table reads the graph and the segments, not the render cap", {
  src <- paste(
    readLines(hla_inst_file("shiny/v1.4/hla_tcr_motifs/network_table.R"), warn = FALSE),
    collapse = "\n"
  )
  # node view from the SAME graph object the network draws
  expect_match(src, "hla_network_table_data <- reactive\\(", perl = TRUE)
  expect_match(src, "hla_motif_graph\\(\\)", perl = TRUE)
  expect_match(src, "as_data_frame\\([\\s\\S]{0,40}\"vertices\"", perl = TRUE)
  # cell view from the scoped per-cell rows
  expect_match(src, "hla_scoped_segments\\(\\)", perl = TRUE)
  # switched by the grain input
  expect_match(src, "input\\$hla_table_grain", perl = TRUE)
  # NOT bound by the render cap (this is data, not canvas)
  expect_no_match(src, "HLA_MOTIF_MAX_RENDER", perl = TRUE)
  # sourced into the module
  server_src <- paste(
    readLines(hla_inst_file("shiny/v1.4/hla_tcr_motifs/server.R"), warn = FALSE),
    collapse = "\n"
  )
  expect_match(server_src, "network_table\\.R", perl = TRUE)
})
```

- [ ] **Step 2: Run test to verify it fails**

Run: `Rscript -e 'devtools::test(filter = "hla-app-contract")' 2>&1 | grep -E "reads the graph|\\[ FAIL"`
Expected: FAIL — `network_table.R` does not exist (readLines errors → test fails), and `server.R` has no reference.

- [ ] **Step 3: Create `network_table.R`** with this content:

```r
##----------------------------------------------------------------------------##
## HLA & TCR Motifs — "Network data" table
##
## Presentation only. Node view = the vertices of the SAME graph object the
## Motif Network draws (hla_motif_graph()), so the table matches the picture by
## construction and is NOT bound by the render cap -- the graph is built even
## when too large to draw. Cell view = the per-cell scoped rows (hla_scoped_
## segments()) that feed the graph. No new data logic; both reuse existing
## reactives, so the table cannot drift from the graph.
##----------------------------------------------------------------------------##

## Desired columns -> display names, per grain. Columns absent from a given
## dataset/scope are dropped (intersect with what the data actually carries),
## the same defensive pattern as hla_node_meta_cols().
HLA_NETWORK_TABLE_NODE_COLS <- c(
  cdr3 = "CDR3",
  v_gene = "V",
  j_gene = "J",
  clone_count = "cells",
  cluster = "motif cluster",
  pair_allele = "allele side",
  mhc_context = "MHC context",
  samples_all = "samples",
  sample_origin = "sample origin"
)
HLA_NETWORK_TABLE_CELL_COLS <- c(
  sample = "sample",
  cell_type = "cell_type",
  cell_type_fine = "cell_type_fine",
  cdr3 = "CDR3",
  v_gene = "V",
  j_gene = "J",
  pair_allele = "allele side",
  mhc_context = "MHC context"
)

hla_network_table_grain <- reactive({
  g <- input$hla_table_grain
  if (is.null(g) || !nzchar(g)) "node" else g
})

## The data frame currently shown, already column-selected and renamed. NULL
## when there is nothing in scope / no graph, which the render treats as empty.
hla_network_table_data <- reactive({
  if (identical(hla_network_table_grain(), "cell")) {
    df <- hla_scoped_segments()
    map <- HLA_NETWORK_TABLE_CELL_COLS
  } else {
    g <- hla_motif_graph()
    if (!hla_motif_graph_ok(g)) {
      return(NULL)
    }
    df <- igraph::as_data_frame(g, what = "vertices")
    map <- HLA_NETWORK_TABLE_NODE_COLS
  }
  if (is.null(df) || nrow(df) == 0) {
    return(NULL)
  }
  keep <- intersect(names(map), colnames(df))
  out <- df[, keep, drop = FALSE]
  colnames(out) <- unname(map[keep])
  rownames(out) <- NULL
  out
})
```

- [ ] **Step 4: Wire it into `server.R`** — insert this block immediately after the `visualizations.R` source block (after its closing `)` near line 38):

```r
source(
  paste0(
    Cerebro.options[["cerebro_root"]],
    "/shiny/v1.4/hla_tcr_motifs/network_table.R"
  ),
  local = TRUE
)
```

- [ ] **Step 5: Run test to verify it passes**

Run: `air format inst/shiny/v1.4/hla_tcr_motifs/network_table.R inst/shiny/v1.4/hla_tcr_motifs/server.R tests/testthat/test-hla-app-contract.R && Rscript -e 'devtools::test(filter = "hla-app-contract")' 2>&1 | grep -E "\\[ FAIL"`
Expected: `[ FAIL 0 | ... ]`.

- [ ] **Step 6: Commit**

```bash
git add inst/shiny/v1.4/hla_tcr_motifs/network_table.R inst/shiny/v1.4/hla_tcr_motifs/server.R tests/testthat/test-hla-app-contract.R
git commit -m "feat(hla): network table data reactive (node + cell)"
```

---

### Task 3: Render the table and wire the CSV download

**Files:**
- Modify: `inst/shiny/v1.4/hla_tcr_motifs/network_table.R` (append)
- Test: `tests/testthat/test-hla-app-contract.R`

- [ ] **Step 1: Write the failing test** — append:

```r
test_that("the network table renders and downloads the current view", {
  src <- paste(
    readLines(hla_inst_file("shiny/v1.4/hla_tcr_motifs/network_table.R"), warn = FALSE),
    collapse = "\n"
  )
  expect_match(src, "output\\$hla_network_table <- DT::renderDataTable", perl = TRUE)
  expect_match(src, "output\\$hla_network_download <- downloadHandler", perl = TRUE)
  # the download writes the SAME reactive the table renders
  expect_match(src, "downloadHandler\\([\\s\\S]{0,400}hla_network_table_data\\(\\)", perl = TRUE)
})
```

- [ ] **Step 2: Run test to verify it fails**

Run: `Rscript -e 'devtools::test(filter = "hla-app-contract")' 2>&1 | grep -E "renders and downloads|\\[ FAIL"`
Expected: FAIL (render + download outputs not defined yet).

- [ ] **Step 3: Append the render + download to `network_table.R`:**

```r
output$hla_network_table <- DT::renderDataTable({
  df <- hla_network_table_data()
  if (is.null(df)) {
    df <- data.frame(Note = "No rows in the current network scope.")
  }
  DT::datatable(
    df,
    rownames = FALSE,
    filter = "top",
    options = list(pageLength = 25, scrollX = TRUE)
  )
})

output$hla_network_download <- downloadHandler(
  filename = function() {
    paste0("hla_network_", hla_network_table_grain(), ".csv")
  },
  content = function(file) {
    df <- hla_network_table_data()
    if (is.null(df)) {
      df <- data.frame()
    }
    utils::write.csv(df, file, row.names = FALSE, na = "")
  }
)
```

- [ ] **Step 4: Run test to verify it passes + full HLA suite stays green**

Run: `air format inst/shiny/v1.4/hla_tcr_motifs/network_table.R tests/testthat/test-hla-app-contract.R && Rscript -e 'devtools::test(filter = "hla")' 2>&1 | grep -E "\\[ FAIL"`
Expected: `[ FAIL 0 | ... ]` (all `test-hla-*` green).

- [ ] **Step 5: Commit**

```bash
git add inst/shiny/v1.4/hla_tcr_motifs/network_table.R tests/testthat/test-hla-app-contract.R
git commit -m "feat(hla): render + CSV download for network table"
```

---

### Task 4: Live verification (real app)

**Files:** none (verification only). This mirrors the #8 live check.

- [ ] **Step 1: Start the hot-reload app**

```bash
Rscript -e "options(shiny.autoreload=TRUE); shiny::runApp('inst', launch.browser=FALSE, port=6924, host='127.0.0.1')"
```
Wait for `Listening on http://127.0.0.1:6924`.

- [ ] **Step 2: Load the synthetic HLA demo and open the tab**

Navigate to `http://127.0.0.1:6924/?dataset=demo_hla_tcr`, click the "HLA & TCR Motifs" sidebar item, then click the "Network data" sub-tab.

- [ ] **Step 3: Confirm node-count parity with the graph**

In the browser console (or Playwright `browser_evaluate`), with grain = "By motif (node)":
```js
() => {
  const info = document.querySelector('#hla_network_table_info');   // DT "Showing 1 to N of TOTAL"
  return info ? info.textContent : 'no table';
}
```
Expected: the "of N entries" total equals the current graph's node count for the active scope (cross-check against the Motif Network node count / the scope-status line).

- [ ] **Step 4: Switch grain and allele**

Set grain to "By cell" → the row count jumps to the per-cell total (larger). Change the Class I or Class II allele on the Parameters panel → the table's totals change with the new scope (it tracks the live network). Download CSV → the file opens with the shown columns.

- [ ] **Step 5: Stop the app**

```bash
kill %1   # or the recorded PID
```

---

## Self-Review

- **Spec coverage:** new sub-tab (Task 1) ✓; node+cell switchable grain (Tasks 1–2) ✓; DT with search/sort (Task 3, `filter = "top"`) ✓; CSV download of current view (Task 3) ✓; follows current network state via `hla_motif_graph()` / `hla_scoped_segments()` (Task 2) ✓; not bound by render cap (Task 2 test asserts no `HLA_MOTIF_MAX_RENDER`) ✓; empty-scope edge case (Task 3 render + download guard NULL) ✓; column absent → dropped (Task 2 `intersect`) ✓; no core file (all inst/) ✓.
- **Placeholder scan:** none — every code step is complete.
- **Type/name consistency:** `hla_table_grain`, `hla_network_table`, `hla_network_download`, `hla_network_table_data`, `hla_network_table_grain`, `clone_count`, `cluster`, `pair_allele`, `mhc_context`, `samples_all`, `sample_origin` used consistently across UI, server, and tests.

## Notes

- Independent of PR #88; land on its own branch/PR.
- No `R/` ↔ `core/` duplication and no `devtools::document()` — all files are inst/-only module code.

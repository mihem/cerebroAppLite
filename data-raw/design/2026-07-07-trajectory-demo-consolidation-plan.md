# Trajectory Demo Consolidation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Merge the monocle2 trajectory into `demo_full_tcr_bcr.crb`, delete the standalone `demo_trajectory.crb`, add a reproducible build script + provenance docs, and fix two review bugs — addressing PR #69 feedback.

**Architecture:** A `data-raw/` script recomputes a monocle2 DDRTree trajectory on the 915 B cells inside `demo_full_tcr_bcr.crb` and injects it via `addTrajectory()`, so one demo shows TCR + BCR + trajectory. The old 4th demo entry and its `.crb` are removed; tests that assumed "trajectory lives in a separate 4th demo" are repointed (and one whose premise inverts is rewritten). Two Shiny bugs (blank tab on unsupported method; zero-cell `sample()` crash) are fixed.

**Tech Stack:** R, R6 (Cerebro_v1.3), monocle (Bioconductor, monocle2 line — build-time only), Shiny, testthat, shinytest2, air formatter.

---

## File Structure

- `data-raw/build_trajectory_demo.R` — **new**. Reads `demo_full_tcr_bcr.crb`, subsets B cells, runs monocle2 DDRTree, injects trajectory, overwrites the `.crb`. Build-time only; depends on `monocle` (not in DESCRIPTION).
- `data-raw/README.md` — **edit**. Add "Trajectory demo" provenance section.
- `inst/extdata/v1.4/demo_full_tcr_bcr.crb` — **regenerated** (gains a monocle2 trajectory).
- `inst/extdata/v1.4/demo_trajectory.crb` — **deleted**.
- `inst/app.R:31` — **edit**. Drop the 4th demo entry.
- `inst/shiny/v1.4/shiny_server.R:562` — **edit**. Gate tab visibility on supported methods.
- `inst/shiny/v1.4/trajectory/select_method_and_name.R:15-17` — **edit**. Empty-check on the filtered (supported) list.
- `inst/shiny/v1.4/trajectory/projection_plot.R:47` — **edit**. Zero-cell guard + `seq_len`.
- `tests/testthat/test-trajectory.R` — **edit**. Repoint trajectory source to `demo_full_tcr_bcr.crb`.
- `tests/testthat/test-app-trajectory.R` — **rewrite premise**. Trajectory tab now present on the default set.
- `NEWS.md:14` — **edit**. Update changelog.

**Note on TDD here:** the `.crb` rebuild depends on `monocle` (heavy Bioconductor build-time dep) and the bug fixes live in Shiny reactive code — neither is a pure unit under this repo's testthat harness. "Test" therefore means: (a) the existing testthat suite via `scripts/precheck.sh fast`, and (b) in-app Playwright verification. Bug-fix tasks are written test-first where the repo's regex-on-source test style supports it; the build task is verified by asserting on the produced `.crb`.

---

## Task 1: Bug 2 — zero-cell `sample()` crash guard

**Files:**
- Modify: `inst/shiny/v1.4/trajectory/projection_plot.R:47`

The current line `cells_df <- cells_df[sample(1:nrow(cells_df)), ]` breaks when
filters empty `cells_df`: `1:0` is `c(1, 0)`, so `sample` injects an NA row.

- [ ] **Step 1: Read the surrounding block to place the guard correctly**

Run: `sed -n '38,60p' inst/shiny/v1.4/trajectory/projection_plot.R`
Expected: see `cells_df <- cells_df[keep_cells, ]`, then `randomlySubsetCells(...)`, then the `sample(1:nrow(cells_df))` line.

- [ ] **Step 2: Add empty-state guard before the sample line**

Insert immediately after `cells_df <- randomlySubsetCells(...)` returns and before `cells_df <- cells_df[sample(...)]`:

```r
    ## Empty-state guard: if group filters removed every cell, `1:nrow` would be
    ## `1:0` = c(1, 0) and sample() would emit an NA row that crashes the plot.
    if (nrow(cells_df) == 0) {
      return(
        plotly::plotly_empty(type = "scatter", mode = "markers") %>%
          plotly::layout(
            title = list(
              text = "No cells match the current filters.",
              x = 0.5,
              y = 0.5
            )
          )
      )
    }
```

- [ ] **Step 3: Replace `1:nrow` with `seq_len` to kill the degenerate case at the root**

Change:
```r
    cells_df <- cells_df[sample(1:nrow(cells_df)), ]
```
to:
```r
    cells_df <- cells_df[sample(seq_len(nrow(cells_df))), ]
```

- [ ] **Step 4: Verify the file still parses**

Run: `Rscript -e 'invisible(parse("inst/shiny/v1.4/trajectory/projection_plot.R")); cat("OK\n")'`
Expected: `OK`

- [ ] **Step 5: Commit**

```bash
git add inst/shiny/v1.4/trajectory/projection_plot.R
git commit -m "fix(shiny): guard trajectory plot against zero filtered cells"
```

---

## Task 2: Bug 1 — blank tab on unsupported trajectory method

**Files:**
- Modify: `inst/shiny/v1.4/trajectory/select_method_and_name.R:13-17`
- Modify: `inst/shiny/v1.4/shiny_server.R:562`

The UI filters methods to `%in% c('monocle2')` (line 15) but its empty-check
(line 17) tests the **unfiltered** `getMethodsForTrajectories()`, and
`shiny_server.R:562` inserts the tab on the unfiltered list too. A `.crb` whose
only method is unsupported gets a blank tab instead of the "No trajectories"
message.

- [ ] **Step 1: Read both sites**

Run: `sed -n '13,18p' inst/shiny/v1.4/trajectory/select_method_and_name.R && echo '---' && sed -n '562,567p' inst/shiny/v1.4/shiny_server.R`
Expected: see the `available_methods <- available_methods[... %in% c('monocle2')]` filter, the `if (length(getMethodsForTrajectories()) == 0)` check, and the `insertConditionalTab("Trajectory", ..., function() getMethodsForTrajectories())`.

- [ ] **Step 2: Fix the UI empty-check to use the filtered list**

In `select_method_and_name.R`, change:
```r
  available_methods <- available_methods[available_methods %in% c('monocle2')]

  if (length(getMethodsForTrajectories()) == 0) {
```
to:
```r
  available_methods <- available_methods[available_methods %in% c('monocle2')]

  if (length(available_methods) == 0) {
```

- [ ] **Step 3: Fix the tab-visibility condition to only count supported methods**

In `shiny_server.R`, change the `insertConditionalTab` condition:
```r
  insertConditionalTab(
    "Trajectory",
    "trajectory",
    "route",
    function() getMethodsForTrajectories()
  )
```
to:
```r
  insertConditionalTab(
    "Trajectory",
    "trajectory",
    "route",
    ## Only supported methods (monocle2) should surface the tab; an unsupported
    ## method would otherwise render a blank tab instead of the empty state.
    function() intersect(getMethodsForTrajectories(), c("monocle2"))
  )
```

- [ ] **Step 4: Verify both files parse**

Run: `Rscript -e 'invisible(parse("inst/shiny/v1.4/trajectory/select_method_and_name.R")); invisible(parse("inst/shiny/v1.4/shiny_server.R")); cat("OK\n")'`
Expected: `OK`

- [ ] **Step 5: Commit**

```bash
git add inst/shiny/v1.4/trajectory/select_method_and_name.R inst/shiny/v1.4/shiny_server.R
git commit -m "fix(shiny): align trajectory tab visibility with supported methods"
```

---

## Task 3: Build script — recompute trajectory on B cells of full T+B demo

**Files:**
- Create: `data-raw/build_trajectory_demo.R`

This is a data-generation script (build-time). It must be deterministic
(`set.seed(42)`) and depend on `monocle` without touching DESCRIPTION.

- [ ] **Step 1: Write the build script**

```r
#!/usr/bin/env Rscript
#' Recompute a monocle2 pseudotime trajectory on the B cells of the existing
#' `demo_full_tcr_bcr.crb` and inject it, so a SINGLE demo carries TCR + BCR +
#' trajectory. This replaces the former standalone `demo_trajectory.crb`
#' (an opaque binary with no build script).
#'
#' Data source: the trajectory is derived entirely from `demo_full_tcr_bcr.crb`,
#' itself built by `build_ir_demos.R` from the public 10x Genomics dataset
#' `vdj_v1_hs_pbmc3` (Human PBMC, 5' V(D)J) + `example.crb`. No new data is
#' downloaded.
#'
#' NOTE (honest scope): these are peripheral-blood B cells, not a bone-marrow
#' developmental lineage, so the trajectory is ILLUSTRATIVE of the pseudotime
#' feature, not a biological claim about B-cell ontogeny.
#'
#' Pipeline: subset B cells -> monocle2 newCellDataSet -> size factors +
#' dispersions -> ordering filter on high-variance genes -> DDRTree ->
#' orderCells -> addTrajectory("monocle2", "B_cell_maturation", coords+edges).

set.seed(42)

suppressMessages({
  library(cerebroAppLite)
  library(monocle)
  library(Matrix)
})

## ---- Paths (override via env for a tmp dry-run) ---------------------------
crb_path <- Sys.getenv("FULL_CRB", "inst/extdata/v1.4/demo_full_tcr_bcr.crb")

message("Reading ", crb_path)
crb <- readRDS(crb_path)

## ---- Subset B cells --------------------------------------------------------
md <- crb$getMetaData()
stopifnot("cell_type" %in% colnames(md))
b_idx <- which(md$cell_type == "B cells")
message("B cells: ", length(b_idx))
stopifnot(length(b_idx) > 50)

expr <- crb$getExpressionMatrix()          # genes x cells, log-normalized
b_barcodes <- md$cell_barcode[b_idx]
expr_b <- expr[, b_idx, drop = FALSE]

## ---- Build monocle2 CellDataSet -------------------------------------------
pd <- new("AnnotatedDataFrame", data = data.frame(
  cell_barcode = b_barcodes,
  row.names = colnames(expr_b),
  stringsAsFactors = FALSE
))
fd <- new("AnnotatedDataFrame", data = data.frame(
  gene_short_name = rownames(expr_b),
  row.names = rownames(expr_b),
  stringsAsFactors = FALSE
))

cds <- newCellDataSet(
  as(as.matrix(expr_b), "sparseMatrix"),
  phenoData = pd,
  featureData = fd,
  expressionFamily = uninormal()          # data already log-normalized
)

## ---- Order + reduce with DDRTree ------------------------------------------
# Ordering genes: most variable across the B-cell subset.
gene_var <- apply(as.matrix(expr_b), 1, var)
ordering_genes <- names(sort(gene_var, decreasing = TRUE))[seq_len(min(500, length(gene_var)))]
cds <- setOrderingFilter(cds, ordering_genes)

cds <- reduceDimension(
  cds,
  max_components = 2,
  method = "DDRTree",
  norm_method = "none",
  pseudo_expr = 0
)
cds <- orderCells(cds)

## ---- Extract trajectory into Cerebro slot shape ---------------------------
# meta: DR_1, DR_2, pseudotime, state (rownames = cell barcodes)
reduced <- t(reducedDimS(cds))
meta <- data.frame(
  DR_1 = reduced[, 1],
  DR_2 = reduced[, 2],
  pseudotime = pData(cds)$Pseudotime,
  state = as.character(pData(cds)$State),
  row.names = colnames(expr_b),
  stringsAsFactors = FALSE
)

# edges: DDRTree skeleton in the reduced space
dp_mst <- minSpanningTree(cds)
Y <- t(reducedDimK(cds))
edges_list <- igraph::as_edgelist(dp_mst)
edges <- data.frame(
  source = edges_list[, 1],
  target = edges_list[, 2],
  weight = 1,
  source_dim_1 = Y[edges_list[, 1], 1],
  source_dim_2 = Y[edges_list[, 1], 2],
  target_dim_1 = Y[edges_list[, 2], 1],
  target_dim_2 = Y[edges_list[, 2], 2],
  stringsAsFactors = FALSE
)

## ---- Inject + overwrite ----------------------------------------------------
crb$addTrajectory("monocle2", "B_cell_maturation", list(meta = meta, edges = edges))

message("Trajectory methods now: ", paste(crb$getMethodsForTrajectories(), collapse = ", "))
message("Trajectory names: ", paste(crb$getNamesOfTrajectories("monocle2"), collapse = ", "))

saveRDS(crb, crb_path)
message("Wrote ", crb_path)
```

- [ ] **Step 2: Verify the script parses**

Run: `Rscript -e 'invisible(parse("data-raw/build_trajectory_demo.R")); cat("OK\n")'`
Expected: `OK`

- [ ] **Step 3: Run the build (writes to a tmp copy first, to protect the real .crb)**

```bash
cp inst/extdata/v1.4/demo_full_tcr_bcr.crb /tmp/full_dry.crb
FULL_CRB=/tmp/full_dry.crb Rscript data-raw/build_trajectory_demo.R
```
Expected: messages showing `B cells: 915`, `Trajectory methods now: monocle2`, `Trajectory names: B_cell_maturation`, `Wrote /tmp/full_dry.crb`. If `monocle` is not installed, install it (`BiocManager::install("monocle")`) before rerunning — it is a build-time-only dependency.

- [ ] **Step 4: Assert the dry-run .crb has trajectory + still has TCR + BCR**

```bash
Rscript -e '
x <- readRDS("/tmp/full_dry.crb")
stopifnot("monocle2" %in% x$getMethodsForTrajectories())
stopifnot("B_cell_maturation" %in% x$getNamesOfTrajectories("monocle2"))
tj <- x$getTrajectory("monocle2","B_cell_maturation")
stopifnot(all(c("meta","edges") %in% names(tj)))
stopifnot(all(c("DR_1","DR_2","pseudotime","state") %in% colnames(tj$meta)))
stopifnot(!anyNA(tj$meta$pseudotime))
stopifnot(length(x$getTCR()) > 0 || !is.null(x$getTCR()))
stopifnot(length(x$getBCR()) > 0 || !is.null(x$getBCR()))
cat("DRY RUN OK: trajectory + TCR + BCR all present\n")
'
```
Expected: `DRY RUN OK: trajectory + TCR + BCR all present`

- [ ] **Step 5: Run for real (overwrite the shipped .crb)**

```bash
Rscript data-raw/build_trajectory_demo.R
```
Expected: same success messages, `Wrote inst/extdata/v1.4/demo_full_tcr_bcr.crb`.

- [ ] **Step 6: Commit the script + regenerated .crb**

```bash
git add data-raw/build_trajectory_demo.R inst/extdata/v1.4/demo_full_tcr_bcr.crb
git commit -m "feat(data): add monocle2 B-cell trajectory to full T+B demo"
```

---

## Task 4: Delete standalone demo + drop app entry

**Files:**
- Delete: `inst/extdata/v1.4/demo_trajectory.crb`
- Modify: `inst/app.R:28-32`

- [ ] **Step 1: Remove the 4th demo entry from the app**

In `inst/app.R`, change:
```r
  "crb_file_to_load" = c(
    "PBMC - Full (T+B)" = "extdata/v1.4/demo_full_tcr_bcr.crb",
    "PBMC - Healthy (T/NK)" = "extdata/v1.4/demo_healthy_t.crb",
    "PBMC - B-cell rich" = "extdata/v1.4/demo_bcell_rich.crb",
    "PBMC - Monocle2 trajectory" = "extdata/v1.4/demo_trajectory.crb"
  ),
```
to:
```r
  "crb_file_to_load" = c(
    "PBMC - Full (T+B)" = "extdata/v1.4/demo_full_tcr_bcr.crb",
    "PBMC - Healthy (T/NK)" = "extdata/v1.4/demo_healthy_t.crb",
    "PBMC - B-cell rich" = "extdata/v1.4/demo_bcell_rich.crb"
  ),
```

- [ ] **Step 2: Update the comment above the block**

In `inst/app.R`, change the comment (lines ~25-27) from referring to "The Monocle2 set carries trajectory data" to reflect that the full T+B set now carries it. Replace:
```r
  ## The Monocle2 set carries trajectory data, which surfaces the Trajectory
  ## tab (dynamically inserted by insertConditionalTab).
```
with:
```r
  ## The full T+B set additionally carries a monocle2 B-cell trajectory, which
  ## surfaces the Trajectory tab (dynamically inserted by insertConditionalTab).
```

- [ ] **Step 3: Delete the standalone .crb**

```bash
git rm inst/extdata/v1.4/demo_trajectory.crb
```
Expected: `rm 'inst/extdata/v1.4/demo_trajectory.crb'`

- [ ] **Step 4: Verify no remaining code/app references (tests handled in Task 5)**

Run: `grep -rn "demo_trajectory" inst/ --exclude-dir=.git`
Expected: no output.

- [ ] **Step 5: Commit**

```bash
git add inst/app.R
git commit -m "chore(shiny): drop standalone trajectory demo entry"
```

---

## Task 5: Repoint / rewrite tests

**Files:**
- Modify: `tests/testthat/test-trajectory.R:6-9,40,49`
- Modify: `tests/testthat/test-app-trajectory.R` (premise inverts)

`test-trajectory.R` sources the trajectory from `demo_trajectory.crb`; repoint to
`demo_full_tcr_bcr.crb`. `test-app-trajectory.R` asserts the default set has NO
trajectory and the tab appears only after switching — after the merge the
**default set HAS the trajectory**, so that assertion inverts.

- [ ] **Step 1: Repoint the trajectory source in test-trajectory.R**

Change:
```r
trajectory_crb <- system.file(
  "extdata/v1.4/demo_trajectory.crb",
  package = "cerebroAppLite"
)
```
to:
```r
# The full T+B demo now carries the monocle2 B-cell trajectory (the standalone
# demo_trajectory.crb was consolidated into it).
trajectory_crb <- system.file(
  "extdata/v1.4/demo_full_tcr_bcr.crb",
  package = "cerebroAppLite"
)
```

- [ ] **Step 2: Update the two test_that descriptions in test-trajectory.R**

Rename for accuracy (content stays valid — they assert monocle2 + meta/edges):
- `"demo_trajectory.crb trajectory class methods work"` → `"full T+B demo trajectory class methods work"`
- `"demo_trajectory.crb trajectory data is accessible and complete"` → `"full T+B demo trajectory data is accessible and complete"`

Also add an assertion that the demo still carries a specific trajectory name, inside the "complete" test, after the existing `expect_true("state" %in% colnames(traj$meta))`:
```r
  expect_true("B_cell_maturation" %in% crb$getNamesOfTrajectories("monocle2"))
```

- [ ] **Step 3: Rewrite the inverted premise in test-app-trajectory.R**

The comment header (lines 3-6) and `trajectory_crb` (line 23) and the first
`test_that` all assume trajectory lives in a separate 4th demo. Replace the
header comment:
```r
# The bundled app loads four demo data sets; only the fourth
# ("PBMC - Monocle2 trajectory" -> demo_trajectory.crb) carries trajectory
# data, so the Trajectory tab is conditionally inserted only after switching
# to it. The default landing data set (demo_full_tcr_bcr) has no trajectory.
```
with:
```r
# The bundled app loads three demo data sets; the default landing set
# ("PBMC - Full (T+B)" -> demo_full_tcr_bcr.crb) now carries the monocle2
# B-cell trajectory, so the Trajectory tab is present from the start.
```

Remove the now-unused `trajectory_crb <- "extdata/v1.4/demo_trajectory.crb"` line (23).

Rewrite the first test to assert the tab is present on load (no switch needed):
```r
test_that("Trajectory tab is present on the default (full T+B) data set", {
  app <- AppDriver$new(
    inst_dir,
    name = "trajectory_visible",
    height = 950,
    width = 1619,
    load_timeout = 60000
  )
  on.exit(app$stop(), add = TRUE)
  app$wait_for_idle(timeout = 20000)

  # Default data set now carries trajectory data -> tab present immediately.
  tab_present <- app$get_js(
    'document.querySelector(\'a[href="#shiny-tab-trajectory"]\') !== null;'
  )
  expect_true(tab_present)
})
```

- [ ] **Step 4: Verify both test files parse**

Run: `Rscript -e 'invisible(parse("tests/testthat/test-trajectory.R")); invisible(parse("tests/testthat/test-app-trajectory.R")); cat("OK\n")'`
Expected: `OK`

- [ ] **Step 5: Run the fast test suite**

Run: `Rscript -e 'testthat::test_file("tests/testthat/test-trajectory.R")'`
Expected: all tests pass (shinytest2 app tests may be skipped in this invocation; that is fine — they run in CI).

- [ ] **Step 6: Commit**

```bash
git add tests/testthat/test-trajectory.R tests/testthat/test-app-trajectory.R
git commit -m "test: repoint trajectory tests to consolidated full T+B demo"
```

---

## Task 6: Provenance docs + changelog

**Files:**
- Modify: `data-raw/README.md`
- Modify: `NEWS.md:14`

- [ ] **Step 1: Add a "Trajectory demo" section to data-raw/README.md**

Append after the existing IR-demo content:
```markdown
## Trajectory demo (monocle2)

The **`demo_full_tcr_bcr.crb`** demo additionally carries a monocle2 pseudotime
trajectory (`monocle2 / B_cell_maturation`), so a single dataset demonstrates
TCR **and** BCR **and** trajectory — rather than shipping a separate
trajectory-only file.

- **Source:** derived entirely from `demo_full_tcr_bcr.crb` itself (no new
  download). The trajectory is computed on that demo's 915 B cells.
- **Method:** monocle2 `DDRTree` on the most variable genes, `set.seed(42)` for
  reproducibility. See `build_trajectory_demo.R`.
- **Honest scope:** these are peripheral-blood B cells, not a bone-marrow
  developmental lineage — the trajectory is **illustrative** of the pseudotime
  feature, not a biological claim about B-cell ontogeny.

### Rebuild

From the package root, with `cerebroAppLite` and `monocle` (Bioconductor)
installed:

```bash
Rscript data-raw/build_trajectory_demo.R
```

`monocle` is a **build-time-only** dependency (like `scRepertoire` for the IR
demos) and is intentionally not in `DESCRIPTION`.
```

- [ ] **Step 2: Update NEWS.md**

Read the current line: `sed -n '10,18p' NEWS.md`. Replace the bullet about the standalone `demo_trajectory.crb` (line ~14) with a bullet describing the consolidation:
```markdown
- **Demo data**: the monocle2 pseudotime trajectory is now bundled inside the
  `demo_full_tcr_bcr.crb` demo (on its B-cell subset) instead of a separate
  `demo_trajectory.crb`, so one demo shows TCR + BCR + trajectory. The
  trajectory is reproducible via `data-raw/build_trajectory_demo.R`.
```
Adjust wording to match the surrounding NEWS.md formatting/tense.

- [ ] **Step 3: Commit**

```bash
git add data-raw/README.md NEWS.md
git commit -m "docs: document consolidated trajectory demo provenance"
```

---

## Task 7: Full local CI + in-app verification

**Files:** none (verification only)

- [ ] **Step 1: Run the fast precheck (air + testthat)**

Run: `scripts/precheck.sh fast`
Expected: air formats cleanly (may reflow — restage if the pre-commit hook adjusts), testthat green. If air reflows any file touched above, amend the relevant commit.

- [ ] **Step 2: Confirm no dangling references remain anywhere**

Run: `grep -rn "demo_trajectory" . --exclude-dir=.git | grep -v data-raw/design`
Expected: no output.

- [ ] **Step 3: Hot-reload the app and drive the Trajectory tab with Playwright**

Start once (background):
```bash
Rscript -e "options(shiny.autoreload = TRUE); shiny::runApp('inst', launch.browser = FALSE, port = 5919)"
```
Then with Playwright, on the default "PBMC - Full (T+B)" set:
- Confirm the **Trajectory** sidebar tab is present on load.
- Open it; confirm the B-cell trajectory (method `monocle2`, name `B_cell_maturation`) renders with points + DDRTree lines.
- In a group filter, deselect every value; confirm the empty-state message appears and the app does **not** crash (Bug 2 fixed).

- [ ] **Step 4: Final review**

Confirm all commits are present and the working tree is clean:
```bash
git log --oneline -8 && git status --short
```
Expected: the 6 task commits + the spec/plan doc commits; clean tree.

---

## Self-review notes

- **Spec coverage:** build script (Task 3), README provenance (Task 6), fewer datasets / delete standalone (Task 4), Bug 1 (Task 2), Bug 2 (Task 1), dangling refs incl. the non-obvious test inversion (Task 5), verification incl. Playwright (Task 7). All spec sections mapped.
- **Placeholder scan:** no TBD/TODO; every code step shows real code. `monocle` install is the one external prerequisite, called out explicitly in Task 3 Step 3.
- **Type consistency:** trajectory slot shape (`meta` cols DR_1/DR_2/pseudotime/state; `edges` cols source/target/weight/source_dim_1..target_dim_2) matches the verified structure of the existing demo and the `addTrajectory(...)` call. Method name `monocle2` and trajectory name `B_cell_maturation` are consistent across Tasks 3, 5, 6, 7.
- **Ordering note:** bug fixes (Tasks 1-2) come before the data rebuild (Task 3) so each commit is independently valid; the `.crb` delete (Task 4) precedes test repointing (Task 5) so the suite is only run green at the end of Task 5 onward.

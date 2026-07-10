# Trajectory demo — build notes

> Provenance of record (source, acquire command, version, sampling, license, output) lives in [`DATASETS.md`](DATASETS.md). This file covers the trajectory build design and rebuild steps only.

The trajectory demo is **not a separate `.crb`**. A monocle2 pseudotime trajectory is carried **inside** the immune-repertoire demo `demo_full_tcr_bcr.crb`, computed on its B-cell subset, so a single dataset demonstrates TCR **and** BCR **and** trajectory — rather than shipping a standalone trajectory-only file (which the former opaque `demo_trajectory.crb` was, with no build script).

| Carried in | Method | Trajectory name | Cells | Stored fields |
|------------|--------|-----------------|-------|---------------|
| `demo_full_tcr_bcr.crb` | monocle2 `DDRTree` | `B_cell_maturation` | 915 B cells | `DR_1`, `DR_2`, `pseudotime`, `state` |

**Honest scope**: these are peripheral-blood B cells, not a bone-marrow developmental lineage — the trajectory is **illustrative** of the pseudotime feature, not a biological claim about B-cell ontogeny.

## Rebuild

This build is **self-contained**: its input is the already-built IR demo `demo_full_tcr_bcr.crb`, so no new data is downloaded. It needs `monocle` (Bioconductor), a **build-time-only** dependency (like `scRepertoire` for the IR demos) — it is intentionally not a hard runtime dependency.

From the package root, with `cerebroAppLite` and `monocle` installed:

```bash
Rscript data-raw/build_trajectory_demo.R
```

The input/output path is overridable via the `FULL_CRB` env var; the default is `inst/extdata/v1.4/demo_full_tcr_bcr.crb`.

The script (`build_trajectory_demo.R`):

1. Reads `demo_full_tcr_bcr.crb` and subsets its **B cells**.
2. Builds a monocle2 `newCellDataSet`, applies an ordering filter on the high-variance genes, then `DDRTree` → `orderCells` (`set.seed(42)` for reproducibility).
3. Injects the result via `Cerebro_v1.3$addTrajectory("monocle2", "B_cell_maturation", trajectory)`, storing the DDRTree embedding (`DR_1`, `DR_2`), `pseudotime`, and `state` per cell plus the tree edges.

Output overwrites the **trajectory slot inside** `inst/extdata/v1.4/demo_full_tcr_bcr.crb` — no new file is produced.

### Reproducibility note

monocle2 (v2.x) is unmaintained and calls a few igraph functions that are defunct in modern igraph; `build_trajectory_demo.R` applies small, self-contained in-process shims (documented inline) so the DDRTree ordering runs on current toolchains.

## Try it

Load the demo; the conditional **Trajectory** tab appears because the `.crb` carries trajectory data.

```r
library(cerebroAppLite)
createShinyApp(
  cerebro_data = c(
    "PBMC - Full (T+B)" = system.file("extdata/v1.4/demo_full_tcr_bcr.crb", package = "cerebroAppLite")
  )
)
```

The tab colours the projection by monocle2 `state` or continuous `pseudotime`, and shows states-by-group and expression-along-pseudotime views.

# Immune repertoire demos — build notes

> Provenance of record (source, acquire command, version, sampling, license, output) lives in [`DATASETS.md`](DATASETS.md). This file covers the immune-repertoire build design and rebuild steps only.

Three demo `.crb` files shipped in `inst/extdata/v1.4/` for the multi-crb + Immune Repertoire demo:

| File | Sample | Cell composition | Immune repertoire |
|------|--------|------------------|-------------------|
| `demo_full_tcr_bcr.crb` | PBMC - Full (T+B) | all cells (T + B + Mono) | TCR **and** BCR |
| `demo_healthy_t.crb` | PBMC - Healthy (T/NK) | T + Monocytes | TCR only |
| `demo_bcell_rich.crb` | PBMC - B-cell rich | B + a few T cells | BCR only |

These are **genuinely distinct** datasets, not one dataset with three IR variants: each is a different cell subset of `example.crb`, so the UMAP and cell-type composition change when you switch. Clonotypes are assigned **by lineage** — TCR only to T cells, BCR only to B cells — so the repertoire is biologically plausible rather than random noise.

## Rebuild

This is a **two-step** build: the raw VDJ contig CSVs are not committed (only the built `.crb` ship), so download them first, then run the script.
See the `acquire` block for `demo_full_tcr_bcr.crb` in [`DATASETS.md`](DATASETS.md) for the exact `curl` commands.

From the package root, with `cerebroAppLite` and `scRepertoire` (>= 2.0) installed and the CSVs in `data-raw/vdj_10x/`:

```bash
Rscript data-raw/build_ir_demos.R
```

Input/output paths are overridable via env vars (`SRC_CRB`, `T_CSV`, `B_CSV`, `OUT_FULL`, `OUT_HEALTHY`, `OUT_BCELL`); the defaults match the layout above.

The script (`build_ir_demos.R`):

1. `scRepertoire::loadContigs()` + `combineTCR()` / `combineBCR()` turn the 10x contig CSVs into clonotype pools (`CTgene`, `CTnt`, `CTaa`, `CTstrict`).
2. For each demo it takes a **cell subset** of `example.crb` (e.g. T + Mono for the healthy sample) and reconstructs a fresh `Cerebro_v1.3` with the expression matrix, metadata and projections filtered consistently.
3. Clonotypes are assigned **by lineage** (`set.seed` for reproducibility): TCR clonotypes go only to `T cells`, BCR only to `B cells`. The result is written into the `immune_repertoire` slot in the five-column layout (`barcode, CTgene, CTnt, CTaa, CTstrict`) the Shiny app's `immune_repertoire/data.R` expects; the app infers chain type from `CTgene`.
4. A verification pass asserts every TCR barcode lands on a T cell and every BCR barcode on a B cell.

Output overwrites the three `.crb` files in `inst/extdata/v1.4/`.

## Try it

```r
library(cerebroAppLite)
createShinyApp(
  cerebro_data = c(
    "PBMC - Full (T+B)"     = system.file("extdata/v1.4/demo_full_tcr_bcr.crb", package = "cerebroAppLite"),
    "PBMC - Healthy (T/NK)" = system.file("extdata/v1.4/demo_healthy_t.crb",    package = "cerebroAppLite"),
    "PBMC - B-cell rich"    = system.file("extdata/v1.4/demo_bcell_rich.crb",   package = "cerebroAppLite")
  )
)
```

A "Select dataset:" switcher appears in the sidebar; switching changes the UMAP, the cell-type composition and the Immune Repertoire tab.

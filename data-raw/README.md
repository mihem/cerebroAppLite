# data-raw — reproducible demo data

This directory reproducibly rebuilds every demo `.crb` shipped in `inst/extdata/v1.4/`. It is excluded from the built package via `.Rbuildignore`; it stays in the repository for reproducibility only. The built `.crb` files are what ships.

## Where to look

| I want to… | Read |
|------------|------|
| know the exact source / citation / download command / license of a dataset | [`DATASETS.md`](DATASETS.md) — the provenance registry |
| understand or rebuild the **spatial** demos | [`spatial.md`](spatial.md) |
| understand or rebuild the **immune repertoire** demos | [`immune_repertoire.md`](immune_repertoire.md) |
| understand or rebuild the **trajectory** demo | [`trajectory.md`](trajectory.md) |
| add a **new** dataset | copy the template in [`DATASETS.md`](DATASETS.md), then add a build script + a per-type notes file |

`DATASETS.md` is the single source of truth for provenance across all data types. The per-type notes files (`spatial.md`, `immune_repertoire.md`, `trajectory.md`) carry only design and rebuild details and link back to it. This keeps citations in one place and avoids duplicating source info per file.

## Data families

| Family | Datasets | Build script | Runs | Notes |
|--------|----------|--------------|------|-------|
| Immune repertoire | 3 PBMC subsets (TCR/BCR by lineage) | `build_ir_demos.R` | download-then-run (needs the VDJ CSVs first — see acquire in `DATASETS.md`) | [`immune_repertoire.md`](immune_repertoire.md) |
| Spatial | Visium · Slide-seq v2 · MERFISH · Xenium | `build_spatial_demos.R` | self-contained (all sources fetched automatically — R packages for Visium/Slide-seq/MERFISH, auto-`download.file` for Xenium) | [`spatial.md`](spatial.md) |
| Trajectory | monocle2 pseudotime, carried inside `demo_full_tcr_bcr.crb` | `build_trajectory_demo.R` | self-contained (input is the already-built IR demo `.crb`; needs `monocle`) | [`trajectory.md`](trajectory.md) |

**Verification (2026-07-07):** `build_spatial_demos.R` reproduces all four shipped spatial `.crb` (`set.seed(42)` makes it deterministic) and is now **fully self-contained** — the network-sourced demo (Xenium) auto-downloads its raw data on first run via `download.file`, so `Rscript data-raw/build_spatial_demos.R` runs the whole link → `.crb` pipeline from one command. The download is skipped when the file is already present (verified: Xenium skipped its 3.5 GB download when the outs bundle was already unzipped). The three package-sourced builds (Visium, Slide-seq, MERFISH) pull from SeuratData/Bioconductor. `build_ir_demos.R` is still a two-step build: its download URLs are live and its dependencies (`scRepertoire`, `example.crb`) are present, but the VDJ CSVs it consumes are intentionally not committed, so run the acquire `curl` step first.

## Environment of record

The shipped `.crb` files were last built with:

| Component | Version |
|-----------|---------|
| R | 4.5.2 |
| Bioconductor | 3.22 |
| Seurat | 5.4.0 |
| SeuratObject | 5.3.0 |
| SeuratData | 0.2.2.9002 |
| MerfishData | 1.12.0 |
| scRepertoire | ≥ 2.0 |
| monocle | for the trajectory demo (build-time only) |
| RBioFormats | for the Xenium DAPI OME-TIFF (JPEG2000) extraction (pure R, Bioconductor) |

- **One registry.** Every dataset is recorded in `DATASETS.md` with the same fields — no dataset ships without a registry entry.
- **Reproducible acquire.** Each entry gives the exact command to obtain the raw data (a package install + load, or a `curl` from a public URL); raw downloads are not committed, only the built `.crb`.
- **Public, citable sources only.** Every dataset is public reference data with a stated license.
- **Soft-wrapped Markdown.** Prose is one sentence (or clause) per line, no fixed-column hard wrapping — cleaner rendering and smaller diffs. Tables and code blocks are kept literal.

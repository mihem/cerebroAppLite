# Demo dataset registry

Single source of truth for every demo `.crb` shipped in `inst/extdata/v1.4/`.
Whatever the data type — immune repertoire, spatial, trajectory (planned) — each dataset is recorded here with the **same fields** so provenance is complete and reproducible.

`data-raw/` is excluded from the built package via `.Rbuildignore`; it stays in the repo for reproducibility only. The built `.crb` files are what ship.

## Environment of record

The shipped `.crb` files in this repo were last built with:

| Component | Version |
|-----------|---------|
| R | 4.5.2 |
| Bioconductor | 3.22 |
| Seurat | 5.4.0 |
| SeuratObject | 5.3.0 |
| SeuratData | 0.2.2.9002 |
| MerfishData | 1.12.0 |
| scRepertoire | ≥ 2.0 |

## Registry schema

Every entry is one `### <file>.crb` block with exactly these fields.
When adding a dataset (spatial, trajectory, or otherwise), **copy the template and fill every field** — do not leave a field out; write `none`/`n/a` where it does not apply.

| Field | Meaning |
|-------|---------|
| **type** | `immune_repertoire` \| `spatial` \| `trajectory` |
| **technology** | assay/platform (e.g. `10x Visium`, `Slide-seq v2`, `Monocle3`) |
| **dropdown label** | exact string shown in the app's dataset switcher |
| **organism / tissue** | species + tissue of origin |
| **source** | citation + the exact package/accession that distributes it |
| **acquire** | the exact command(s) to obtain the raw data |
| **object type** | class of the loaded object (e.g. Seurat v5 `VisiumV2`, `SpatialExperiment`) |
| **sampling** | how the shipped subset was derived (cells, genes, seed) |
| **cell-type field** | metadata column used for grouping/colouring |
| **embedded image** | real histology image stored in the `.crb`, or `none` (+ why) |
| **license** | data license / usage terms |
| **build** | the script + function that produces the `.crb` |
| **output** | shipped path + approx size |

### Template (copy for new datasets)

```
### demo_<type>_<name>.crb
- **type**:
- **technology**:
- **dropdown label**:
- **organism / tissue**:
- **source**:
- **acquire**:
- **object type**:
- **sampling**:
- **cell-type field**:
- **embedded image**:
- **license**:
- **build**: `data-raw/<script>.R` → `<function>()`
- **output**: `inst/extdata/v1.4/demo_<type>_<name>.crb` (~X MB)
```

---

## Spatial

Real, measured, down-sampled public data — one dataset per technology.
All flow through the same platform-agnostic extractor `.getSpatialData()` (`R/seurat_utils.R`); there is no per-platform loader.
Built by `data-raw/build_spatial_demos.R` (see [`spatial.md`](spatial.md) for design notes).

### demo_spatial_visium.crb
- **type**: spatial
- **technology**: 10x Visium (spot, 55 µm)
- **dropdown label**: `Mouse brain (Visium)`
- **organism / tissue**: mouse (mm) / brain, sagittal anterior section
- **source**: 10x Genomics Visium Mouse Brain (Sagittal Anterior), distributed by the `stxBrain.SeuratData` package.
- **acquire**:
  ```r
  install.packages("SeuratData")   # or remotes::install_github("satijalab/seurat-data")
  SeuratData::InstallData("stxBrain")
  obj <- SeuratData::LoadData("stxBrain", type = "anterior1")
  ```
- **object type**: Seurat v5, image class `VisiumV2` (auto-upgraded on load)
- **sampling**: `set.seed(42)`; ≤ 5,000 spots stratified by Louvain cluster (here 2,696 spots, the full anterior1 section); expression trimmed to 1,200 genes (variable features + top-expressed) to keep the `.crb` small.
- **cell-type field**: `cluster` (Louvain, `FindClusters(resolution = 0.5)`, since the source ships no cell-type labels)
- **embedded image**: **none — uses an EXTERNAL image instead.** The real low-res H&E (`slot(image, "image")`, 599×600×3) is written to a standalone PNG, `inst/extdata/v1.4/demo_spatial_visium_he.png`, and loaded via `spatial_images` in `inst/app.R` rather than embedded in the `.crb`. This is the deliberate live example of the external-image path (the other image demos embed); it also keeps the Visium `.crb` smaller. Displayed with `spatial_images_flip_y = TRUE` (ground-truth verified against Seurat's `SpatialPlot`).
- **license**: 10x Genomics public dataset terms (freely redistributable).
- **build**: `data-raw/build_spatial_demos.R` → `build_visium()` (writes both the `.crb` and `demo_spatial_visium_he.png`)
- **output**: `inst/extdata/v1.4/demo_spatial_visium.crb` (~6.1 MB) + `demo_spatial_visium_he.png` (~0.5 MB)

### demo_spatial_slideseq.crb
- **type**: spatial
- **technology**: Slide-seq v2 (bead, 10 µm)
- **dropdown label**: `Mouse hippocampus (Slide-seq v2)`
- **organism / tissue**: mouse (mm) / hippocampus
- **source**: Stickels et al. 2021 (Slide-seqV2 mouse hippocampus), distributed by the `ssHippo.SeuratData` package.
- **acquire**:
  ```r
  SeuratData::InstallData("ssHippo")
  data("ssHippo", package = "ssHippo.SeuratData")
  obj <- SeuratObject::UpdateSeuratObject(get("ssHippo"))
  ```
- **object type**: Seurat **v4-era** object, image class `SlideSeq`. `ssHippo` ships as a v3.1.4 object whose `SlideSeq` image predates the current class (missing the `misc` slot), so `UpdateSeuratObject()` is required before any `subset`/`validObject`. This dataset is the end-to-end proof that `exportFromSeurat` handles non-v5 spatial objects.
- **sampling**: `set.seed(42)`; 5,000 beads sampled from ~53,173; no gene trim needed at that cell count.
- **cell-type field**: `cluster` (Louvain; the source ships no cell-type labels)
- **embedded image**: **none — and this is correct, not an omission.** The `SlideSeq` S4 class has only a `coordinates` slot; it structurally carries no tissue raster (unlike `VisiumV2`/`FOV`). Slide-seq images beads to recover positions but the public object stores only bead coordinates, no H&E/DAPI photo. The scatter of beads is therefore the complete spatial view.
- **license**: distributed under the SeuratData terms; original data CC-BY (Broad Institute / Macosko lab).
- **build**: `data-raw/build_spatial_demos.R` → `build_slideseq()`
- **output**: `inst/extdata/v1.4/demo_spatial_slideseq.crb` (~1.6 MB)

### demo_spatial_merfish.crb
- **type**: spatial
- **technology**: MERFISH (single-cell imaging)
- **dropdown label**: `Mouse ileum (MERFISH)`
- **organism / tissue**: mouse (mm) / ileum (small intestine)
- **source**: Petukhov et al. 2021 (mouse ileum MERFISH), distributed by the Bioconductor `MerfishData` package (ExperimentHub-backed). Chosen over the Moffitt 2018 hypothalamus set because it ships a genuine DAPI tissue mosaic, and its cells are already in DAPI pixel coordinates (near-1:1 image alignment).
- **acquire**:
  ```r
  BiocManager::install("MerfishData")
  spe <- MerfishData::MouseIleumPetukhov2021()   # SpatialExperiment, 241 genes × 5,800 cells
  ```
- **object type**: `SpatialExperiment` (converted to a Seurat `FOV`+`Centroids` object at build time so extraction runs via `GetTissueCoordinates`, exactly as `LoadVizgen`/`LoadXenium` would). The SPE ships with **no cell names**, so the builder mints stable `cell%05d` ids and applies them to matrix/metadata/coords.
- **sampling**: `set.seed(42)`; cells with `leiden_final == "Removed"` dropped, then ≤ 5,000 stratified by cell type (here 5,000 of 5,800); 241-gene panel kept whole.
- **cell-type field**: `cell_type` (from the source's `leiden_final` labels: Enterocyte tiers, Goblet, Paneth, Smooth Muscle, Myenteric Plexus, ICC, Telocyte, Stromal, Endothelial, immune subsets, …)
- **embedded image**: **real DAPI mosaic** (`imgRaster(getImg(spe, "dapi"))`, 9392×5721), stored as `histology_image` with `histology_image_bounds = [0, W] × [0, H]` (cells already sit in DAPI pixel space). **Vertically flipped on encode** (`flip_y = TRUE`): `imgRaster` returns rows in the opposite order to the cell-coordinate y (verified by the brightness test in spatial.md — this is the opposite of Xenium, which is not flipped).
- **license**: Bioconductor `MerfishData` / original Petukhov et al. terms (public reference data).
- **build**: `data-raw/build_spatial_demos.R` → `build_merfish()`
- **output**: `inst/extdata/v1.4/demo_spatial_merfish.crb` (~2.0 MB)

### demo_spatial_xenium.crb
- **type**: spatial
- **technology**: 10x Xenium (in-situ single-cell imaging)
- **dropdown label**: `Mouse brain (Xenium)`
- **organism / tissue**: mouse (mm) / brain, coronal section — cortex + hippocampus (CTX+HP)
- **source**: 10x Genomics public Xenium demo `Xenium_V1_FF_Mouse_Brain_Coronal_Subset_CTX_HP` (a real tissue sub-section of the Fresh Frozen Mouse Brain coronal dataset, 248-gene Mouse Brain panel). Chosen over the "human breast 2fov" set because it is a genuine tissue section with recognisable brain structure (visible cortical layers and hippocampus), not a rectangular field-of-view crop.
- **acquire**: `build_xenium()` performs this automatically on first run (skipped if already present); the manual equivalent is:
  ```bash
  mkdir -p data-raw/xenium
  BASE=https://cf.10xgenomics.com/samples/xenium/1.0.2/Xenium_V1_FF_Mouse_Brain_Coronal_Subset_CTX_HP
  curl -fL -o data-raw/xenium/brain.zip \
    "$BASE/Xenium_V1_FF_Mouse_Brain_Coronal_Subset_CTX_HP_outs.zip"
  unzip -oq data-raw/xenium/brain.zip -d data-raw/xenium/brain
  ```
- **object type**: raw 10x Xenium outs (`cell_feature_matrix.h5` + `cells.csv.gz` + `morphology_focus.ome.tif`), assembled into a Seurat `FOV`+`Centroids` object at build time. `LoadXenium` is not used: the public bundle ships the `.h5` matrix (not the mtx directory `LoadXenium` expects) and stores transcripts as `.parquet` (needs `arrow`); reading the matrix + `cells.csv.gz` directly is smaller and dependency-free.
- **sampling**: `set.seed(42)`; ≤ 5,000 cells stratified by Louvain cluster (here 5,000 of 36,602); 248-gene brain panel kept whole.
- **cell-type field**: `cluster` (Louvain; the source ships no cell-type labels)
- **embedded image**: **real DAPI morphology** (first channel of `morphology_focus.ome.tif`, contrast-stretched to a greyscale PNG), stored as `histology_image` with `histology_image_bounds = [0, W·px] × [0, H·px]` where `px = pixel_size` (0.2125 µm/px from `experiment.xenium`) converts the full-resolution pixel raster into the micron coordinate space `GetTissueCoordinates` reports. The OME-TIFF is JPEG2000-compressed, which R's `tiff`/`EBImage` cannot decode, so it is read with the Bioconductor package `RBioFormats` (a pure-R wrapper over the Java Bio-Formats library, no Python); if `RBioFormats` is missing, the demo ships coordinates without the image. **Not vertically flipped** — the RBioFormats raster and the cell centroids share the same top-down frame (verified by the brightness test, see spatial.md); this is the opposite of MERFISH.
- **license**: 10x Genomics public dataset terms (freely redistributable).
- **build**: `data-raw/build_spatial_demos.R` → `build_xenium()`
- **output**: `inst/extdata/v1.4/demo_spatial_xenium.crb` (~3.4 MB)

### demo_spatial_slidetags.crb
- **type**: spatial
- **technology**: Slide-tags (spatial-barcoded single-nucleus)
- **dropdown label**: `Human cortex (Slide-tags)`
- **organism / tissue**: human (hg) / prefrontal cortex
- **source**: Russell et al. 2024 (Slide-tags, *Nature*) human prefrontal cortex, via the Open Problems processed mirror on Zenodo (AnnData `.h5ad`, cortex sample).
- **acquire**: `build_slidetags()` performs this automatically on first run (skipped if already present); the manual equivalent is:
  ```bash
  mkdir -p data-raw/slidetags
  curl -fL -o data-raw/slidetags/slidetags_cortex.h5ad \
    "https://openproblems-data.s3.amazonaws.com/resources/datasets/zenodo_spatial_slidetags/slidetags/human_cortex/dataset.h5ad"
  ```
- **object type**: AnnData `.h5ad` (4,065 nuclei × 18,570 genes), parsed straight into a Seurat `FOV`+`Centroids` object with `hdf5r` (CSC `layers/counts` transposed to genes × cells, `obsm/spatial` coordinates, `obs/cell_type` categories) — no `anndata`/`zellkonverter` dependency.
- **sampling**: `set.seed(42)`; all 4,065 nuclei kept; expression trimmed to 2,000 genes (variable + top-expressed) to keep the `.crb` small.
- **cell-type field**: `cell_type` (7 cortical classes: Excitatory, Inhibitory, Astrocyte, Microglia, Endothelial, OPC, …)
- **embedded image**: **none — and this is correct, not an omission.** Slide-tags barcodes single nuclei with spatial DNA tags, then runs standard droplet snRNA-seq; the spatial signal is a coordinate pair per nucleus (`obsm/spatial`), not a tissue photo. Like Slide-seq, the nucleus scatter *is* the complete spatial view.
- **license**: Zenodo record under the Open Problems terms; original data from Russell et al. 2024 (public reference data).
- **build**: `data-raw/build_spatial_demos.R` → `build_slidetags()`
- **output**: `inst/extdata/v1.4/demo_spatial_slidetags.crb` (~6.7 MB)

### Spatial — evaluated, not yet shipped

These platforms were evaluated for a demo but are not shipped this round; the acquire path is recorded so the demo can be added later without re-researching sources.

**Stereo-seq (BGI STOmics).** Chip-capture spatial transcriptomics at sub-micron resolution.
The raw format is a `.gef`/`.gem` file that has no native R reader; the reference toolchain is the Python package `stereopy`, which reads the `.gef` and can export to AnnData (`.h5ad`) for the same `hdf5r` route Slide-tags uses.
Public data (mouse embryo / brain) lives at the STOmics MOSTA portal.
- **acquire** (two-step: needs Python + `stereopy`):
  ```bash
  # 1. download a .gef from the MOSTA portal, e.g. a mouse brain / embryo section:
  #    https://db.cngb.org/stomics/mosta/
  # 2. convert to .h5ad with stereopy (Python):
  python -c "import stereo as st; \
    data = st.io.read_gef('SECTION.cellbin.gef', bin_type='cell_bins'); \
    st.io.stereo_to_anndata(data, flavor='seurat', output='stereoseq.h5ad')"
  ```
  Then a `build_stereoseq()` twin of `build_slidetags()` would parse `stereoseq.h5ad` with `hdf5r`. Not built here because `stereopy` is a Python-only dependency not present in the build environment; documented so it is a drop-in when that environment is available.

---

## Immune repertoire

Three distinct cell subsets of `example.crb`, each with lineage-constrained clonotypes.
Built by `data-raw/build_ir_demos.R` (see [`immune_repertoire.md`](immune_repertoire.md)).

### demo_full_tcr_bcr.crb / demo_healthy_t.crb / demo_bcell_rich.crb
- **type**: immune_repertoire
- **technology**: 10x Chromium 5' V(D)J (scRNA-seq + TCR/BCR)
- **dropdown label**: `PBMC - Full (T+B)` / `PBMC - Healthy (T/NK)` / `PBMC - B-cell rich`
- **organism / tissue**: human (hg) / PBMC, healthy donor
- **source**: 10x Genomics public dataset `vdj_v1_hs_pbmc3` (Human PBMC, Chromium 5' V(D)J, Cell Ranger 3.1.0).
- **acquire**:
  ```bash
  mkdir -p data-raw/vdj_10x
  BASE=https://cf.10xgenomics.com/samples/cell-vdj/3.1.0/vdj_v1_hs_pbmc3
  curl -fL -o data-raw/vdj_10x/pbmc3_t_contig.csv \
    "$BASE/vdj_v1_hs_pbmc3_t_filtered_contig_annotations.csv"
  curl -fL -o data-raw/vdj_10x/pbmc3_b_contig.csv \
    "$BASE/vdj_v1_hs_pbmc3_b_filtered_contig_annotations.csv"
  ```
- **object type**: `Cerebro_v1.3` cell subsets of `example.crb`
- **sampling**: `set.seed()`-pinned cell subsets (T+Mono, T+NK, B+few-T); TCR clonotypes assigned only to T cells, BCR only to B cells.
- **cell-type field**: existing `cell_type` from `example.crb`
- **embedded image**: none (n/a for immune repertoire)
- **license**: 10x Genomics public dataset terms
- **build**: `data-raw/build_ir_demos.R`
- **output**: three `.crb` in `inst/extdata/v1.4/` (~0.4–1.0 MB each)

---

## Trajectory (planned)

_Not built yet._
When trajectory demo data is prepared it will be recorded here using the same schema (one `### demo_trajectory_<name>.crb` block per dataset), built by a future `data-raw/build_trajectory_demos.R`, and stored via the `Cerebro_v1.3$addTrajectory(method, trajectory_name, trajectory)` method.
Fill **source / acquire / object type / sampling / license / build / output** exactly as above so trajectory provenance is as complete as spatial's.

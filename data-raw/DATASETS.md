# Demo dataset registry

Single source of truth for every demo `.crb` shipped in `inst/extdata/v1.4/`.
Whatever the data type — immune repertoire, spatial, trajectory — each dataset is recorded here with the **same fields** so provenance is complete and reproducible.

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
| **type** | `immune_repertoire` \| `spatial` \| `trajectory` \| `trekker` |
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

### Spatial — evaluated, not yet shipped

These platforms were evaluated for a demo but are not shipped this round; the acquire path is recorded so the demo can be added later without re-researching sources.

**Slide-tags (spatial-barcoded single-nucleus).** Russell et al. 2024 (*Nature*) human prefrontal cortex, via the Open Problems Zenodo mirror as an AnnData `.h5ad`.
Not shipped: it carries no tissue image (coordinates only), so it duplicates the Slide-seq demo's role (image-free bead/nucleus scatter) while costing an ~80 MB `.h5ad` download.
- **acquire**:
  ```bash
  mkdir -p data-raw/slidetags
  curl -fL -o data-raw/slidetags/slidetags_cortex.h5ad \
    "https://openproblems-data.s3.amazonaws.com/resources/datasets/zenodo_spatial_slidetags/slidetags/human_cortex/dataset.h5ad"
  ```
  The `.h5ad` parses straight into a Seurat `FOV`+`Centroids` object with `hdf5r` (CSC `layers/counts`, `obsm/spatial`, `obs/cell_type`) — no `anndata`/`zellkonverter` dependency.

**Stereo-seq (BGI STOmics).** Chip-capture spatial transcriptomics at sub-micron resolution.
The raw format is a `.gef`/`.gem` file that has no native R reader; the reference toolchain is the Python package `stereopy`, which reads the `.gef` and can export to AnnData (`.h5ad`) for the same `hdf5r` route Slide-tags would use.
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
  Then a `build_stereoseq()` would parse `stereoseq.h5ad` with `hdf5r`. Not built here because `stereopy` is a Python-only dependency not present in the build environment; documented so it is a drop-in when that environment is available.

---

## Immune repertoire

A cell subset of `example.crb` with lineage-constrained clonotypes.
Built by `data-raw/build_ir_demos.R` (see [`immune_repertoire.md`](immune_repertoire.md)).

### demo_full_tcr_bcr.crb
- **type**: immune_repertoire
- **technology**: 10x Chromium 5' V(D)J (scRNA-seq + TCR/BCR)
- **dropdown label**: `PBMC - Full (T+B)`
- **organism / tissue**: human (hg) / PBMC, healthy donor
- **source**: 10x Genomics public dataset `vdj_v1_hs_pbmc3` (Human PBMC, Chromium 5' V(D)J, Cell Ranger 3.1.0).
- **acquire**:
  ```bash
  mkdir -p data-raw/vdj_10x
  BASE=https://cf.10xgenomics.com/samples/cell-vdj/3.1.0/vdj_v1_hs_pbmc3
  curl -fL -o data-raw/vdj_10x_dextramer/pbmc3_t_contig.csv \
    "$BASE/vdj_v1_hs_pbmc3_t_filtered_contig_annotations.csv"
  curl -fL -o data-raw/vdj_10x_dextramer/pbmc3_b_contig.csv \
    "$BASE/vdj_v1_hs_pbmc3_b_filtered_contig_annotations.csv"
  ```
- **object type**: `Cerebro_v1.3` cell subset of `example.crb` (T + B + Mono, 1,476 cells)
- **sampling**: `set.seed()`-pinned cell subset; TCR clonotypes assigned only to T cells, BCR only to B cells.
- **cell-type field**: existing `cell_type` from `example.crb`
- **embedded image**: none (n/a for immune repertoire)
- **license**: 10x Genomics public dataset terms
- **build**: `data-raw/build_ir_demos.R` (also carries the monocle2 trajectory — see the Trajectory section)
- **output**: `inst/extdata/v1.4/demo_full_tcr_bcr.crb` (~1.0 MB)

> `build_ir_demos.R` can also emit two narrower subsets — `demo_healthy_t.crb` (T + Mono, TCR only) and `demo_bcell_rich.crb` (B + few T, BCR only) — as a multi-sample switcher demo. They are **not shipped** by default; the Full set is their superset.

### demo_hla_tcr_synthetic.crb
- **type**: immune_repertoire
- **technology**: none — **fully synthetic**; simulates a 5' V(D)J + scRNA-seq cohort, measures nothing
- **dropdown label**: `HLA & TCR - SYNTHETIC fixture (fabricated, not measurement)`
- **organism / tissue**: human gene symbols / notional PBMC T-cell cohort. No organism was sampled.
- **source**: **no source — every value is fabricated** by `data-raw/build_hla_tcr_demo.R`. Reused as vocabulary only, not as measurement: gene symbols (from `demo_full_tcr_bcr.crb`, so the Gene expression tab is searchable), IMGT V/J gene names, and European HLA allele frequency ranges.
- **acquire**: none — no download; the generator is self-contained.
- **object type**: `Cerebro_v1.3`, built from the current generator (`hla_typing` slot + methods present).
- **sampling**: **30 donors × 167 cells = 5,010 cells**, `set.seed(20260715)`. Composition: CD8 T 2,000 / CD4 T 1,750 / Treg 500 / B 500 / Monocytes 260; only T cells carry a receptor (TRB in 95%, TRA in 90%). Measured with the package's own motif core: **TRB 2,913 unique CDR3 → 440 nodes in 20 motifs (sizes 5–64, diameter 3–6)**; TRA 3,330 → 184 nodes in 10 motifs. ~1,200 genes.
- **why synthetic**: the predecessor carried REAL CDR3s and rendered a **4-node** network (TRB: 456 unique CDR3 → 2 Hamming-1 pairs; TRA: 395 → 32 pairs). That is not a sample-size accident — an unselected polyclonal repertoire is sparse in CDR3 space, pair count grows ~n², and 5,000 cells only extrapolates to ~150 pairs. Dense motif networks in real data come from **selection** (public/antigen-conditioned receptors converge), not scale, so the families here are designed in: a branching walk in sequence space, one V/J per family, verified isolated at Hamming ≥ 2 from every other family and from the ~2,470 background singletons.
- **HLA design**: 30 synthetic genotypes over HLA-A/B/C/DRB1 only (the loci `HLA_MVP_LOCI` enforces). Carrier counts for anchor alleles are fixed, not drawn, so the allele picker opens on **HLA-A*02:01 — 15 carrier / 15 non-carrier**. Families are tiered: 6 **strong** (members appear only in carriers ⇒ solid "Carrier" islands), 8 **weak** (carrier-enriched, leaks ⇒ Carrier + Mixed), 6 **none** (random donors ⇒ Mixed). The four largest families are concentrated on `HLA-A*02:01`, because one strong family per allele lights a single island and washes the rest to "Mixed". Class I anchors live in CD8 T, class II in CD4 T / Treg, so lineage MHC context stays coherent.
- **cell-type field**: `cell_type_fine` (CD8 T / CD4 T / Treg / B cells / Monocytes); coarse `cell_type` also kept.
- **embedded image**: none (n/a for immune repertoire)
- **HLA typing**: **synthetic** (`source_type = "synthetic"`).
- **declared contracts**: `observation_unit = "cell"`, `receptor_key = "v_gene+cdr3"`, `tcr_selection = "synthetic"` — the page's hardest disclosure. It is strictly stronger than the bulk demo's `association-conditioned`: a positive control has real sequences and real genotypes and only its *selection* is circular, whereas here the sequences AND the association are constructed. Any carrier/non-carrier contrast this data set shows was put there on purpose and is not evidence.
- **license**: none applicable — no third-party data is embedded.
- **build**: `data-raw/build_hla_tcr_demo.R` (self-verifying: it asserts the recovered motif sizes match the design exactly, that the allele picker opens on the anchor, and that whole islands score "Carrier" — a build that drifts fails rather than shipping)
- **output**: `inst/extdata/v1.4/demo_hla_tcr_synthetic.crb` (~4.0 MB)

### demo_hla_tcr_bulk.crb
- **type**: immune_repertoire
- **technology**: bulk TCR-beta immunosequencing (Adaptive immunoSEQ). **Not single cell** — see *sampling*.
- **dropdown label**: `HLA & TCR - real bulk TCRb + real donor HLA`
- **organism / tissue**: human (hg) / peripheral blood, 666-donor cohort
- **source**: Emerson et al., *Nat Genet* 2017 (cohort + HLA typing), as cleaned and published by DeWitt et al., *eLife* 2018. Distributed as `pubtcrs_data_v1.tgz` on Zenodo record [1248193](https://zenodo.org/records/1248193). Tools: [phbradley/pubtcrs](https://github.com/phbradley/pubtcrs).
- **acquire**: the build script downloads it on demand; or manually:
  ```bash
  mkdir -p data-raw/pubtcrs
  curl -fL -o data-raw/pubtcrs/pubtcrs_data_v1.tgz \
    "https://zenodo.org/api/records/1248193/files/pubtcrs_data_v1.tgz/content"
  tar xzf data-raw/pubtcrs/pubtcrs_data_v1.tgz -C data-raw/pubtcrs
  ```
  The 349 MB archive is **not tracked** (`.gitignore`); only the built `.crb` ships.
- **object type**: `Cerebro_v1.3` built from scratch (no source `.crb`).
- **sampling**: **everything is real measured data; nothing is synthesised.** TCRs are the paper's real HLA-associated public TCR-beta chains (V family + CDR3 aa) for six single alleles (`HLA-A*02:01`, `A*01:01`, `B*07:02`, `B*08:01`, `DRB1*04:01`, `DRB1*07:01`); donor↔TCR linkage is the real observed occurrence pattern; HLA is each donor's real genotype. Donors: the first 100 by donor index among those with HLA typing that carry ≥ 1 demo TCR (deterministic, *not* chosen to flatter any association). Restricted to single alleles because the canonical HLA table stores one allele per locus × copy, so the source's DR/DQ haplotype triples and DQ/DP α-β pairs cannot be represented.
- **⚠️ association-conditioned (positive control, NOT independent evidence)**: the receptor set was chosen **using** the published HLA association, and donors were then kept only if they carry one of those receptors. **Any carrier / non-carrier contrast the page shows is put there by that selection**, and re-computing overlap on the same cohort the association was derived from is not independent replication. This is a positive control for the workflow. The `.crb` declares it in `technical_info$tcr_selection = "association-conditioned"`, and the app surfaces it as a warning above the Associations tables. The paper's p/q values are **not** stored in the `.crb` — only the TCRs that its association selected.
- **receptor key**: this source identifies a receptor by (V family, CDR3), not CDR3 alone — 22 of its CDR3s occur on more than one V family. Declared as `technical_info$receptor_key = "v_gene+cdr3"`, which makes split-by-V the app's default so nodes match the source's own receptor identity.
- **statistical unit**: one donor = one sample, and `donor_id` is written into the canonical HLA long table, so the app counts at **donor** level. (Passing a named list instead would silently leave `donor_id` NA and demote counting to sample level.)
- **observation unit**: declared as `technical_info$observation_unit = "analysis unit"`, read app-wide (see `getObservationUnit()`), so the front page reports `21,119 Analysis units` rather than claiming cells that were never sequenced. A data set that declares nothing is treated as single-cell, which is correct for every other `.crb`.
- **absent tabs**: with no projection and no genes, the Projection and Gene expression tabs are not offered for this data set (same conditional mechanism as Marker genes / Spatial / Trajectory) instead of opening blank.
- **bulk → `.crb` mapping**: each row is one **(donor, TCR clonotype) analysis unit, not a sequenced cell**. Consequences, all intended: **no expression matrix** (a real 0-gene × N-unit matrix — bulk measures no transcriptome) and **no projection**, so the Projection / Gene expression tabs have nothing to show for this data set; `cell_type` is `T cell (bulk TCRb)` for every row, so the lineage MHC context is **Unknown by design** — this assay cannot distinguish CD4 from CD8 and the page must not pretend otherwise; `sample` = `donor_id` = the donor, which is the correct unit for HLA carrier counts.
- **cell-type field**: `cell_type` (single level, `T cell (bulk TCRb)`)
- **embedded image**: none (n/a)
- **HLA typing**: **real**, stored with `source_type = "genotyped"` in the `hla_typing` slot. This is the demo that exercises HLA Associations on genuine donor genotypes; `demo_hla_tcr_synthetic.crb` is its single-cell counterpart with synthetic HLA.
- **license**: CC-BY 4.0 (Zenodo record 1248193)
- **build**: `data-raw/build_hla_tcr_bulk_demo.R` (caches the 11M-line occurrence scan to `data-raw/pubtcrs/tcr_donors_cache.rds`)
- **output**: `inst/extdata/v1.4/demo_hla_tcr_bulk.crb`

### demo_hla_tcr_dextramer.crb
- **type**: immune_repertoire
- **technology**: 10x Genomics 5′ Single Cell Immune Profiling — paired αβ V(D)J + 3′ gene expression + TotalSeq-C surface protein + dCODE pMHC dextramers. **Real single cells.**
- **dropdown label**: `HLA & TCR - real single cells, antigen-selected`
- **organism / tissue**: human (hg) / peripheral blood CD8+ T cells, four healthy donors
- **source**: 10x Genomics, *CD8+ T cells of Healthy Donor 1–4* (2019), published as Zhang W *et al.*, **Sci Adv** 7(20):eabf5835 (2021), doi:10.1126/sciadv.abf5835.
- **acquire**: the build script downloads on demand (~1.6 GB, cached in `data-raw/vdj_10x_dextramer/`, gitignored); or manually, per donor `d` in 1..4:
  ```bash
  base=https://cf.10xgenomics.com/samples/cell-vdj/3.0.2
  stem=vdj_v1_hs_aggregated_donor${d}
  curl -fL -O ${base}/${stem}/${stem}_all_contig_annotations.csv
  curl -fL -O ${base}/${stem}/${stem}_binarized_matrix.csv
  curl -fL -O ${base}/${stem}/${stem}_filtered_feature_bc_matrix.tar.gz
  ```
- **object type**: `Cerebro_v1.3` built from scratch (Seurat used only for normalisation/PCA/UMAP).
- **sampling**: **everything is real measured data.** Cells are kept only if they carry a productive αβ clonotype **and** bound exactly **one** dextramer (multi-binders are dropped, not guessed at). Deterministically subsampled to **3,000 cells per donor = 12,000 cells**, `set.seed(20260721)`; matrix cut to the 2,000 most variable genes. Measured with the package's own motif core on the shipped object: **TRB 3,350 unique CDR3 → 157 nodes in 31 motifs; TRA 3,067 → 367 nodes in 130 motifs**.
- **why this data set exists**: it answers the fair objection that the motif network is only legible on synthetic data. A CDR3 Hamming-1 network needs an **antigen-selected** repertoire; an unselected one is sparse in CDR3 space and no amount of cells fixes it. Measured on this same source: all cells unselected = 26,449 unique CDR3 → trips the size guard; dextramer-binding cells = 2,910 → 308 nodes in 75 motifs; the single Flu-MP `GILGFVFTL` epitope = 267 → **121 nodes in 7 motifs**, i.e. 45 % of the CDR3s against one immunodominant epitope collapse into seven families. That is measured convergence, not a designed fixture.
- **cell-type field**: `cell_type` (single level, `CD8 T` — the cells were sorted CD8+). Declared via `technical_info$lineage_column`, so the app never has to infer it.
- **embedded image**: none (n/a for immune repertoire)
- **HLA typing**: ⚠️ **inferred, `source_type = "imputed"`.** The published haplotypes are in table S1, served from `advances.sciencemag.org` — a domain retired when Science migrated to science.org, so the supplement is no longer retrievable. Each donor's alleles are therefore inferred from which dextramers their cells bound: an allele counts when it accounts for ≥ 200 **and** ≥ 10 % of that donor's single-specificity cells. The relative cut matters — donor2 has 814 cells against A\*11:01, which clears any sensible count threshold and is still only 2 % of its specific cells (cross-reactivity, not a genotype). The result reproduces the per-donor allele profile of the paper's own quality-controlled call set (data file S1) exactly: d1 A\*02:01/A\*03:01/A\*11:01 · d2 A\*02:01/A\*03:01/B\*08:01 · d3 A\*03:01 · d4 A\*03:01/A\*11:01.
- **⚠️ circular by construction (NOT independent evidence)**: a donor is called a carrier of HLA-X *because their cells bound an X-restricted dextramer*, and the motif families are built from those same cells. Any carrier / non-carrier contrast this data set shows is therefore guaranteed and is not evidence of an HLA association. Declared in `technical_info$tcr_selection = "antigen-selected"` with the detail spelled out, which the app prints above the Associations tables. **Use `demo_hla_tcr_bulk.crb` for association work on genuine genotypes.**
- **declared contracts**: `observation_unit = "cell"`, `receptor_key = "v_gene+cdr3"`, `tcr_selection = "antigen-selected"`, `lineage_column = "cell_type"`.
- **license**: CC BY 4.0 (10x Genomics datasets)
- **build**: `data-raw/build_hla_tcr_dextramer_demo.R` (self-verifying: re-reads the written file and re-derives the network with the package's own motif core, so the reported numbers are what the shipped object produces)
- **output**: `inst/extdata/v1.4/demo_hla_tcr_dextramer.crb` (~7.8 MB)
- **walkthrough**: `vignettes/hla_tcr_antigen_selected.Rmd` records the download, every processing step, and what changes at each one — with the TCR and HLA transformations spelled out.

> The three HLA demos are complementary and none is sufficient alone. `demo_hla_tcr_synthetic.crb`: dense motif network and clean HLA associations, but everything is fabricated. `demo_hla_tcr_bulk.crb`: real receptors and **real genotypes**, but bulk — no cells, no transcriptome, no lineage. `demo_hla_tcr_dextramer.crb`: **real single cells with real paired TCR** and a network that is legible because the repertoire is antigen-selected, but its genotypes are inferred from that same selection and so cannot carry an association claim. A data set with real paired single-cell VDJ **and** independently measured donor HLA would supersede all three; none is currently public (the pan-disease scTCR reference's HLA is in controlled-access sub-studies).

---

## Trajectory

The trajectory demo is not a separate `.crb`: the monocle2 pseudotime trajectory is
carried **inside** the immune-repertoire demo `demo_full_tcr_bcr.crb`, computed on its
B-cell subset, so one dataset demonstrates TCR + BCR + trajectory.
Built by `data-raw/build_trajectory_demo.R` (see [`trajectory.md`](trajectory.md)).

### demo_full_tcr_bcr.crb (trajectory slot)
- **type**: trajectory
- **technology**: monocle2 `DDRTree` pseudotime (`monocle2 / B_cell_maturation`)
- **dropdown label**: same as the IR demo — `PBMC - Full (T+B)` (the Trajectory tab appears when trajectory data is present)
- **organism / tissue**: human (hg) / PBMC B cells, healthy donor
- **source**: derived entirely from `demo_full_tcr_bcr.crb` itself — no new download. The trajectory is computed on that demo's 915 B cells.
- **acquire**: none (input is the already-built IR demo `.crb`)
- **object type**: `monocle` `CellDataSet`, ordered by `DDRTree`; stored via `Cerebro_v1.3$addTrajectory("monocle2", "B_cell_maturation", trajectory)`.
- **sampling**: `set.seed(42)`; all 915 B cells of the demo; ordering filter on high-variance genes. The stored `meta` has `DR_1`, `DR_2`, `pseudotime`, `state`.
- **cell-type field**: `state` (monocle2 DDRTree state) / continuous `pseudotime`
- **embedded image**: none (n/a for trajectory)
- **license**: 10x Genomics public dataset terms (inherited from the IR demo)
- **build**: `data-raw/build_trajectory_demo.R` (needs `monocle` from Bioconductor; build-time-only, not a runtime dependency)
- **output**: no new file — overwrites the trajectory slot inside `inst/extdata/v1.4/demo_full_tcr_bcr.crb`

**Honest scope**: these are peripheral-blood B cells, not a bone-marrow developmental lineage — the trajectory is **illustrative** of the pseudotime feature, not a biological claim about B-cell ontogeny.

---

## Trekker

Real, measured, down-sampled Trekker single-cell spatial-mapping output (Curio
Bioscience / Takara Bio). Drives the bespoke **Trekker** tab, not the generic
Spatial tab: real single nuclei × whole transcriptome, positions inferred from
bead spatial barcodes, no histology image. Built by
`data-raw/build_trekker_demo.R` (see [`trekker.md`](trekker.md) for the full
download → extract → subsample → build walk-through).

### demo_trekker.crb
- **type**: trekker
- **technology**: Trekker Single-Cell Spatial Mapping (TrekkerU; snRNA + bead spatial barcodes; Slide-tags foundational tech)
- **dropdown label**: `Mouse brain (Trekker)`
- **organism / tissue**: mouse (mm) / brain, coronal section (single reaction `TrekkerU_C`, tile `U0016_004`)
- **source**: official Curio/Takara Trekker example bundle `Mouse_Brain_TrekkerU_C_Sept2025` (~1.3 GB `.tar.gz`), the smallest of the 9 example bundles. **Registration required, not a public download** — obtained through a Curio/Takara account after requesting access to the Trekker example data. **Not redistributable here**; only the derived, down-sampled `.crb` ships (the raw bundle is gitignored).
- **acquire**:
  ```
  # 1. Register / request access to the Trekker example data (Curio / Takara account).
  # 2. Download Mouse_Brain_TrekkerU_C_Sept2025.tar.gz and extract:
  tar -xzf Mouse_Brain_TrekkerU_C_Sept2025.tar.gz
  # 3. Point the builder at the bundle's output/ dir (see trekker.md):
  export TREKKER_OUTPUT_DIR=/path/to/Mouse_Brain_TrekkerU_C_Sept2025/output
  ```
- **object type**: vendor Seurat v5 RDS (`..._ConfPositioned_seurat_spatial.rds`, `SCT` assay, `umap`/`pca`/`SPATIAL` reductions, a legacy `SlideSeq` @images entry). Coordinates are taken from the vendor **Location CSV** (`..._Location_ConfPositionedNuclei.csv`), the coordinate authority — never from `@images` (which is transposed) or the `SPATIAL` reduction (which is y-mirrored). The three orientations are surfaced side by side on the page's "坐标来源" switch.
- **sampling**: `set.seed(42)`; 2,532 nuclei stratified by Louvain cluster (`SCT_snn_res.0.2`) out of 7,420 confidently-positioned, **plus the 50 nuclei that carry official positioning-evidence images force-included**. Whole transcriptome kept (**all 21,374 genes** — "single cell × whole transcriptome" is the platform's differentiator); nuclei are down-sampled rather than genes, so the embedded `data` matrix stays under budget (measured: ~3.8 MB at 2,500 nuclei, all genes).
- **cell-type field**: `celltype` (18 Louvain clusters labelled once by marker z-score argmax: Snap25/Slc17a7→ExN, Gad1→InN, Plp1/Mbp→Oligo, Aqp4/Gfap→Astro, Cx3cr1/C1qa/Csf1r→Micro, Pdgfra→OPC, Prox1→DG; ambiguous clusters honestly left `Neuron`) plus `cluster`
- **embedded image**: **none — Trekker carries no matched histology image** (positions come from bead barcodes, not a tissue photo). Instead the `.crb` embeds, in its `trekker` slot, the 50 official per-nucleus positioning-evidence JPEGs + 3 excluded-class example JPEGs as base64 `data:` URIs (down-scaled to 620 px, quality 68), so the whole demo — expression + evidence — is self-contained in one file.
- **license**: Curio/Takara example data, access-gated (registration). Raw bundle **not redistributable**; the shipped `.crb` is a small derived subset for demonstration.
- **build**: `data-raw/build_trekker_demo.R` (needs `magick` + `base64enc` at build time only, not a package Import)
- **output**: `inst/extdata/v1.4/demo_trekker.crb` (~4.7 MB, self-contained incl. evidence images)

**Honest scope**: `ConfPositioned` ≠ "exactly one location" — 264 of the 7,420 (3.56%) are vendor-salvaged multi-location nuclei, and the RDS's `number_clusters` is all `1` (the salvage trace is erased), so the page labels the set `vendor_confidently_positioned`. The vendor's own 2+-location rate (22.56%) exceeds its own manual's `<20%` guideline; the page shows "below vendor reference range" and does **not** adjudicate sample usability. Moran's I is the **upstream** vendor value (`..._variable_features_spatial_moransi.txt`), computed differently from Cerebro's own — labelled `Upstream` and never mixed.

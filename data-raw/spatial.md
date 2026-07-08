# Spatial demos — build notes

> Provenance of record (source, acquire command, version, sampling, license, output) lives in [`DATASETS.md`](DATASETS.md). This file covers the spatial-specific design and rebuild steps only.

Genuinely-measured, public spatial-transcriptomics `.crb` demos shipped in `inst/extdata/v1.4/` for the Spatial tab. Each is a down-sampled subset of a different technology, so the multi-crb dropdown shows that the **same platform-agnostic extraction pipeline** (`.getSpatialData`, `R/seurat_utils.R`) ingests every platform — there is no per-platform loader.

| File | Technology (dropdown label) | Public source | Cells | Real tissue image |
|------|-----------------------------|---------------|-------|-------------------|
| `demo_spatial_visium.crb` | Mouse brain (Visium) | `SeuratData::stxBrain` (anterior1) | 2,696 | ✅ H&E (external file) |
| `demo_spatial_slideseq.crb` | Mouse hippocampus (Slide-seq v2) | `SeuratData::ssHippo` | 5,000 | — (see note) |
| `demo_spatial_merfish.crb` | Mouse ileum (MERFISH) | `MerfishData::MouseIleumPetukhov2021` | 5,000 | ✅ DAPI mosaic |
| `demo_spatial_xenium.crb` | Mouse brain (Xenium) | 10x `Xenium_V1_FF_Mouse_Brain_Coronal_Subset_CTX_HP` (public) | 5,000 | ✅ DAPI morphology |

The four files above are **real measured data**. They deliberately demonstrate **both** background-image paths the app supports:
- **MERFISH** and **Xenium** *embed* their genuine histology image (DAPI mosaic / DAPI morphology) inside the `.crb` under `histology_image`, with the image extent in coordinate space (`histology_image_bounds`). The Spatial tab offers this as the "Tissue background (H&E / DAPI)" background.
- **Visium** loads its genuine H&E from an *external* PNG (`demo_spatial_visium_he.png`) via the `spatial_images` option in `inst/app.R` — a live example of the external-image path, which also keeps the Visium `.crb` smaller. The tab offers it by filename.

Images render in their native orientation; if a dataset needs a flip to align with the points, the user sets it from the Spatial tab's "Flip vertically/horizontally" checkboxes (external images can also be pre-flipped via `spatial_images_flip_y` in `inst/app.R`).
Slide-seq carries no image by design (see the note below): the bead scatter is the complete spatial view.

### Image ↔ point alignment (the flip decision and the aspect lock)

Getting the real image to line up with the points needs two things, because the Spatial tab draws the background as a DOM layer stretched to fill the plot's drawing area (it is not a Plotly `layout.image`):

1. **A vertical flip, when a dataset needs one (user control).** The image is always stored NATIVE (row 0 = image top) in the `.crb`; the renderer draws it top-down while Plotly's y-axis grows upward. Whether the display needs a vertical flip is **not uniform** — it depends on how a dataset's point y relates to its image rows, which differs by platform (e.g. Seurat's `GetTissueCoordinates` vs a raw `y_centroid` vs `MerfishData::imgRaster`). There is no stored per-`.crb` flip flag: the user aligns the image with the Spatial tab's "Flip vertically/horizontally" checkboxes (applied by `func_projection_update_plot.R` → `js_projection_update_plot.js`, via the background `scale(1, -1)`).

   Which orientation is correct per dataset is judged by **visual comparison against a native ground-truth reference** — overlay the real cell centroids on the source raster in its native frame, note an unambiguous anatomical landmark, then flip in the app until that landmark matches. (Automated point-on-tissue "brightness" scores were tried and proved **unreliable** — dense tissue like the Xenium brain defeats them — so landmark comparison is the standard.) For the shipped demos:
   - **Visium** (mouse brain): needs a **vertical flip** — olfactory bulb lower-left, tissue body lower-middle, matching Seurat's own `SpatialPlot`.
   - **Xenium** (mouse brain CTX+HP): **no flip** — hippocampus lower-right, pial surface along the top, matching the native DAPI reference.
   - **MERFISH** (mouse ileum): **no flip** — villi orientation confirmed by eye against the native DAPI.

   The lesson: do **not** apply one blanket flip rule, and do **not** trust the brightness score. When adding a new image demo, build a native-frame centroid overlay, pick a landmark, and flip in the app until it matches.
2. **Aspect lock at render time.** The stretch-to-fill would squash a non-square image (the MERFISH DAPI mosaic is ~0.6:1, tall). When an embedded image is active the renderer sets `yaxis.scaleanchor = 'x'` (`func_projection_update_plot.R` flags `is_embedded`; `js_projection_update_plot.js` applies the lock), so the drawing area keeps the image's width:height and the stretch stays proportional. Non-embedded projections (UMAP etc.) are untouched.

`demo_spatial.crb` + `demo_spatial_histology.svg` are lightweight fixtures used only by the unit tests (`test-spatial.R`) to exercise the class methods and the external-`spatial_images` overlay path. They are intentionally not part of the bundled app's dataset dropdown.

## Why Slide-seq has no background image

This is structural, not an oversight: the platform records positions, not a tissue photo. The `SlideSeq` S4 class in SeuratObject has only a `coordinates` slot — it carries no tissue raster, unlike Visium's `VisiumV2` (`image` slot) or the imaging `FOV` (which can hold a mosaic). Slide-seq images beads to recover their positions, but the public `ssHippo` object stores only those bead coordinates, not an H&E/DAPI photo.

So the bead scatter *is* the complete spatial view; there is no real image to overlay.

## Why these four

They deliberately span the structural axes that decide whether the extraction pipeline copes with a platform: how coordinates are stored, whether a tissue image exists, and the Seurat object version.

**Spot vs. bead vs. in-situ imaging:**

- Visium = 55 µm spots, coords in the `VisiumV2` image (`imagerow`/`imagecol`).
- Slide-seq v2 = 10 µm beads, coords in the `SlideSeq` image slot (`x`/`y`).
- MERFISH = single-cell imaging, coords via `GetTissueCoordinates` on an `FOV` with `Centroids` — the same route `LoadVizgen` / `LoadXenium` produce.
- Xenium = in-situ single-cell imaging; here built from the raw 10x outs (`.h5` matrix + `cells.csv.gz` centroids) into the same `FOV`/`Centroids` object, with real DAPI morphology as the background. Cells sit in **micron** coordinates while the morphology raster is in **pixels**, so the image extent in coordinate space is `dims × pixel_size` (0.2125 µm/px) — a scale conversion Visium/MERFISH do not need.

**Seurat v4 vs. v5 object:**

- Slide-seq (`ssHippo`) ships as a **Seurat v3.1.4-era `SlideSeq`** object. It is the end-to-end proof that `exportFromSeurat` handles non-v5 spatial objects, not only Seurat v5 (Visium/MERFISH/Xenium are v5). The old blanket `is_seurat_v5 &&` gate in `exportFromSeurat.R` used to drop these entirely.

**Package-shipped vs. network-fetched source:**

- Visium, Slide-seq and MERFISH load from R packages (`SeuratData`, `MerfishData`).
- Xenium fetches raw data over the network (10x CDN zip), but its build function **auto-downloads it on first run** (via `ensure_download` / `ensure_unzipped`) into `data-raw/xenium/`, skipping the download when the file is already there. So the whole build is self-contained — one `Rscript` call — and only no-ops with a message if a download actually fails.

## Rebuild

From the package root, with `cerebroAppLite`, `Seurat`, `SeuratData` and `MerfishData` installed:

```bash
Rscript data-raw/build_spatial_demos.R
```

That single command runs the whole link → `.crb` pipeline. Three builds (Visium, Slide-seq, MERFISH) pull data from R packages; Xenium auto-downloads its raw data on first run (and skips the download when it is already present):

- **Xenium** auto-fetches the 10x mouse brain coronal CTX+HP outs bundle (~3.5 GB) and unzips it under `data-raw/xenium/brain/`. Its DAPI morphology image is a JPEG2000 OME-TIFF that R's `tiff`/`EBImage` cannot decode, so the build reads it with the Bioconductor package `RBioFormats` (a pure-R wrapper over the Java Bio-Formats library — no Python); if `RBioFormats` is missing it ships coordinates without the image.

The exact source URLs are recorded in the `acquire` blocks in [`DATASETS.md`](DATASETS.md); the build performs those downloads for you, so you no longer need to run them by hand.

The script (`build_spatial_demos.R`):

1. Loads each dataset, coercing the assay name to `Spatial` and (for `ssHippo`) running `UpdateSeuratObject()` to repair the legacy `SlideSeq` class before any `validObject`/`subset` call. The object stays a `SlideSeq` image — that is the point: it exercises the non-v5 path. Xenium is assembled from the raw `.h5` matrix + `cells.csv.gz` centroids into an `FOV`/`Centroids` object.
2. Down-samples to ~5,000 cells (stratified by cluster / cell class) and trims the embedded expression matrix (Visium to 1,200 genes, others to ~2,000; small imaging panels like MERFISH's 241 and Xenium's 280 are kept whole) so the shipped `.crb` stays small. `nUMI`/`nGene` are computed on the full gene set beforehand.
3. Runs a light `NormalizeData → PCA → UMAP` (and `FindClusters` where the source has no cell types) so `exportFromSeurat` has a `data` layer, a UMAP reduction and a grouping variable to colour by.
4. For Visium, MERFISH and Xenium, extracts the real histology raster, encodes it to a base64 PNG data URI, and injects it into the spatial slot as `histology_image` with `histology_image_bounds` (the image's extent in coordinate space; for Xenium that means converting the pixel raster to microns via `pixel_size`).
5. Calls `exportFromSeurat(...)`, then **verifies** the written `.crb`: the spatial slot is non-empty, its `coordinates` has `x`/`y`, and the coordinate cells intersect the expression cells.

Output overwrites the four spatial `.crb` files in `inst/extdata/v1.4/`.

## Try it

Launch the bundled app; the "Select sample dataset" switcher lists all four under their technology labels. Selecting one reveals the conditional **Spatial** tab, which renders the real coordinates coloured by cluster / cell type, over the real tissue image where available.

```r
library(cerebroAppLite)
createShinyApp(
  cerebro_data = c(
    "Mouse brain (Visium)"             = system.file("extdata/v1.4/demo_spatial_visium.crb",    package = "cerebroAppLite"),
    "Mouse hippocampus (Slide-seq v2)" = system.file("extdata/v1.4/demo_spatial_slideseq.crb",  package = "cerebroAppLite"),
    "Mouse ileum (MERFISH)"            = system.file("extdata/v1.4/demo_spatial_merfish.crb",   package = "cerebroAppLite"),
    "Mouse brain (Xenium)"             = system.file("extdata/v1.4/demo_spatial_xenium.crb",    package = "cerebroAppLite")
  )
)
```

#!/usr/bin/env Rscript
# ============================================================================
# Build the HLA & TCR Motifs demo (.crb)
# ============================================================================
# Produces `inst/extdata/v1.4/demo_hla_tcr.crb`: a showcase dataset for the
# "HLA & TCR Motifs" page. The base object contains real expression values and
# real receptor sequences, but build_ir_demos.R assigned those receptors to
# expression cells synthetically. This is NOT paired GEX+VDJ evidence.
#
#   1. `cell_type_fine` — a FINER T-cell lineage (CD8 T / CD4 T / Treg) derived
#      from the object's OWN real marker-gene expression (CD8A/CD8B vs CD4/IL7R
#      vs FOXP3). This is an explicitly heuristic demo annotation, not a
#      validated cell-type call. The base object only had a coarse "T cells"
#      label; B cells / Monocytes keep their labels.
#
#   2. `hla_typing` — a SYNTHETIC per-sample HLA typing table, built from real
#      common European HLA allele frequencies, attached with
#      source_type = "synthetic". It is clearly flagged as synthetic everywhere
#      (slot provenance + app UI), so it demonstrates the HLA-context workflow
#      WITHOUT claiming a real genotype. Real donor HLA would replace it via the
#      same addHLATyping() path.
#
# Expression values, projections and receptor sequences are carried over, but
# their receptor-to-cell linkage remains synthetic. See DATASETS.md.
#
# Run from the package root:
#   Rscript data-raw/build_hla_tcr_demo.R
# ============================================================================

suppressMessages(library(cerebroAppLite))

set.seed(42)

src <- Sys.getenv(
  "SRC_CRB",
  unset = system.file(
    "extdata/v1.4/demo_full_tcr_bcr.crb",
    package = "cerebroAppLite"
  )
)
out <- Sys.getenv("OUT_CRB", unset = "inst/extdata/v1.4/demo_hla_tcr.crb")

stopifnot(nzchar(src), file.exists(src))
old <- readRDS(src)

## The shipped .crb was serialized with an OLDER Cerebro_v1.3 generator, so the
## deserialized object does NOT carry the new HLA methods (R6 binds methods at
## creation time). Rebuild a fresh object from the CURRENT generator and copy
## every public data field over, so addHLATyping()/getHLATyping() are available.
data_fields <- c(
  "expression",
  "meta_data",
  "projections",
  "groups",
  "gene_lists",
  "trees",
  "trajectories",
  "enriched_pathways",
  "marker_genes",
  "most_expressed_genes",
  "extra_material",
  "cell_cycle",
  "parameters",
  "technical_info",
  "experiment",
  "version",
  "expression_backend",
  "immune_repertoire",
  "bcr_data",
  "tcr_data",
  "spatial"
)
crb <- Cerebro_v1.3$new()
for (f in data_fields) {
  val <- tryCatch(old[[f]], error = function(e) NULL)
  if (!is.null(val)) {
    crb[[f]] <- val
  }
}

## ---- 1. Derive a finer T-cell lineage from real expression ---------------- ##
md <- crb$getMetaData()
expr <- crb$expression
stopifnot("cell_type" %in% colnames(md), "cell_barcode" %in% colnames(md))

# Mean expression of a marker set per cell (0 when a gene is absent).
marker_score <- function(genes) {
  genes <- intersect(genes, rownames(expr))
  if (length(genes) == 0) {
    return(rep(0, ncol(expr)))
  }
  Matrix::colMeans(expr[genes, , drop = FALSE])
}

cd8_score <- marker_score(c("CD8A", "CD8B"))
cd4_score <- marker_score(c("CD4", "IL7R"))
treg_score <- marker_score(c("FOXP3"))

# Assign a fine label only to cells the base object calls "T cells"; everything
# else keeps its coarse label. Treg wins when FOXP3 is expressed; otherwise the
# higher of CD8 vs CD4 score decides, with an "T (unassigned)" fallback when
# neither lineage marker is expressed (kept honest, mapped to Unknown context).
is_t <- md$cell_type == "T cells"
fine <- as.character(md$cell_type)
fine[is_t] <- ifelse(
  treg_score[is_t] > 0,
  "Treg",
  ifelse(
    cd8_score[is_t] == 0 & cd4_score[is_t] == 0,
    "T (unassigned)",
    ifelse(cd8_score[is_t] >= cd4_score[is_t], "CD8 T", "CD4 T")
  )
)
md$cell_type_fine <- factor(fine)
crb$setMetaData(md)

cat("cell_type_fine composition:\n")
print(table(md$cell_type_fine))

## ---- 2. Synthetic HLA typing per sample ----------------------------------- ##
# Common European alleles per locus (illustrative, from public frequency
# tables). Each sample draws two alleles per locus. SYNTHETIC — see header.
allele_pool <- list(
  "HLA-A" = c("01:01", "02:01", "03:01", "24:02", "11:01"),
  "HLA-B" = c("07:02", "08:01", "44:02", "15:01", "40:01"),
  "HLA-C" = c("07:01", "07:02", "05:01", "04:01", "03:04"),
  "HLA-DRB1" = c("03:01", "15:01", "07:01", "04:01", "13:01")
)

samples <- names(crb$getImmuneRepertoire())
stopifnot(length(samples) > 0)

typing_list <- lapply(samples, function(s) {
  unlist(lapply(names(allele_pool), function(locus) {
    a <- sample(allele_pool[[locus]], 2, replace = TRUE)
    paste0(locus, "*", a)
  }))
})
names(typing_list) <- samples

crb$addHLATyping(
  typing_list,
  source_type = "synthetic",
  typing_method = "synthetic (European allele frequencies)",
  source_reference = "data-raw/build_hla_tcr_demo.R"
)

if (is.list(crb$experiment)) {
  crb$experiment$hla_tcr_demo_scope <- paste(
    "Software fixture: real expression and receptor sequences;",
    "synthetic receptor-to-cell linkage; heuristic lineage labels; synthetic HLA"
  )
}

cat("\nHLA typing (synthetic):\n")
print(crb$getHLATyping()[, c(
  "sample",
  "locus",
  "copy",
  "allele",
  "source_type"
)])

## ---- 3. Save -------------------------------------------------------------- ##
dir.create(dirname(out), showWarnings = FALSE, recursive = TRUE)
saveRDS(crb, out)
cat(sprintf(
  "\nWrote %s (%.1f MB)\n",
  out,
  file.info(out)$size / 1024^2
))

## ---- 4. Verify round-trip ------------------------------------------------- ##
check <- readRDS(out)
stopifnot(
  "cell_type_fine" %in% colnames(check$getMetaData()),
  nrow(check$getHLATyping()) > 0,
  all(check$getHLATyping()$source_type == "synthetic")
)
cat("Round-trip verification passed.\n")

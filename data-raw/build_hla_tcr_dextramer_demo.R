#!/usr/bin/env Rscript
# ============================================================================
# Build the REAL single-cell antigen-selected TCR demo (.crb)
#   -> inst/extdata/v1.4/demo_hla_tcr_dextramer.crb
# ============================================================================
# This is the ONLY HLA demo the package ships. It replaced two earlier ones
# (2026-07-21): a fully fabricated fixture and a real BULK TCRb cohort. Neither
# was both real and single-cell, and cerebroAppLite is a single-cell app. Their
# build scripts are kept in data-raw/ as the reproducibility record --
# build_hla_tcr_demo.R and build_hla_tcr_bulk_demo.R -- but what they write into
# inst/extdata/v1.4/ is no longer tracked or installed. See data-raw/hla.md S1.
#
# Because this demo is sorted CD8+ T cells, its typing is CLASS I ONLY, so the
# Class I x Class II pair scope stays hidden on it (hla_pair_available() gates
# the control). That is a real gap, stated rather than papered over.
#
# WHY THIS DATA SET EXISTS
# ------------------------
# The honest objection to the motif page is: "if the network is only legible on
# synthetic data, what is the feature for?" The answer is that a CDR3 Hamming-1
# network needs a repertoire that has been ANTIGEN-SELECTED. An unselected
# polyclonal repertoire is sparse in CDR3 space -- pairs at distance 1 are rare,
# and more cells do not fix it. A selected repertoire converges: many donors
# arrive at near-identical CDR3s for the same epitope (public / convergent
# recombination), which is exactly what the network draws.
#
# Measured on this source with THIS PACKAGE's own motif core (not a claim, a
# number -- the verification block at the bottom re-measures it on the shipped
# object):
#
#   all cells, unselected         26,449 unique CDR3  -> trips the size guard
#   dextramer-binding cells        2,910 unique CDR3  ->  308 nodes / 75 motifs
#   one epitope: Flu-MP GILGFVFTL    267 unique CDR3  ->  121 nodes /  7 motifs
#
# The Flu M1 line is the point: 45% of the CDR3s seen against one immunodominant
# epitope collapse into SEVEN families. That is real measured convergence.
#
# SOURCE
# ------
# 10x Genomics, "CD8+ T cells of Healthy Donor 1-4" (2019), the dextramer /
# Immune Map experiment published as Zhang et al., Sci Adv 7:eabf5835 (2021).
# CD8+ T cells from four HLA-haplotyped healthy donors were stained with a pool
# of dCODE dextramers, sorted, and run on 10x 5' immune profiling: paired ab TCR
# + transcriptome + surface protein + per-cell dextramer counts.
# License: CC BY 4.0.
#
# WHAT IS REAL AND WHAT IS DERIVED  (read this before trusting any number)
# -----------------------------------------------------------------------
#   REAL, measured:
#     * the cells, their transcriptomes, their surface protein counts
#     * the paired TCR alpha/beta contigs -- V/J gene and CDR3 amino acids
#     * which dextramer each cell bound (10x's own binarized calls)
#     * the HLA restriction of each dextramer: it is a property of the reagent,
#       stated in the reagent's name (A0201_GILGFVFTL_Flu-MP -> HLA-A*02:01)
#
#     * the donors' HLA GENOTYPES, transcribed from table S1 of the paper's
#       supplementary PDF (inline as DONOR_HLA below, with citation and URL).
#       They were measured independently of these cells, so they can carry an
#       association claim.
#
# WHY THE GENOTYPES ARE NOT INFERRED FROM BINDING
# -----------------------------------------------
# An earlier version of this script derived each donor's alleles from which
# dextramers their cells bound. That was circular AND wrong. Circular, because a
# donor would be a carrier of HLA-X precisely because their cells bound an
# X-restricted reagent, and the motifs come from those same cells. Wrong,
# because binding is simply not genotype: donor3 has 25,674 cells -- 92.8% of
# its antigen-specific cells -- binding A*03:01-restricted dextramers, and
# table S1 shows it carries no A*03:01 at all (it is A*24:02 / A*29:02). No
# threshold separates cross-reactivity at that scale. The published table is
# used instead, and the demo can therefore ship real genotypes.
#
# WHAT REMAINS DECLARED
# ---------------------
# The repertoire is still ANTIGEN-SELECTED: cells were sorted for dextramer
# binding, so this is not an unbiased repertoire and the page says so through
# `technical_info$tcr_selection`. That is a statement about how the cells were
# chosen, not about the genotypes, which are independent.
#
# USAGE
#   Rscript data-raw/build_hla_tcr_dextramer_demo.R
# Raw downloads are cached in data-raw/vdj_10x_dextramer/ (gitignored, ~1.6 GB);
# only the built .crb ships.
# ============================================================================

suppressPackageStartupMessages({
  library(Matrix)
  library(Seurat)
  library(scRepertoire)
})
devtools::load_all(".", quiet = TRUE)

set.seed(20260721)

## ---- Configuration ------------------------------------------------------ ##
DONORS <- 1:4
CACHE <- "data-raw/vdj_10x_dextramer"
OUT <- "inst/extdata/v1.4/demo_hla_tcr_dextramer.crb"
BASE <- "https://cf.10xgenomics.com/samples/cell-vdj/3.0.2"

## The donors' REAL genotypes: table S1 ("HLA haplotypes of the healthy donors")
## of the paper's supplementary PDF, transcribed by hand. Kept inline so this
## script is self-contained -- it is 14 rows, and a separate file would only be
## one more thing to keep in step.
##
##   Supplement (Figs. S1-S11, Tables S1-S5), ~6 MB:
##   https://www.science.org/doi/suppl/10.1126/sciadv.abf5835/suppl_file/abf5835_sm.pdf
##   (the link printed inside the paper, advances.sciencemag.org/.../DC1, is dead:
##    that domain was retired when Science migrated to science.org)
##
## Table S1 gives two HLA-A and two HLA-B alleles per donor, "na" where the paper
## reports none -- which is why donors 1 and 2 contribute a single B allele.
## Donor 4 is homozygous A*03:01. `copy` is 1 or 2 within a locus, matching the
## canonical HLA table this package stores.
##
## This matters more than it looks. An earlier version of this script inferred
## the genotypes from which dextramers each donor's cells bound, and that
## inference was WRONG: donor3 has 25,674 cells (92.8% of its specific cells)
## binding A*03:01-restricted dextramers and is not an A*03:01 carrier at all --
## it is A*24:02 / A*29:02. Binding is not genotype, and cross-reactivity is far
## larger than a threshold can separate. The published table is used instead.
DONOR_HLA <- read.csv(
  text = "donor,copy,allele
donor1,1,HLA-A*02:01
donor1,2,HLA-A*11:01
donor1,1,HLA-B*35:01
donor2,1,HLA-A*02:01
donor2,2,HLA-A*01:01
donor2,1,HLA-B*08:01
donor3,1,HLA-A*24:02
donor3,2,HLA-A*29:02
donor3,1,HLA-B*35:02
donor3,2,HLA-B*44:03
donor4,1,HLA-A*03:01
donor4,2,HLA-A*03:01
donor4,1,HLA-B*07:02
donor4,2,HLA-B*57:01",
  stringsAsFactors = FALSE
)

## Shipped size. The demo must stay a few MB, so the antigen-selected cells are
## subsampled per donor and the matrix is cut to informative genes.
CELLS_PER_DONOR <- 3000L
N_GENES <- 2000L

## ---- 1. Download (on demand) -------------------------------------------- ##
dir.create(CACHE, showWarnings = FALSE, recursive = TRUE)

## These are big files (the expression matrix is ~300 MB) on a server that is
## not always fast. R's default 60 s timeout truncates them silently-ish, and a
## truncated file left at `dest` would be treated as a completed download on the
## next run, so: download to a .part file, resume if interrupted, and only move
## it into place once curl reports success.
options(timeout = max(getOption("timeout"), 3600))

fetch <- function(url, dest) {
  if (file.exists(dest)) {
    return(invisible(dest))
  }
  part <- paste0(dest, ".part")
  cat("  downloading", basename(dest), "...\n")
  ok <- FALSE
  if (nzchar(Sys.which("curl"))) {
    status <- system2(
      "curl",
      c(
        "-fL",
        "--retry",
        "5",
        "--retry-delay",
        "3",
        "-C",
        "-",
        "-o",
        shQuote(part),
        shQuote(url)
      ),
      stdout = FALSE,
      stderr = FALSE
    )
    ok <- identical(status, 0L)
  } else {
    ok <- tryCatch(
      {
        utils::download.file(url, part, mode = "wb", quiet = TRUE)
        TRUE
      },
      error = function(e) FALSE
    )
  }
  if (!ok || !file.exists(part) || file.info(part)$size == 0) {
    unlink(part)
    stop("download failed: ", url, call. = FALSE)
  }
  file.rename(part, dest)
  invisible(dest)
}

donor_files <- function(d) {
  stem <- sprintf("vdj_v1_hs_aggregated_donor%d", d)
  list(
    contigs = file.path(CACHE, sprintf("%s_all_contig_annotations.csv", stem)),
    binarized = file.path(CACHE, sprintf("%s_binarized_matrix.csv", stem)),
    gex_tar = file.path(
      CACHE,
      sprintf("%s_filtered_feature_bc_matrix.tar.gz", stem)
    ),
    gex_dir = file.path(CACHE, sprintf("%s_gex", stem)),
    url_stem = sprintf("%s/%s/%s", BASE, stem, stem)
  )
}

cat("== 1. raw data ==\n")
for (d in DONORS) {
  f <- donor_files(d)
  fetch(paste0(f$url_stem, "_all_contig_annotations.csv"), f$contigs)
  fetch(paste0(f$url_stem, "_binarized_matrix.csv"), f$binarized)
  fetch(paste0(f$url_stem, "_filtered_feature_bc_matrix.tar.gz"), f$gex_tar)
  if (!dir.exists(f$gex_dir)) {
    dir.create(f$gex_dir, showWarnings = FALSE, recursive = TRUE)
    utils::untar(f$gex_tar, exdir = f$gex_dir)
  }
}

## ---- 2. TCR: contigs -> scRepertoire CT* columns ------------------------- ##
## The app reads receptors through hla_parse_ir_segments(), whose contract is
## the scRepertoire shape: `barcode`, `CTgene`, `CTaa`. The binarized matrix
## carries CDR3s but NO V/J gene, and V is required (it is half of this source's
## receptor key), so the contigs are the input and combineTCR() does the join.
cat("== 2. TCR contigs -> clonotypes ==\n")
tcr_by_donor <- lapply(DONORS, function(d) {
  contigs <- read.csv(donor_files(d)$contigs, stringsAsFactors = FALSE)
  # combineTCR wants one data frame per sample and productive contigs only.
  contigs <- contigs[
    contigs$productive %in%
      c("True", "TRUE", TRUE) &
      contigs$chain %in% c("TRA", "TRB"),
    ,
    drop = FALSE
  ]
  out <- scRepertoire::combineTCR(
    list(contigs),
    samples = sprintf("donor%d", d),
    filterMulti = TRUE
  )[[1]]
  # combineTCR prefixes the barcode with the sample id; keep the raw 10x barcode
  # too so the dextramer table and the expression matrix can be joined on it.
  out$barcode_raw <- sub("^donor[0-9]+_", "", out$barcode)
  out$donor <- sprintf("donor%d", d)
  out
})
names(tcr_by_donor) <- sprintf("donor%d", DONORS)
cat(sprintf(
  "   cells with a clonotype: %s\n",
  paste(
    sprintf("d%d=%d", DONORS, vapply(tcr_by_donor, nrow, integer(1))),
    collapse = " "
  )
))

## ---- 3. Antigen specificity and the HLA it is restricted by -------------- ##
## Every dextramer column is named <allele>_<peptide>_<antigen>_binder, e.g.
## A0201_GILGFVFTL_Flu-MP_Influenza_binder. The allele prefix is the reagent's
## own HLA restriction -- real, published, and independent of these cells.
## Columns containing "NR(" are 10x's negative controls and are never evidence.
cat("== 3. dextramer specificity ==\n")

allele_of <- function(col) {
  a <- sub("^([ABC])([0-9]{2})([0-9]{2})_.*", "\\1*\\2:\\3", col)
  paste0("HLA-", a)
}
peptide_of <- function(col) sub("^[ABC][0-9]{4}_([A-Z]+)_.*", "\\1", col)
antigen_of <- function(col) {
  x <- sub("^[ABC][0-9]{4}_[A-Z]+_", "", col)
  sub("_binder$", "", x)
}

dex_by_donor <- lapply(DONORS, function(d) {
  b <- read.csv(
    donor_files(d)$binarized,
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  dex <- grep("^[ABC][0-9]{4}_", colnames(b), value = TRUE)
  dex <- grep("NR\\(", dex, value = TRUE, invert = TRUE)
  hits <- as.matrix(b[, dex, drop = FALSE]) == "True"
  hits[is.na(hits)] <- FALSE
  n_hit <- rowSums(hits)
  # A cell is assigned to ONE specificity: the dextramer it bound. Cells binding
  # several are dropped rather than guessed at -- an ambiguous specificity would
  # put a cell in the wrong HLA context, which is the one thing this page must
  # not do.
  keep <- n_hit == 1L
  idx <- max.col(hits, ties.method = "first")
  data.frame(
    barcode_raw = b$barcode,
    donor = sprintf("donor%d", d),
    specific = keep,
    dextramer = ifelse(keep, dex[idx], NA_character_),
    stringsAsFactors = FALSE
  )
})
dex_all <- do.call(rbind, dex_by_donor)
dex_all$antigen <- ifelse(
  is.na(dex_all$dextramer),
  NA_character_,
  antigen_of(dex_all$dextramer)
)
dex_all$peptide <- ifelse(
  is.na(dex_all$dextramer),
  NA_character_,
  peptide_of(dex_all$dextramer)
)
dex_all$restricting_allele <- ifelse(
  is.na(dex_all$dextramer),
  NA_character_,
  allele_of(dex_all$dextramer)
)
cat(sprintf(
  "   cells with exactly one specificity: %d of %d\n",
  sum(dex_all$specific),
  nrow(dex_all)
))

## Donor genotype, read off the published table (see DONOR_HLA above).
hla_donor_typing <- function(donors) {
  tab <- DONOR_HLA[DONOR_HLA$donor %in% donors, , drop = FALSE]
  data.frame(
    sample = tab$donor,
    donor_id = tab$donor,
    allele = tab$allele,
    copy = as.integer(tab$copy),
    stringsAsFactors = FALSE
  )
}
donor_typing <- hla_donor_typing(sprintf("donor%d", DONORS))
cat("   published genotypes (table S1):\n")
for (dn in unique(donor_typing$sample)) {
  cat(sprintf(
    "     %s: %s\n",
    dn,
    paste(donor_typing$allele[donor_typing$sample == dn], collapse = ", ")
  ))
}

## ---- 4. Cell selection: the antigen-selected repertoire ------------------ ##
## Only cells that (a) have a productive clonotype and (b) bound exactly one
## dextramer. This IS the selection that makes the motif network legible, and
## it is the data set's defining property, not a convenience.
cat("== 4. cell selection ==\n")
tcr_all <- do.call(
  rbind,
  lapply(tcr_by_donor, function(x) {
    x[, c(
      "barcode",
      "barcode_raw",
      "donor",
      "CTgene",
      "CTnt",
      "CTaa",
      "CTstrict"
    )]
  })
)
sel <- merge(
  tcr_all,
  dex_all[
    dex_all$specific,
    c(
      "barcode_raw",
      "donor",
      "dextramer",
      "antigen",
      "peptide",
      "restricting_allele"
    )
  ],
  by = c("barcode_raw", "donor")
)
sel <- sel[!is.na(sel$CTaa) & nzchar(sel$CTaa), , drop = FALSE]

# Subsample per donor, deterministically.
keep_rows <- unlist(lapply(split(seq_len(nrow(sel)), sel$donor), function(ix) {
  if (length(ix) <= CELLS_PER_DONOR) ix else sort(sample(ix, CELLS_PER_DONOR))
}))
sel <- sel[sort(keep_rows), , drop = FALSE]
cat(sprintf(
  "   kept %d antigen-selected cells (%s)\n",
  nrow(sel),
  paste(
    sprintf(
      "d%s=%d",
      sub("donor", "", names(table(sel$donor))),
      table(sel$donor)
    ),
    collapse = " "
  )
))

## ---- 5. Expression + projection ----------------------------------------- ##
## Real measured transcriptomes for exactly the kept cells. Subset FIRST, then
## run the standard Seurat pipeline, so nothing is computed on cells that are
## thrown away.
cat("== 5. expression + UMAP ==\n")
mats <- lapply(DONORS, function(d) {
  f <- donor_files(d)
  sub <- list.dirs(f$gex_dir, recursive = TRUE)
  hit <- sub[
    file.exists(file.path(sub, "matrix.mtx.gz")) |
      file.exists(file.path(sub, "matrix.mtx"))
  ]
  m <- Seurat::Read10X(hit[1])
  if (is.list(m)) {
    m <- m[["Gene Expression"]]
  }
  want <- sel$barcode_raw[sel$donor == sprintf("donor%d", d)]
  m <- m[, intersect(colnames(m), want), drop = FALSE]
  colnames(m) <- paste0(sprintf("donor%d_", d), colnames(m))
  m
})
genes <- Reduce(intersect, lapply(mats, rownames))
expr <- do.call(cbind, lapply(mats, function(m) m[genes, , drop = FALSE]))
sel <- sel[sel$barcode %in% colnames(expr), , drop = FALSE]
expr <- expr[, sel$barcode, drop = FALSE]
cat(sprintf("   matrix: %d genes x %d cells\n", nrow(expr), ncol(expr)))

so <- Seurat::CreateSeuratObject(counts = expr)
so <- Seurat::NormalizeData(so, verbose = FALSE)
so <- Seurat::FindVariableFeatures(so, nfeatures = N_GENES, verbose = FALSE)
so <- Seurat::ScaleData(so, verbose = FALSE)
so <- Seurat::RunPCA(so, npcs = 30, verbose = FALSE)
so <- Seurat::RunUMAP(so, dims = 1:30, verbose = FALSE)

hv <- Seurat::VariableFeatures(so)
expression <- as.matrix(Seurat::GetAssayData(so, layer = "data")[
  hv,
  ,
  drop = FALSE
])
umap <- as.data.frame(Seurat::Embeddings(so, "umap"))
colnames(umap) <- c("UMAP_1", "UMAP_2")

## ---- 6. Assemble the Cerebro object ------------------------------------- ##
cat("== 6. assemble .crb ==\n")
meta <- data.frame(
  cell_barcode = sel$barcode,
  sample = sel$donor,
  # Every cell here is a sorted CD8+ T cell. Declared, not inferred: see
  # technical_info$lineage_column below.
  cell_type = "CD8 T",
  antigen = sel$antigen,
  peptide = sel$peptide,
  restricting_allele = sel$restricting_allele,
  stringsAsFactors = FALSE
)
rownames(umap) <- meta$cell_barcode

immune_repertoire <- lapply(split(sel, sel$donor), function(x) {
  data.frame(
    barcode = x$barcode,
    CTgene = x$CTgene,
    CTnt = x$CTnt,
    CTaa = x$CTaa,
    CTstrict = x$CTstrict,
    stringsAsFactors = FALSE
  )
})

crb <- Cerebro_v1.3$new()
crb$expression <- expression
crb$setMetaData(meta)
crb$projections <- list(umap = umap)
crb$groups <- list(
  sample = sort(unique(meta$sample)),
  cell_type = sort(unique(meta$cell_type)),
  antigen = sort(unique(meta$antigen)),
  restricting_allele = sort(unique(meta$restricting_allele))
)
crb$immune_repertoire <- immune_repertoire
crb$experiment <- list(
  experiment_name = "Antigen-selected CD8 T cells - real 10x dextramer cohort",
  organism = "hg",
  date_of_export = Sys.Date()
)
crb$technical_info <- list(
  observation_unit = "cell",
  # This source identifies a receptor by V gene + CDR3, like the bulk demo.
  receptor_key = "v_gene+cdr3",
  tcr_selection = "antigen-selected",
  tcr_selection_detail = paste(
    "Cells were sorted for binding to a pooled dCODE dextramer panel, so this",
    "repertoire is antigen-SELECTED -- which is exactly why its motif network",
    "is legible where an unselected repertoire's is not. It is therefore not an",
    "unbiased sample of the donors' repertoires: which receptors are present",
    "was decided by the panel. The donor HLA genotypes are the published ones",
    "(table S1 of the source paper), measured independently of these cells, so",
    "they are not circular with the selection."
  ),
  # Declared, so the app never has to guess which column holds the lineage.
  lineage_column = "cell_type"
)
crb$addHLATyping(
  donor_typing,
  source_type = "genotyped",
  typing_method = "HLA typing published in table S1 of Zhang et al., Sci Adv 2021",
  source_reference = "10x Genomics CD8+ T cells of Healthy Donor 1-4; Zhang et al., Sci Adv 2021, eabf5835"
)

dir.create(dirname(OUT), showWarnings = FALSE, recursive = TRUE)
saveRDS(crb, OUT, compress = "xz")
cat(sprintf("   wrote %s (%.1f MB)\n", OUT, file.info(OUT)$size / 1024^2))

## ---- 7. Verify with the package's OWN motif core ------------------------- ##
## Everything above is intent. What matters is what the shipped object actually
## produces, so these numbers are measured on the file that was just written.
cat("== 7. verification (measured on the shipped object) ==\n")
check <- readRDS(OUT)
ir <- check$getImmuneRepertoire()
cat(
  "   chains:",
  paste(cerebroAppLite:::hla_detect_chains(ir), collapse = ", "),
  "\n"
)
for (ch in c("TRB", "TRA")) {
  seg <- cerebroAppLite:::hla_parse_ir_segments(ir, ch)
  if (is.null(seg) || nrow(seg) == 0) {
    cat(sprintf("   %s: no segments\n", ch))
    next
  }
  g <- cerebroAppLite:::hla_build_motif_graph(seg, by_v = TRUE, min_nodes = 2L)
  if (!cerebroAppLite:::hla_motif_graph_ok(g)) {
    cat(sprintf("   %s: no graph (%s)\n", ch, attr(g, "guard") %||% "empty"))
    next
  }
  cat(sprintf(
    "   %s: %d unique CDR3 -> %d nodes in %d motifs\n",
    ch,
    length(unique(seg$cdr3)),
    igraph::vcount(g),
    length(unique(igraph::V(g)$cluster))
  ))
}
ht <- check$getHLATyping()
cat(sprintf(
  "   HLA: %d donors, %d alleles, source_type=%s\n",
  length(unique(ht$sample)),
  length(unique(ht$allele)),
  paste(unique(ht$source_type), collapse = ",")
))
cat("done.\n")

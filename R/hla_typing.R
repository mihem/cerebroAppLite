# ============================================================================
# HLA typing: canonical long-table contract + normalization
# ============================================================================
# The single persistence contract for HLA typing is a canonical LONG table (one
# row per sample x locus x copy), carrying data provenance so the app never
# mistakes an uploaded / imputed / synthetic genotype for a directly typed one.
# named-list and wide inputs are accepted only as adapters that normalize INTO
# this long table.
#
# See tmp/DESIGN-hla-motif-network.md §6 for the rationale (provenance,
# donor != cell, "context not restriction").
#
# These functions are Shiny-independent, installed and unit-testable.
# ============================================================================

## ---- Canonical schema -------------------------------------------------- ##
HLA_TYPING_COLUMNS <- c(
  "sample",
  "donor_id",
  "locus",
  "copy",
  "allele",
  "resolution",
  "source_type",
  "typing_method",
  "source_reference",
  "confidence"
)

## `source_type` describes how the genotype was obtained (evidence quality),
## NOT how it entered the app (that is the input channel: R API / seurat misc /
## upload). Only `genotyped` is eligible for confirmatory downstream analysis.
HLA_SOURCE_TYPES <- c("genotyped", "imputed", "synthetic", "unknown")

## MVP-interpretable loci. Others may be stored but are flagged "stored, not
## interpreted" — DQ/DP need heterodimer pairing rules; HLA-E is non-classical.
HLA_MVP_LOCI <- c("HLA-A", "HLA-B", "HLA-C", "HLA-DRB1")
HLA_CLASS_I_LOCI <- c("HLA-A", "HLA-B", "HLA-C")
HLA_CLASS_II_LOCI <- c(
  "HLA-DRB1",
  "HLA-DRB3",
  "HLA-DRB4",
  "HLA-DRB5",
  "HLA-DQA1",
  "HLA-DQB1",
  "HLA-DPA1",
  "HLA-DPB1"
)

#' Normalize one raw allele token to canonical `HLA-<locus>*<fields>`
#'
#' Accepts `A*02:01`, `HLA-A*02:01`, or a bare `02:01` when `locus` is supplied.
#' `NNNN` / empty / `NA` become NA (missing). Field resolution is preserved
#' (never auto-padded). Returns NA for anything unrecognisable; the caller logs
#' it as a QC warning rather than silently dropping it.
#'
#' @param x A raw allele token.
#' @param locus Optional locus (e.g. "HLA-A") for bare `02:01` inputs.
#' @return A canonical allele string, or NA_character_.
#' @keywords internal
hla_normalize_allele <- function(x, locus = NULL) {
  if (is.null(x) || length(x) != 1) {
    return(NA_character_)
  }
  x <- trimws(as.character(x))
  if (is.na(x) || !nzchar(x) || toupper(x) %in% c("NA", "NNNN", "NONE", "-")) {
    return(NA_character_)
  }
  x <- toupper(x)
  x <- sub("^HLA-", "", x) # strip any HLA- prefix; re-added below
  # Split "<locus>*<fields>" if present.
  if (grepl("\\*", x)) {
    parts <- strsplit(x, "\\*")[[1]]
    loc <- parts[1]
    fields <- parts[2]
  } else {
    # bare fields like "02:01" need the caller's locus
    if (is.null(locus) || is.na(locus) || !nzchar(locus)) {
      return(NA_character_)
    }
    loc <- sub("^HLA-", "", toupper(trimws(locus)))
    fields <- x
  }
  # Field portion must look like colon-separated numeric fields, optionally with
  # a trailing expression suffix letter (N/L/S/C/A/Q). Resolution is preserved.
  if (!grepl("^[0-9]{1,3}(:[0-9]{1,3}){0,3}[NLSCAQ]?$", fields)) {
    return(NA_character_)
  }
  if (!grepl("^[A-Z0-9]+$", loc)) {
    return(NA_character_)
  }
  paste0("HLA-", loc, "*", fields)
}

#' Count the field resolution of a canonical allele (e.g. 2-field)
#' @keywords internal
hla_allele_resolution <- function(allele) {
  if (is.na(allele)) {
    return(NA_character_)
  }
  fields <- sub("^HLA-[A-Z0-9]+\\*", "", allele)
  fields <- sub("[NLSCAQ]$", "", fields)
  n <- length(strsplit(fields, ":", fixed = TRUE)[[1]])
  paste0(n, "-field")
}

#' Locus of a canonical allele (e.g. "HLA-A")
#' @keywords internal
hla_allele_locus <- function(allele) {
  if (is.na(allele)) {
    return(NA_character_)
  }
  sub("\\*.*$", "", allele)
}

#' MHC class of a locus: "Class I" / "Class II" / "Other"
#' @keywords internal
hla_locus_class <- function(locus) {
  ifelse(
    locus %in% HLA_CLASS_I_LOCI,
    "Class I",
    ifelse(locus %in% HLA_CLASS_II_LOCI, "Class II", "Other")
  )
}

## ---- Long-table normalization ------------------------------------------ ##

# Turn a named list (sample -> allele vector, à la 57.R hla_by_patient) into a
# long data.frame of (sample, locus, allele) before canonicalisation.
.hla_named_list_to_long <- function(x) {
  do.call(
    rbind,
    lapply(names(x), function(s) {
      alleles <- x[[s]]
      if (length(alleles) == 0) {
        return(NULL)
      }
      data.frame(
        sample = s,
        allele_raw = as.character(alleles),
        stringsAsFactors = FALSE
      )
    })
  )
}

# Turn a wide table (sample column + one column per HLA-*_1 / HLA-*_2 slot, à la
# 57.R HLA_typing_v3.xlsx) into long (sample, locus, allele_raw).
.hla_wide_to_long <- function(df) {
  sample_col <- intersect(c("sample", "sample_ID", "patient_id"), colnames(df))
  if (length(sample_col) == 0) {
    stop("wide HLA table needs a 'sample' column", call. = FALSE)
  }
  sample_col <- sample_col[1]
  hla_cols <- grep("^HLA-", colnames(df), value = TRUE, ignore.case = TRUE)
  if (length(hla_cols) == 0) {
    stop("wide HLA table needs HLA-* columns", call. = FALSE)
  }
  do.call(
    rbind,
    lapply(hla_cols, function(col) {
      locus <- sub("_[12]$", "", col) # HLA-A_1 -> HLA-A
      data.frame(
        sample = as.character(df[[sample_col]]),
        locus_hint = locus,
        allele_raw = as.character(df[[col]]),
        stringsAsFactors = FALSE
      )
    })
  )
}

#' Normalize any accepted HLA input into the canonical long table
#'
#' Accepts:
#'   * a canonical/near-canonical long data.frame (has `sample` + `allele`);
#'   * a wide data.frame (`sample` + `HLA-A_1`, `HLA-A_2`, ... columns);
#'   * a named list (`sample -> c("HLA-A*02:01", ...)`).
#'
#' Output columns are exactly [HLA_TYPING_COLUMNS]. `copy` (1/2) is assigned per
#' (sample, locus) in input order. Unrecognisable alleles are dropped from the
#' table but reported via attribute "qc" (a data.frame of warnings). Provenance
#' defaults to `source_type = "unknown"` with a blocking warning when absent —
#' allele format is never used to guess `genotyped`.
#'
#' @param x One of the accepted inputs.
#' @param source_type One of [HLA_SOURCE_TYPES]; default "unknown".
#' @param typing_method,source_reference Optional provenance strings.
#' @return A canonical long data.frame with a "qc" attribute (warnings df).
#' @export
hla_normalize_typing <- function(
  x,
  source_type = "unknown",
  typing_method = NA_character_,
  source_reference = NA_character_
) {
  qc <- data.frame(
    sample = character(0),
    value = character(0),
    issue = character(0),
    stringsAsFactors = FALSE
  )
  add_qc <- function(sample, value, issue) {
    qc <<- rbind(
      qc,
      data.frame(
        sample = sample,
        value = value,
        issue = issue,
        stringsAsFactors = FALSE
      )
    )
  }

  if (!source_type %in% HLA_SOURCE_TYPES) {
    add_qc(NA, source_type, "unknown source_type; treated as 'unknown'")
    source_type <- "unknown"
  }

  # Dispatch input shape -> a long frame with columns (sample, allele_raw) and
  # optionally locus_hint.
  long <- NULL
  if (is.list(x) && !is.data.frame(x)) {
    long <- .hla_named_list_to_long(x)
    if (!is.null(long)) {
      long$locus_hint <- NA_character_
    }
  } else if (is.data.frame(x)) {
    if (all(c("sample", "allele") %in% colnames(x))) {
      # already long-ish
      long <- data.frame(
        sample = as.character(x$sample),
        locus_hint = if ("locus" %in% colnames(x)) {
          as.character(x$locus)
        } else {
          NA_character_
        },
        allele_raw = as.character(x$allele),
        stringsAsFactors = FALSE
      )
    } else {
      long <- .hla_wide_to_long(x)
    }
  } else {
    stop(
      "HLA typing must be a named list or a data.frame",
      call. = FALSE
    )
  }

  if (is.null(long) || nrow(long) == 0) {
    out <- .hla_empty_long()
    attr(out, "qc") <- qc
    return(out)
  }

  # Canonicalise each allele; locus comes from the token or the hint.
  canon <- vapply(
    seq_len(nrow(long)),
    function(i) {
      hla_normalize_allele(long$allele_raw[i], locus = long$locus_hint[i])
    },
    character(1)
  )
  bad <- is.na(canon) &
    !is.na(long$allele_raw) &
    !toupper(trimws(long$allele_raw)) %in% c("NA", "NNNN", "", "NONE", "-")
  if (any(bad)) {
    for (i in which(bad)) {
      add_qc(long$sample[i], long$allele_raw[i], "unrecognisable allele")
    }
  }
  keep <- !is.na(canon)
  if (!any(keep)) {
    out <- .hla_empty_long()
    attr(out, "qc") <- qc
    return(out)
  }
  df <- data.frame(
    sample = long$sample[keep],
    allele = canon[keep],
    stringsAsFactors = FALSE
  )
  df$locus <- vapply(df$allele, hla_allele_locus, character(1))
  df$resolution <- vapply(df$allele, hla_allele_resolution, character(1))

  # Assign copy 1/2 within (sample, locus) in input order; flag >2 as conflict.
  df$copy <- NA_integer_
  for (key in unique(paste(df$sample, df$locus))) {
    idx <- which(paste(df$sample, df$locus) == key)
    # de-duplicate identical alleles first (keep, but they occupy one copy slot)
    uniq_alleles <- df$allele[idx]
    copy_ids <- seq_along(idx)
    if (length(idx) > 2) {
      add_qc(
        df$sample[idx[1]],
        paste(uniq_alleles, collapse = ","),
        sprintf("> 2 alleles at %s; extra copies flagged", df$locus[idx[1]])
      )
    }
    df$copy[idx] <- copy_ids
  }
  df$copy[df$copy > 2L] <- NA_integer_ # keep row but mark copy unknown

  out <- data.frame(
    sample = df$sample,
    donor_id = NA_character_,
    locus = df$locus,
    copy = df$copy,
    allele = df$allele,
    resolution = df$resolution,
    source_type = source_type,
    typing_method = typing_method,
    source_reference = source_reference,
    confidence = NA_real_,
    stringsAsFactors = FALSE
  )
  out <- out[, HLA_TYPING_COLUMNS, drop = FALSE]
  rownames(out) <- NULL
  if (identical(source_type, "unknown")) {
    add_qc(
      NA,
      NA,
      "source_type is 'unknown'; descriptive context only, no association"
    )
  }
  attr(out, "qc") <- qc
  out
}

# An empty canonical long table with the right columns/types.
.hla_empty_long <- function() {
  out <- data.frame(
    sample = character(0),
    donor_id = character(0),
    locus = character(0),
    copy = integer(0),
    allele = character(0),
    resolution = character(0),
    source_type = character(0),
    typing_method = character(0),
    source_reference = character(0),
    confidence = numeric(0),
    stringsAsFactors = FALSE
  )
  out[, HLA_TYPING_COLUMNS, drop = FALSE]
}

#' Is a value a valid canonical HLA long table?
#' @param x Candidate object.
#' @return TRUE when `x` is a data.frame with the canonical columns.
#' @keywords internal
hla_is_typing_table <- function(x) {
  is.data.frame(x) && all(HLA_TYPING_COLUMNS %in% colnames(x))
}

#' Carrier index: which samples carry each allele
#'
#' @param typing A canonical long table.
#' @return Named list `allele -> character vector of samples`, or empty list.
#' @keywords internal
hla_carrier_index <- function(typing) {
  if (!hla_is_typing_table(typing) || nrow(typing) == 0) {
    return(list())
  }
  by_allele <- split(typing$sample, typing$allele)
  lapply(by_allele, function(s) sort(unique(s)))
}

## ---- Lineage-derived MHC context -------------------------------------- ##

#' Map a cell-type label to a lineage-derived MHC class context
#'
#' CD8 lineage -> "Class I", CD4 / Treg -> "Class II", everything else ->
#' "Unknown" (never guessed). This is explicitly a lineage-derived CONTEXT, not
#' a confirmed restriction; a coarse "T cells" label yields "Unknown".
#'
#' @param cell_type A character vector of cell-type labels.
#' @return A character vector of "Class I" / "Class II" / "Unknown".
#' @keywords internal
hla_lineage_context <- function(cell_type) {
  x <- as.character(cell_type)
  out <- rep("Unknown", length(x))
  out[grepl("(^|[^A-Za-z])CD8", x, ignore.case = TRUE)] <- "Class I"
  # CD4 or Treg -> Class II; checked after CD8 so a rare "CD4 CD8" label would
  # already be Class I (double-positive is not a conventional restriction).
  is_ii <- grepl("(^|[^A-Za-z])CD4", x, ignore.case = TRUE) |
    grepl("treg", x, ignore.case = TRUE)
  out[is_ii & out == "Unknown"] <- "Class II"
  out
}

#' Summarise a distribution of MHC-context labels to one node summary
#'
#' A CDR3 node carries cells of possibly mixed lineage. Collapse the per-cell
#' contexts to a single node summary: a single non-Unknown class stays that
#' class; both Class I and Class II present -> "Mixed"; only Unknown -> "Unknown".
#'
#' @param contexts A character vector of per-cell context labels.
#' @return One of "Class I" / "Class II" / "Mixed" / "Unknown".
#' @keywords internal
hla_context_summary <- function(contexts) {
  has_i <- any(contexts == "Class I")
  has_ii <- any(contexts == "Class II")
  if (has_i && has_ii) {
    return("Mixed")
  }
  if (has_i) {
    return("Class I")
  }
  if (has_ii) {
    return("Class II")
  }
  "Unknown"
}

## ---- Descriptive HLA carrier summaries (NO inferential statistics) ----- ##

#' Descriptive per-allele carrier summary over samples
#'
#' For each allele in the typing table, count how many of the given samples
#' carry it vs. do not, plus samples with no typing at all (untyped). This is a
#' strictly DESCRIPTIVE overlap; it performs no enrichment test and reports no
#' p-value. Association testing needs donor-level statistics and a pre-specified
#' analysis plan (see the design doc), which the MVP deliberately omits.
#'
#' @param typing A canonical long table.
#' @param samples Character vector of samples to consider (e.g. the IR samples).
#' @return data.frame(allele, locus, mhc_class, n_carrier, n_noncarrier,
#'   n_untyped, carriers) ordered by descending carrier count, or an empty frame.
#' @keywords internal
hla_allele_carrier_summary <- function(typing, samples) {
  if (
    !hla_is_typing_table(typing) || nrow(typing) == 0 || length(samples) == 0
  ) {
    return(data.frame(
      allele = character(0),
      locus = character(0),
      mhc_class = character(0),
      n_carrier = integer(0),
      n_noncarrier = integer(0),
      n_untyped = integer(0),
      carriers = character(0),
      stringsAsFactors = FALSE
    ))
  }
  typed_samples <- unique(typing$sample)
  ci <- hla_carrier_index(typing)
  alleles <- names(ci)
  out <- do.call(
    rbind,
    lapply(alleles, function(a) {
      carriers <- intersect(ci[[a]], samples)
      # non-carriers are typed samples in `samples` that lack the allele;
      # untyped samples are excluded from carrier/non-carrier (counted apart).
      typed_in_scope <- intersect(typed_samples, samples)
      noncarriers <- setdiff(typed_in_scope, carriers)
      untyped <- setdiff(samples, typed_samples)
      locus <- hla_allele_locus(a)
      data.frame(
        allele = a,
        locus = locus,
        mhc_class = hla_locus_class(locus),
        n_carrier = length(carriers),
        n_noncarrier = length(noncarriers),
        n_untyped = length(untyped),
        carriers = paste(sort(carriers), collapse = ", "),
        stringsAsFactors = FALSE
      )
    })
  )
  out <- out[order(-out$n_carrier, out$allele), , drop = FALSE]
  rownames(out) <- NULL
  out
}

#' Per-sample allele coverage summary (for the Data & QC tab)
#'
#' @param typing A canonical long table.
#' @return data.frame(sample, n_alleles, loci) or an empty frame.
#' @keywords internal
hla_coverage_by_sample <- function(typing) {
  if (!hla_is_typing_table(typing) || nrow(typing) == 0) {
    return(data.frame(
      sample = character(0),
      n_alleles = integer(0),
      loci = character(0),
      stringsAsFactors = FALSE
    ))
  }
  do.call(
    rbind,
    lapply(split(typing, typing$sample), function(d) {
      data.frame(
        sample = d$sample[1],
        n_alleles = length(unique(d$allele)),
        loci = paste(sort(unique(d$locus)), collapse = ", "),
        stringsAsFactors = FALSE
      )
    })
  )
}

# ============================================================================
# Descriptive HLA x TCR-feature overlap (no inferential statistics)
# ============================================================================

#' Resolve sample or donor as the descriptive analysis unit
#'
#' Donor-level collapse is used only when every in-scope sample has exactly one
#' non-empty donor ID. Otherwise all units remain samples; mixed donor/sample
#' counting is deliberately avoided.
#'
#' @param typing Canonical HLA typing table.
#' @param samples In-scope immune-repertoire sample names.
#' @return data.frame(sample, analysis_unit, unit_type).
#' @keywords internal
hla_analysis_unit_map <- function(typing, samples) {
  samples <- unique(as.character(samples))
  if (length(samples) == 0) {
    return(data.frame(
      sample = character(0),
      analysis_unit = character(0),
      unit_type = character(0),
      stringsAsFactors = FALSE
    ))
  }
  in_scope <- if (hla_is_typing_table(typing)) {
    typing[typing$sample %in% samples, , drop = FALSE]
  } else {
    .hla_empty_long()
  }
  donor_by_sample <- vapply(
    samples,
    function(s) {
      donors <- unique(as.character(in_scope$donor_id[
        in_scope$sample == s &
          !is.na(in_scope$donor_id) &
          nzchar(as.character(in_scope$donor_id))
      ]))
      if (length(donors) == 1) donors else NA_character_
    },
    character(1)
  )
  use_donor <- all(!is.na(donor_by_sample))
  data.frame(
    sample = samples,
    analysis_unit = if (use_donor) unname(donor_by_sample) else samples,
    unit_type = if (use_donor) "donor" else "sample",
    stringsAsFactors = FALSE
  )
}

#' Classify each analysis unit for one HLA allele
#'
#' Non-carrier means the allele's locus was typed and the allele was absent.
#' Missing locus typing is always reported separately as untyped.
#'
#' @param typing Canonical HLA typing table.
#' @param samples In-scope immune-repertoire sample names.
#' @param allele Canonical or normalizable HLA allele.
#' @return data.frame(analysis_unit, unit_type, hla_status).
#' @keywords internal
hla_allele_status_by_unit <- function(typing, samples, allele) {
  allele <- hla_normalize_allele(allele)
  if (is.na(allele)) {
    stop("allele must be a recognizable HLA allele", call. = FALSE)
  }
  unit_map <- hla_analysis_unit_map(typing, samples)
  units <- unique(unit_map[, c("analysis_unit", "unit_type"), drop = FALSE])
  units$hla_status <- "untyped"
  if (!hla_is_typing_table(typing) || nrow(typing) == 0 || nrow(units) == 0) {
    return(units)
  }

  in_scope <- typing[typing$sample %in% unit_map$sample, , drop = FALSE]
  sample_to_unit <- stats::setNames(unit_map$analysis_unit, unit_map$sample)
  locus <- hla_allele_locus(allele)
  locus_rows <- in_scope[in_scope$locus == locus, , drop = FALSE]
  typed_units <- unique(unname(sample_to_unit[locus_rows$sample]))
  carrier_units <- unique(unname(sample_to_unit[
    locus_rows$sample[locus_rows$allele == allele]
  ]))
  units$hla_status[units$analysis_unit %in% typed_units] <- "non-carrier"
  units$hla_status[units$analysis_unit %in% carrier_units] <- "carrier"
  units
}

#' Per-node HLA carrier status for one allele (render-time, cache-safe)
#'
#' Maps each motif node to the carrier status of the samples it was observed in,
#' for ONE allele. Deliberately a render-time helper: it takes the node's sample
#' set (`samples_all`, an allele-independent node attribute) rather than being
#' baked into the graph, so switching allele re-colours without rebuilding the
#' Hamming graph.
#'
#' A node aggregates cells from possibly several samples, so the status is a
#' summary of those samples' statuses:
#'   - "Carrier"      every sample carrying this node carries the allele;
#'   - "Non-carrier"  every such sample was locus-typed and lacks the allele;
#'   - "Mixed"        both carriers and non-carriers carry this node;
#'   - "Untyped"      no carrying sample has typing at the allele's locus.
#' A node seen in untyped samples plus carriers is "Mixed" only when a
#' non-carrier is also present; untyped alone never invents a class.
#'
#' This is candidate co-occurrence, NOT restriction: a carrier's TCR is not
#' thereby restricted by that allele.
#'
#' @param samples_all Character vector, one entry per node: a comma-separated
#'   sorted sample list (the `samples_all` node attribute).
#' @param typing Canonical HLA typing table.
#' @param samples In-scope immune-repertoire sample names.
#' @param allele Canonical or normalizable HLA allele.
#' @return Character vector, one status per node.
#' @keywords internal
hla_node_carrier_status <- function(samples_all, typing, samples, allele) {
  n <- length(samples_all)
  if (n == 0) {
    return(character(0))
  }
  status <- tryCatch(
    hla_allele_status_by_unit(typing, samples, allele),
    error = function(e) NULL
  )
  if (is.null(status) || nrow(status) == 0) {
    return(rep("Untyped", n))
  }
  # Samples map to analysis units (donor when donor mapping is complete), so
  # resolve each node's samples through the same unit map the tables use.
  unit_map <- hla_analysis_unit_map(typing, samples)
  sample_to_unit <- stats::setNames(unit_map$analysis_unit, unit_map$sample)
  unit_status <- stats::setNames(status$hla_status, status$analysis_unit)

  vapply(
    samples_all,
    function(s) {
      if (is.na(s) || !nzchar(s)) {
        return("Untyped")
      }
      smp <- strsplit(s, ",", fixed = TRUE)[[1]]
      st <- unname(unit_status[unname(sample_to_unit[smp])])
      st <- st[!is.na(st)]
      if (length(st) == 0) {
        return("Untyped")
      }
      has_c <- any(st == "carrier")
      has_n <- any(st == "non-carrier")
      if (has_c && has_n) {
        return("Mixed")
      }
      if (has_c) {
        return("Carrier")
      }
      if (has_n) {
        return("Non-carrier")
      }
      "Untyped"
    },
    character(1),
    USE.NAMES = FALSE
  )
}

#' Descriptive overlap of one HLA allele with a frozen TCR feature
#'
#' A feature is supplied as its member CDR3 strings (one node or all nodes in a
#' frozen motif component). The function reports per-unit presence, repertoire
#' breadth and cell fraction. It deliberately performs no hypothesis test.
#'
#' @param typing Canonical HLA typing table.
#' @param segments Parsed IR segments with `sample` and `cdr3` columns.
#' @param samples In-scope immune-repertoire sample names.
#' @param allele HLA allele to describe.
#' @param feature_cdr3 Character vector of CDR3 members in the frozen feature.
#' @param feature_v_gene Optional V gene per `feature_cdr3`. When supplied, the
#'   frozen feature is matched by `(V gene, CDR3)` rather than CDR3 alone.
#' @return Per-unit descriptive data.frame.
#' @keywords internal
hla_descriptive_feature_overlap <- function(
  typing,
  segments,
  samples,
  allele,
  feature_cdr3,
  feature_v_gene = NULL
) {
  if (
    !is.data.frame(segments) ||
      !all(c("sample", "cdr3") %in% colnames(segments))
  ) {
    stop("segments must contain sample and cdr3 columns", call. = FALSE)
  }
  unit_map <- hla_analysis_unit_map(typing, samples)
  status <- hla_allele_status_by_unit(typing, samples, allele)
  sample_to_unit <- stats::setNames(unit_map$analysis_unit, unit_map$sample)
  seg <- segments[segments$sample %in% unit_map$sample, , drop = FALSE]
  seg$analysis_unit <- unname(sample_to_unit[seg$sample])
  members <- unique(as.character(feature_cdr3))
  if (!is.null(feature_v_gene)) {
    if (
      !("v_gene" %in% colnames(seg)) ||
        length(feature_v_gene) != length(feature_cdr3)
    ) {
      stop(
        "V-specific features need segments$v_gene and one V gene per CDR3",
        call. = FALSE
      )
    }
    member_keys <- unique(paste(feature_v_gene, feature_cdr3, sep = "::"))
  } else {
    member_keys <- NULL
  }

  metrics <- do.call(
    rbind,
    lapply(unique(unit_map$analysis_unit), function(unit) {
      d <- seg[seg$analysis_unit == unit, , drop = FALSE]
      in_feature <- if (is.null(member_keys)) {
        d$cdr3 %in% members
      } else {
        paste(d$v_gene, d$cdr3, sep = "::") %in% member_keys
      }
      clone_keys <- if (is.null(member_keys)) {
        d$cdr3
      } else {
        paste(d$v_gene, d$cdr3, sep = "::")
      }
      n_cells <- nrow(d)
      n_feature_cells <- sum(in_feature)
      n_unique <- length(unique(clone_keys))
      n_feature_unique <- length(unique(clone_keys[in_feature]))
      data.frame(
        analysis_unit = unit,
        feature_present = n_feature_cells > 0,
        n_cells = as.integer(n_cells),
        n_feature_cells = as.integer(n_feature_cells),
        n_unique_clonotypes = as.integer(n_unique),
        n_feature_clonotypes = as.integer(n_feature_unique),
        unique_clonotype_fraction = if (n_unique > 0) {
          n_feature_unique / n_unique
        } else {
          NA_real_
        },
        cell_fraction = if (n_cells > 0) {
          n_feature_cells / n_cells
        } else {
          NA_real_
        },
        stringsAsFactors = FALSE
      )
    })
  )
  out <- merge(
    status,
    metrics,
    by = "analysis_unit",
    all.x = TRUE,
    sort = FALSE
  )
  out <- out[
    match(unique(unit_map$analysis_unit), out$analysis_unit),
    ,
    drop = FALSE
  ]
  rownames(out) <- NULL
  out
}

#' Build a descriptive analysis-unit by HLA-allele carrier matrix
#'
#' Cells are 1 for carrier, 0 for locus-typed non-carrier and NA when that locus
#' is untyped. No statistical operation is applied to the matrix.
#'
#' @param typing Canonical HLA typing table.
#' @param samples In-scope immune-repertoire sample names.
#' @return data.frame with analysis-unit metadata followed by allele columns.
#' @keywords internal
hla_unit_allele_matrix <- function(typing, samples) {
  unit_map <- hla_analysis_unit_map(typing, samples)
  out <- unique(unit_map[, c("analysis_unit", "unit_type"), drop = FALSE])
  if (!hla_is_typing_table(typing) || nrow(typing) == 0 || nrow(out) == 0) {
    return(out)
  }
  alleles <- sort(unique(typing$allele[typing$sample %in% unit_map$sample]))
  for (allele in alleles) {
    status <- hla_allele_status_by_unit(typing, samples, allele)
    values <- c("carrier" = 1L, "non-carrier" = 0L, "untyped" = NA_integer_)
    out[[allele]] <- unname(values[
      status$hla_status[match(out$analysis_unit, status$analysis_unit)]
    ])
  }
  out
}

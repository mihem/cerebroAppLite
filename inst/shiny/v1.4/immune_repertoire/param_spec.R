## ---------------------------------------------------------------------------
## IR_PARAM_SPEC — per-function analysis parameters (scRepertoire 2.6.2)
##
## Drives the dynamic "function-specific" settings panel: each visualization
## tab shows exactly the analysis parameters of its scRepertoire function.
## Pure output/style params (input.data, exportTable, palette) are excluded;
## order.by and specific-clone selectors are deferred.
##
## Each entry: tab label -> list of param specs. Each param spec:
##   id      : input id (ir_p_<param>)
##   label   : UI label
##   type    : "select" | "numeric" | "checkbox"
##   choices : for select — either a character vector, or one of the dynamic
##             tokens "<<groups>>" (metadata grouping columns) /
##             "<<genes>>" (gene-segment families)
##   value   : default value (must match the scRepertoire default)
##   min/max/step : for numeric
## ---------------------------------------------------------------------------

IR_PARAM_SPEC <- list(
  "Diversity" = list(
    list(
      id = "ir_p_metric", label = "Metric:", type = "select",
      choices = c(
        "shannon", "inv.simpson", "gini.simpson", "norm.entropy",
        "pielou", "ace", "chao1", "gini", "d50", "hill0", "hill1", "hill2"
      ),
      value = "shannon"
    ),
    list(
      id = "ir_p_x_axis", label = "X axis (metadata):", type = "select",
      choices = "<<groups>>", value = ""
    ),
    list(
      id = "ir_p_n_boots", label = "Bootstrap iterations:", type = "numeric",
      value = 20, min = 3, max = 100, step = 1
    )
  ),

  "Scatter" = list(
    list(
      id = "ir_p_graph", label = "Graph:", type = "select",
      choices = c("proportion", "count"), value = "proportion"
    ),
    list(
      id = "ir_p_dot_size", label = "Dot size:", type = "select",
      choices = c("total", "x", "y"), value = "total"
    )
  ),

  "vizGenes" = list(
    list(
      id = "ir_p_vg_x_axis", label = "X axis (gene):", type = "select",
      choices = "<<genes>>", value = "TRBV"
    ),
    list(
      id = "ir_p_vg_plot", label = "Plot:", type = "select",
      choices = c("heatmap", "barplot"), value = "heatmap"
    ),
    list(
      id = "ir_p_vg_summary", label = "Summary:", type = "select",
      choices = c("percent", "proportion", "count"), value = "percent"
    )
  ),

  "Overlap" = list(
    list(
      id = "ir_p_overlap_method", label = "Method:", type = "select",
      choices = c("overlap", "morisita", "jaccard", "cosine", "raw"),
      value = "overlap"
    )
  ),

  "K-mer" = list(
    list(
      id = "ir_p_motif_length", label = "Motif length:", type = "numeric",
      value = 3, min = 1, max = 6, step = 1
    ),
    list(
      id = "ir_p_min_depth", label = "Min depth:", type = "numeric",
      value = 3, min = 1, max = 20, step = 1
    ),
    list(
      id = "ir_p_top_motifs", label = "Top motifs:", type = "select",
      choices = c("10", "20", "25", "30", "50", "75", "100"), value = "30"
    )
  ),

  ## ---- scale-only plots -------------------------------------------------
  "Abundance" = list(
    list(id = "ir_p_scale", label = "Scale (proportion):", type = "checkbox",
         value = FALSE)
  ),
  "Length" = list(
    list(id = "ir_p_scale", label = "Scale (proportion):", type = "checkbox",
         value = FALSE)
  ),
  "Quant" = list(
    list(id = "ir_p_scale", label = "Scale (proportion):", type = "checkbox",
         value = FALSE)
  ),

  ## ---- clonal structure -------------------------------------------------
  "Proportion" = list(
    list(id = "ir_p_clonal_split", label = "Clonal split (comma-separated):",
         type = "text", value = "10, 100, 1000, 10000, 30000, 100000")
  ),
  "Rarefaction" = list(
    list(id = "ir_p_rare_plot_type", label = "Plot type:", type = "select",
         choices = c("Sample-size" = "1", "Coverage" = "2",
                     "Sample completeness" = "3"), value = "1"),
    list(id = "ir_p_hill_numbers", label = "Hill number (q):", type = "select",
         choices = c("Richness (q=0)" = "0", "Shannon (q=1)" = "1",
                     "Simpson (q=2)" = "2"), value = "0"),
    list(id = "ir_p_rare_n_boots", label = "Bootstrap iterations:",
         type = "numeric", value = 20, min = 3, max = 100, step = 1)
  ),
  "SizeDist" = list(
    list(id = "ir_p_sd_method", label = "Clustering method:", type = "select",
         choices = c("ward.D2", "ward.D", "single", "complete", "average",
                     "mcquitty", "median", "centroid"), value = "ward.D2"),
    list(id = "ir_p_sd_threshold", label = "Threshold:", type = "numeric",
         value = 1, min = 1, max = 20, step = 1)
  ),
  "Compare" = list(
    list(id = "ir_p_compare_graph", label = "Graph:", type = "select",
         choices = c("alluvial", "area"), value = "alluvial"),
    list(id = "ir_p_compare_prop", label = "Proportion (vs counts):",
         type = "checkbox", value = TRUE),
    list(id = "ir_p_top_clones", label = "Top clones:", type = "numeric",
         value = 10, min = 1, max = 50, step = 1)
  ),

  ## ---- gene usage -------------------------------------------------------
  "Gene usage" = list(
    list(id = "ir_p_gu_genes", label = "Genes:", type = "select",
         choices = "<<genes>>", value = "TRBV"),
    list(id = "ir_p_gu_plot_type", label = "Plot type:", type = "select",
         choices = c("heatmap", "barplot"), value = "heatmap"),
    list(id = "ir_p_gu_summary", label = "Summary:", type = "select",
         choices = c("percent", "proportion", "count"), value = "percent")
  ),
  "percentGenes" = list(
    list(id = "ir_p_pg_gene", label = "Gene segment:", type = "select",
         choices = c("Vgene", "Dgene", "Jgene"), value = "Vgene"),
    list(id = "ir_p_pg_summary", label = "Summary:", type = "select",
         choices = c("percent", "proportion", "count"), value = "percent")
  ),
  "percentVJ" = list(
    list(id = "ir_p_vj_summary", label = "Summary:", type = "select",
         choices = c("percent", "proportion", "count"), value = "percent")
  ),

  ## ---- CDR3 amino-acid composition --------------------------------------
  "AA %" = list(
    list(id = "ir_p_aa_length", label = "AA length:", type = "numeric",
         value = 20, min = 5, max = 40, step = 1)
  ),
  "Entropy" = list(
    list(id = "ir_p_pe_aa_length", label = "AA length:", type = "numeric",
         value = 20, min = 5, max = 40, step = 1),
    list(id = "ir_p_pe_method", label = "Method:", type = "select",
         choices = c("shannon", "inv.simpson", "gini.simpson", "norm.entropy",
                     "pielou", "hill0", "hill1", "hill2"),
         value = "norm.entropy")
  ),
  # Property: method choices are detected at runtime (immApex availability),
  # resolved via the "<<property_methods>>" token in the settings panel. The id
  # stays ir_property_method so the existing renderer keeps working.
  "Property" = list(
    list(id = "ir_property_method", label = "Property method:", type = "select",
         choices = "<<property_methods>>", value = NULL),
    list(id = "ir_p_pp_aa_length", label = "AA length:", type = "numeric",
         value = 20, min = 5, max = 40, step = 1)
  )
)

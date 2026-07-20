##----------------------------------------------------------------------------##
## HLA & TCR Motifs — "Network data" table
##
## Presentation only. Node view = the vertices of the SAME graph object the
## Motif Network draws (hla_motif_graph()), so the table matches the picture by
## construction and is NOT bound by the render cap -- the graph is built even
## when too large to draw. Cell view = the per-cell scoped rows (hla_scoped_
## segments()) that feed the graph. No new data logic; both reuse existing
## reactives, so the table cannot drift from the graph.
##----------------------------------------------------------------------------##

## Desired columns -> display names, per grain. Columns absent from a given
## dataset/scope are dropped (intersect with what the data actually carries),
## the same defensive pattern as hla_node_meta_cols().
HLA_NETWORK_TABLE_NODE_COLS <- c(
  cdr3 = "CDR3",
  v_gene = "V",
  j_gene = "J",
  clone_count = "cells",
  cluster = "motif cluster",
  pair_allele = "allele side",
  mhc_context = "MHC context",
  samples_all = "samples",
  sample_origin = "sample origin"
)
HLA_NETWORK_TABLE_CELL_COLS <- c(
  sample = "sample",
  cell_type = "cell_type",
  cell_type_fine = "cell_type_fine",
  cdr3 = "CDR3",
  v_gene = "V",
  j_gene = "J",
  pair_allele = "allele side",
  mhc_context = "MHC context"
)

hla_network_table_grain <- reactive({
  g <- input$hla_table_grain
  if (is.null(g) || !nzchar(g)) "node" else g
})

## The data frame currently shown, already column-selected and renamed. NULL
## when there is nothing in scope / no graph, which the render treats as empty.
##
## BOTH grains are anchored on the SAME graph object the network draws, so the
## table can never show more than the picture. The node view is its vertices;
## the cell view is the scoped cells whose node survived into the graph -- the
## graph aggregates to unique CDR3 and drops singletons / sub-min-size motifs,
## so hla_scoped_segments() (every cell in scope) is a superset that must be
## filtered to graph membership, or "By cell" would list cells behind nodes the
## network never showed.
hla_network_table_data <- reactive({
  g <- hla_motif_graph()
  if (!hla_motif_graph_ok(g)) {
    return(NULL)
  }
  if (identical(hla_network_table_grain(), "cell")) {
    seg <- hla_scoped_segments()
    if (is.null(seg) || nrow(seg) == 0) {
      return(NULL)
    }
    # Node id = cdr3, or v_gene::cdr3 under "Split motifs by V gene" -- the same
    # key hla_aggregate_cdr3_nodes() uses for V(g)$name. Build it the same way
    # so the membership test matches the graph exactly.
    by_v <- isTRUE(hla_param("hla_by_v", hla_by_v_default()))
    seg_key <- if (by_v) {
      paste(seg$v_gene, seg$cdr3, sep = "::")
    } else {
      seg$cdr3
    }
    df <- seg[seg_key %in% igraph::V(g)$name, , drop = FALSE]
    map <- HLA_NETWORK_TABLE_CELL_COLS
  } else {
    df <- igraph::as_data_frame(g, what = "vertices")
    map <- HLA_NETWORK_TABLE_NODE_COLS
  }
  if (is.null(df) || nrow(df) == 0) {
    return(NULL)
  }
  keep <- intersect(names(map), colnames(df))
  out <- df[, keep, drop = FALSE]
  colnames(out) <- unname(map[keep])
  rownames(out) <- NULL
  out
})

output$hla_network_table <- DT::renderDataTable({
  df <- hla_network_table_data()
  if (is.null(df)) {
    df <- data.frame(Note = "No rows in the current network scope.")
  }
  # The multi-value "samples" column (a comma-separated donor list) is shown as
  # the first sample + an ellipsis, with the full list on hover via a title
  # attribute. Display only -- the render returns the raw value for every other
  # DataTables type, so search / sort and the CSV export keep the full list.
  # Only that column is left un-escaped (it emits a <span>); every other column
  # stays HTML-escaped.
  s_idx <- which(colnames(df) == "samples")
  col_defs <- list()
  escape_cols <- seq_len(ncol(df))
  if (length(s_idx) == 1) {
    escape_cols <- which(colnames(df) != "samples")
    col_defs <- list(list(
      targets = s_idx - 1L,
      render = DT::JS(
        "function(data, type, row) {",
        "  if (type !== 'display' || data === null) { return data; }",
        "  var parts = String(data).split(',');",
        "  if (parts.length <= 1) { return data; }",
        "  var full = String(data).replace(/\"/g, '&quot;');",
        "  return '<span title=\"' + full + '\">' +",
        "    parts[0] + '\\u2026</span>';",
        "}"
      )
    ))
  }
  DT::datatable(
    df,
    rownames = FALSE,
    filter = "top",
    escape = escape_cols,
    class = "display nowrap",
    options = list(
      pageLength = 25,
      scrollX = TRUE,
      columnDefs = col_defs
    )
  )
})

output$hla_network_download <- downloadHandler(
  filename = function() {
    paste0("hla_network_", hla_network_table_grain(), ".csv")
  },
  content = function(file) {
    df <- hla_network_table_data()
    if (is.null(df)) {
      df <- data.frame()
    }
    utils::write.csv(df, file, row.names = FALSE, na = "")
  }
)

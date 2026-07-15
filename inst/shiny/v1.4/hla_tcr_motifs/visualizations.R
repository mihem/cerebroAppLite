##----------------------------------------------------------------------------##
## HLA & TCR Motifs — visualization layer
##
## igraph -> visNetwork data + the renderVisNetwork output, plus the parameter
## and status panels. Colour / legend are applied HERE from the already-built
## graph, so changing colour never rebuilds the graph (see data.R).
##----------------------------------------------------------------------------##

## Above this many colour levels a per-cluster legend is unreadable noise, so it
## is suppressed (metadata legends are unaffected).
HLA_MOTIF_MAX_LEGEND_CLUSTERS <- 12

## Categorical palette shared by nodes and the legend (plotly/D3-ish).
HLA_MOTIF_PALETTE <- c(
  "#636EFA",
  "#EF553B",
  "#00CC96",
  "#AB63FA",
  "#FFA15A",
  "#19D3F3",
  "#FF6692",
  "#B6E880",
  "#FF97FF",
  "#FECB52"
)

## ---- HTML-escape helper ----------------------------------------------- ##
hla_esc <- function(x) {
  x <- as.character(x)
  x <- gsub("&", "&amp;", x, fixed = TRUE)
  x <- gsub("<", "&lt;", x, fixed = TRUE)
  gsub(">", "&gt;", x, fixed = TRUE)
}

## ---- Build visNetwork data from a motif igraph ------------------------- ##
## Node size = clone_count; colour follows `color_by` (a node attribute) or the
## motif cluster by default. Tooltip shows CDR3, clone size + fraction, motif
## cluster + consensus + DIAMETER (so a transitive component is never implied to
## be all-pairs <= 1), V/J, and the active colour column's distribution.
hla_build_motif_visnet <- function(graph, color_by = NULL, chain = NULL) {
  if (!hla_motif_graph_ok(graph)) {
    return(NULL)
  }
  va <- igraph::vertex_attr(graph)
  n <- igraph::vcount(graph)
  get_attr <- function(nm) if (nm %in% names(va)) va[[nm]] else rep(NA, n)

  color_col <- if (
    !is.null(color_by) && nzchar(color_by) && color_by %in% names(va)
  ) {
    color_by
  } else {
    "cluster"
  }

  cdr3 <- get_attr("name")
  clone_count <- get_attr("clone_count")
  v_gene <- get_attr("v_gene")
  j_gene <- get_attr("j_gene")
  consensus <- get_attr("motif_consensus")
  diameter <- get_attr("motif_diameter")
  topo_cluster <- as.character(get_attr("cluster"))

  # Explicit colour per level so nodes + legend share one palette.
  group_raw <- as.character(get_attr(color_col))
  levels_ord <- if (color_col == "cluster") {
    as.character(sort(unique(suppressWarnings(as.numeric(group_raw)))))
  } else {
    unique(group_raw[!is.na(group_raw)])
  }
  levels_ord <- levels_ord[!is.na(levels_ord)]
  pal <- HLA_MOTIF_PALETTE
  level_colors <- stats::setNames(
    pal[((seq_along(levels_ord) - 1) %% length(pal)) + 1],
    levels_ord
  )
  node_color <- unname(level_colors[group_raw])
  node_color[is.na(node_color)] <- "grey70"

  # Variable-residue label (letters at the consensus 'x' positions).
  node_label <- vapply(
    seq_len(n),
    function(i) hla_motif_variable_aa(cdr3[i], consensus[i]),
    character(1)
  )

  deg <- igraph::degree(graph)
  total_cells <- tryCatch(
    igraph::graph_attr(graph, "total_cells"),
    error = function(e) NA_real_
  )
  if (length(total_cells) != 1 || is.na(total_cells)) {
    total_cells <- NA_real_
  }
  # Distribution of the active colour column across a node's cells (only for
  # metadata colouring, and skipped for cell_type which has its own line).
  color_dist <- if (!color_col %in% c("cluster", "cell_type")) {
    get_attr(paste0(color_col, "_dist"))
  } else {
    rep(NA_character_, n)
  }
  cell_dist <- get_attr("cell_type_dist")

  titles <- vapply(
    seq_len(n),
    function(i) {
      frac <- if (
        !is.na(total_cells) && total_cells > 0 && !is.na(clone_count[i])
      ) {
        sprintf(" (%.1f%%)", 100 * clone_count[i] / total_cells)
      } else {
        ""
      }
      lines <- c(
        sprintf("<b>%s</b>", hla_esc(cdr3[i])),
        if (!is.na(consensus[i])) {
          sprintf(
            "Motif %s &middot; consensus %s &middot; diameter %s",
            hla_esc(topo_cluster[i]),
            hla_esc(consensus[i]),
            hla_esc(diameter[i])
          )
        },
        if (nzchar(node_label[i])) {
          sprintf("Variable residue: %s", hla_esc(node_label[i]))
        },
        sprintf("Clone size: %s%s", hla_esc(clone_count[i]), frac),
        sprintf("Neighbours: %s", hla_esc(deg[i])),
        if (!is.na(cell_dist[i])) hla_esc(cell_dist[i]),
        if (!is.na(color_dist[i])) {
          sprintf("%s: %s", hla_esc(color_col), hla_esc(color_dist[i]))
        },
        if (!is.null(chain)) sprintf("Chain: %s", hla_esc(chain)),
        sprintf("V/J: %s / %s", hla_esc(v_gene[i]), hla_esc(j_gene[i]))
      )
      paste(lines[!vapply(lines, is.null, logical(1))], collapse = "<br>")
    },
    character(1)
  )

  nodes <- data.frame(
    id = seq_len(n),
    label = node_label,
    value = as.numeric(clone_count),
    group = group_raw,
    color = node_color,
    title = titles,
    font.size = 16,
    font.color = "#2a3f5f",
    font.vadjust = -20,
    stringsAsFactors = FALSE
  )

  el <- igraph::as_edgelist(graph, names = FALSE)
  edges <- if (nrow(el) == 0) {
    data.frame(from = integer(0), to = integer(0), stringsAsFactors = FALSE)
  } else {
    data.frame(from = el[, 1], to = el[, 2], stringsAsFactors = FALSE)
  }

  n_levels <- length(levels_ord)
  hide_legend <- color_col == "cluster" &&
    n_levels > HLA_MOTIF_MAX_LEGEND_CLUSTERS
  legend <- if (hide_legend) {
    NULL
  } else {
    data.frame(
      label = if (color_col == "cluster") {
        paste("Motif", levels_ord)
      } else {
        levels_ord
      },
      color = unname(level_colors[levels_ord]),
      shape = "dot",
      stringsAsFactors = FALSE
    )
  }

  n_multi <- sum(igraph::components(graph)$csize >= 2)
  subtitle <- sprintf(
    "%d CDR3 in %d motif(s). Edge = Hamming distance 1.",
    n,
    n_multi
  )

  list(
    nodes = nodes,
    edges = edges,
    legend = legend,
    legend_title = if (color_col == "cluster") "Motif cluster" else color_col,
    subtitle = subtitle,
    n_render = n
  )
}

## ---- The interactive motif network ------------------------------------ ##
output$hla_plot_motifNetwork <- visNetwork::renderVisNetwork({
  if (!hla_has_deps()) {
    return(NULL)
  }
  g <- hla_motif_graph()
  # A tripped size guard returns NA carrying a message; surface it as a note
  # (handled by output$hla_motif_note) and draw nothing.
  if (!hla_motif_graph_ok(g)) {
    return(NULL)
  }
  color_by <- hla_param("hla_color_by", "")
  vn <- hla_build_motif_visnet(g, color_by = color_by, hla_active_chain())
  if (is.null(vn)) {
    return(NULL)
  }

  # Physics is disabled above the render-size guard, so large graphs settle
  # instantly instead of freezing the browser.
  use_physics <- vn$n_render <= HLA_MOTIF_MAX_RENDER

  net <- visNetwork::visNetwork(
    vn$nodes,
    vn$edges
  )
  net <- visNetwork::visNodes(
    net,
    scaling = list(min = 8, max = 40),
    shape = "dot"
  )
  net <- visNetwork::visEdges(net, color = list(color = "#cccccc"))
  net <- visNetwork::visPhysics(
    net,
    enabled = use_physics,
    stabilization = list(iterations = 150)
  )
  net <- visNetwork::visInteraction(
    net,
    hover = TRUE,
    tooltipDelay = 100,
    navigationButtons = TRUE
  )
  if (!is.null(vn$legend)) {
    net <- visNetwork::visLegend(
      net,
      addNodes = vn$legend,
      useGroups = FALSE,
      main = vn$legend_title,
      position = "right",
      width = 0.15
    )
  }
  net
})

## ---- Note under the network (guard messages / empty state) ------------- ##
output$hla_motif_note <- renderUI({
  if (!hla_has_deps()) {
    return(tags$p(
      class = "text-muted",
      "The motif network requires the 'visNetwork' and 'stringdist' packages."
    ))
  }
  seg <- hla_segments()
  if (is.null(seg) || nrow(seg) == 0) {
    return(tags$p(
      class = "text-muted",
      sprintf(
        "No %s cells with a complete V / J / CDR3 to build a network.",
        hla_active_chain()
      )
    ))
  }
  g <- hla_motif_graph()
  guard <- attr(g, "guard")
  if (!is.null(guard)) {
    return(tags$p(class = "text-danger", guard))
  }
  if (!hla_motif_graph_ok(g)) {
    return(tags$p(
      class = "text-muted",
      paste(
        "No CDR3 motif clusters at Hamming distance 1 with the current",
        "settings. Try lowering the minimum motif size or enabling",
        "'Show unconnected CDR3s'."
      )
    ))
  }
  tags$p(
    class = "text-muted",
    style = "font-size: 12px; margin-top: 8px;",
    paste(
      "Nodes = unique CDR3; an edge joins two equal-length CDR3 at Hamming",
      "distance 1. A motif is a Hamming-1 connected component (membership can",
      "be transitive; the tooltip reports the component diameter). Node size",
      "= number of cells carrying that CDR3."
    )
  )
})

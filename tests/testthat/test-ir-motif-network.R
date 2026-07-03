# test-ir-motif-network.R — pure-function tests for the Motif Network tab.
# Lifts the motif algorithm helpers + builders out of data.R via a stub env,
# same approach as test-ir-definition-sharing.R.

rel_data_r <- "shiny/v1.4/immune_repertoire/data.R"
inst_candidates <- c(
  normalizePath("inst", mustWork = FALSE),
  normalizePath("../../inst", mustWork = FALSE),
  normalizePath(testthat::test_path("../../inst"), mustWork = FALSE)
)
local_inst <- inst_candidates[
  file.exists(file.path(inst_candidates, rel_data_r))
][1]
data_r <- if (!is.na(local_inst)) {
  file.path(local_inst, rel_data_r)
} else {
  system.file(rel_data_r, package = "cerebroAppLite")
}
testthat::skip_if_not(
  nzchar(data_r) && file.exists(data_r),
  "immune_repertoire/data.R not found"
)
skip_if_not_installed("stringdist")
skip_if_not_installed("igraph")

ir_env <- new.env()
ir_env$reactive <- function(x) function() NULL
ir_env$reactiveVal <- function(...) function(...) NULL
ir_env$req <- function(...) invisible(NULL)
ir_env$observeEvent <- function(...) invisible(NULL)
ir_env$`%||%` <- function(a, b) if (is.null(a)) b else a
for (nm in c(
  "getImmuneRepertoire",
  "getMetaData",
  "availableProjections",
  "getProjection",
  "detect_chains",
  "input",
  "session",
  "data_set"
)) {
  ir_env[[nm]] <- function(...) NULL
}
sys.source(data_r, envir = ir_env, keep.source = FALSE)

ir_make_consensus <- ir_env$ir_make_consensus
ir_motif_variable_aa <- ir_env$ir_motif_variable_aa
ir_process_length_group <- ir_env$ir_process_length_group
ir_build_motif_groups <- ir_env$ir_build_motif_groups
IR_MOTIF_MAX_LEGEND_CLUSTERS <- ir_env$IR_MOTIF_MAX_LEGEND_CLUSTERS

# Lift ir_apply_display out of server.R so we can test that the generic display
# hook does NOT clobber the legend.position a plot set for itself. server.R is
# full of reactive()/output$ top-level code that needs a live Shiny session, so
# we extract just the ir_apply_display definition rather than sourcing the file.
server_r <- if (!is.na(local_inst)) {
  file.path(local_inst, "shiny/v1.4/immune_repertoire/server.R")
} else {
  system.file(
    "shiny/v1.4/immune_repertoire/server.R",
    package = "cerebroAppLite"
  )
}
if (nzchar(server_r) && file.exists(server_r)) {
  src <- paste(readLines(server_r, warn = FALSE), collapse = "\n")
  # Grab the ir_apply_display <- function(...) { ... } block by brace-matching.
  start <- regexpr("ir_apply_display\\s*<-\\s*function", src)
  if (start > 0) {
    tail_src <- substring(src, start)
    open_brace <- regexpr("\\{", tail_src)
    depth <- 0L
    end_pos <- NA_integer_
    chars <- strsplit(substring(tail_src, open_brace), "")[[1]]
    for (i in seq_along(chars)) {
      if (chars[i] == "{") {
        depth <- depth + 1L
      } else if (chars[i] == "}") {
        depth <- depth - 1L
        if (depth == 0L) {
          end_pos <- i
          break
        }
      }
    }
    def <- substring(tail_src, 1, open_brace + end_pos - 1)
    eval(parse(text = def), envir = ir_env)
  }
}
ir_apply_display <- ir_env$ir_apply_display

test_that("ir_make_consensus marks differing positions with x", {
  expect_equal(ir_make_consensus(c("CASSL", "CASSF")), "CASSx")
  expect_equal(ir_make_consensus("CASSL"), "CASSL")
  expect_equal(ir_make_consensus(c("CASSL", "CASSL")), "CASSL")
})

test_that("ir_motif_variable_aa extracts residues at x positions", {
  expect_equal(ir_motif_variable_aa("CASSL", "CASSx"), "L")
  expect_equal(ir_motif_variable_aa("CASSF", "CASSx"), "F")
  expect_equal(ir_motif_variable_aa(NA_character_, "CASSx"), "")
})

test_that("ir_build_motif_groups clusters Hamming<=1 same-length CDR3s", {
  df <- data.frame(
    cdr3 = c("CASSL", "CASSF", "CASTL", "CWXYZ"),
    stringsAsFactors = FALSE
  )
  df$cdr3_length <- nchar(df$cdr3)
  res <- ir_build_motif_groups(df, by_v = FALSE, threshold = 1)
  sizes <- res$motif_df$motif_size[match(
    c("CASSL", "CASSF", "CASTL", "CWXYZ"),
    res$motif_df$cdr3
  )]
  expect_equal(sizes, c(3, 3, 3, 1))
  expect_true(!is.null(res$edges) && nrow(res$edges) >= 2)
})

test_that("ir_build_motif_groups does not connect different-length CDR3s", {
  df <- data.frame(cdr3 = c("CASSL", "CASSLL"), stringsAsFactors = FALSE)
  df$cdr3_length <- nchar(df$cdr3)
  res <- ir_build_motif_groups(df, by_v = FALSE, threshold = 1)
  expect_equal(unname(res$motif_df$motif_size), c(1, 1))
})

test_that("ir_build_motif_groups by_v keeps different-V CDR3s apart", {
  df <- data.frame(
    cdr3 = c("CASSL", "CASSL"),
    v_gene = c("TRBV1", "TRBV2"),
    stringsAsFactors = FALSE
  )
  df$cdr3_length <- nchar(df$cdr3)
  res <- ir_build_motif_groups(df, by_v = TRUE, threshold = 1)
  expect_equal(unname(res$motif_df$motif_size), c(1, 1))
})

test_that("ir_build_motif_groups handles a single-row length bin without crashing", {
  df <- data.frame(cdr3 = "CASSL", stringsAsFactors = FALSE)
  df$cdr3_length <- nchar(df$cdr3)
  res <- ir_build_motif_groups(df, by_v = FALSE, threshold = 1)
  expect_equal(unname(res$motif_df$motif_size), 1)
  expect_null(res$edges)
})

test_that("ir_build_motif_groups tags by_v edges with their V gene", {
  # Two CASSL/CASSF pairs, one per V gene: each V forms its own edge, and the
  # edge should carry the v_gene of its bin.
  df <- data.frame(
    cdr3 = c("CASSL", "CASSF", "CASSL", "CASSF"),
    v_gene = c("TRBV1", "TRBV1", "TRBV2", "TRBV2"),
    stringsAsFactors = FALSE
  )
  df$cdr3_length <- nchar(df$cdr3)
  res <- ir_build_motif_groups(df, by_v = TRUE, threshold = 1)
  expect_true("v_gene" %in% colnames(res$edges))
  expect_setequal(unique(res$edges$v_gene), c("TRBV1", "TRBV2"))
  expect_equal(nrow(res$edges), 2)
})

# --- ir_build_motif_graph --------------------------------------------------

test_that("ir_build_motif_graph builds a graph, drops isolates, keeps metadata", {
  data <- list(
    s1 = data.frame(
      barcode = paste0("b", 1:4),
      CTgene = c(
        "TRBV1..TRBJ1.TRBC1",
        "TRBV1..TRBJ1.TRBC1",
        "TRBV1..TRBJ1.TRBC1",
        "TRBV2..TRBJ2.TRBC2"
      ),
      CTaa = c("CASSL", "CASSF", "CASTL", "CWXYZ"),
      sample = c("s1", "s1", "s1", "s1"),
      stringsAsFactors = FALSE
    )
  )
  ir_build_motif_graph <- ir_env$ir_build_motif_graph
  g <- ir_build_motif_graph(
    data,
    chain = "TRB",
    threshold = 1,
    by_v = FALSE,
    min_size = 1
  )
  expect_true(inherits(g, "igraph"))
  expect_equal(igraph::vcount(g), 3)
  expect_true("cdr3" %in% igraph::vertex_attr_names(g))
  expect_true("sample" %in% igraph::vertex_attr_names(g))
})

test_that("ir_build_motif_graph returns NULL when no cluster survives", {
  data <- list(
    s1 = data.frame(
      barcode = c("b1", "b2"),
      CTgene = c("TRBV1..TRBJ1.TRBC1", "TRBV1..TRBJ1.TRBC1"),
      CTaa = c("CASSL", "CWXYZ"),
      sample = c("s1", "s1"),
      stringsAsFactors = FALSE
    )
  )
  ir_build_motif_graph <- ir_env$ir_build_motif_graph
  g <- ir_build_motif_graph(
    data,
    chain = "TRB",
    threshold = 1,
    by_v = FALSE,
    min_size = 1
  )
  expect_null(g)
})

test_that("ir_build_motif_graph min_size drops small clusters", {
  data <- list(
    s1 = data.frame(
      barcode = paste0("b", 1:2),
      CTgene = c("TRBV1..TRBJ1.TRBC1", "TRBV1..TRBJ1.TRBC1"),
      CTaa = c("CASSL", "CASSF"),
      sample = c("s1", "s1"),
      stringsAsFactors = FALSE
    )
  )
  ir_build_motif_graph <- ir_env$ir_build_motif_graph
  g <- ir_build_motif_graph(
    data,
    chain = "TRB",
    threshold = 1,
    by_v = FALSE,
    min_size = 2
  )
  expect_null(g)
})

test_that("ir_build_motif_graph keeps j_gene and a cell_type distribution", {
  # Two cells share CDR3 CASSL but differ in cell_type; CASSF is a Hamming-1
  # neighbour so the pair forms a cluster.
  data <- list(
    s1 = data.frame(
      barcode = paste0("b", 1:3),
      CTgene = c(
        "TRBV1..TRBJ1.TRBC1",
        "TRBV1..TRBJ1.TRBC1",
        "TRBV1..TRBJ1.TRBC1"
      ),
      CTaa = c("CASSL", "CASSL", "CASSF"),
      sample = c("s1", "s1", "s1"),
      cell_type = c("CD8 T", "CD4 T", "CD8 T"),
      stringsAsFactors = FALSE
    )
  )
  ir_build_motif_graph <- ir_env$ir_build_motif_graph
  g <- ir_build_motif_graph(
    data,
    chain = "TRB",
    threshold = 1,
    by_v = FALSE,
    min_size = 1
  )
  expect_true(inherits(g, "igraph"))
  expect_true("j_gene" %in% igraph::vertex_attr_names(g))
  expect_true("cell_type_dist" %in% igraph::vertex_attr_names(g))
  va <- igraph::vertex_attr(g)
  cassl_dist <- va$cell_type_dist[va$name == "CASSL"]
  expect_match(cassl_dist, "2 types")
  expect_match(cassl_dist, "CD8 T")
  expect_match(cassl_dist, "CD4 T")
})

# --- ir_build_motif_plot ---------------------------------------------------

test_that("ir_build_motif_plot returns a ggplot for a valid graph", {
  skip_if_not_installed("ggraph")
  data <- list(
    s1 = data.frame(
      barcode = paste0("b", 1:3),
      CTgene = rep("TRBV1..TRBJ1.TRBC1", 3),
      CTaa = c("CASSL", "CASSF", "CASTL"),
      sample = c("s1", "s1", "s1"),
      stringsAsFactors = FALSE
    )
  )
  ir_build_motif_graph <- ir_env$ir_build_motif_graph
  ir_build_motif_plot <- ir_env$ir_build_motif_plot
  g <- ir_build_motif_graph(
    data,
    chain = "TRB",
    threshold = 1,
    by_v = FALSE,
    min_size = 1
  )
  p <- ir_build_motif_plot(g, color_by = NULL)
  expect_s3_class(p, "ggplot")
  # ggplot objects are lazy; force a full build so rendering-time errors
  # (broken aes, deprecated geom args) are actually caught by CI.
  built <- ggplot2::ggplot_build(p)
  expect_s3_class(built, "ggplot_built")
  expect_gt(nrow(built$data[[which.max(lengths(built$data))]]), 0)
})

test_that("ir_build_motif_plot returns NULL for a NULL graph", {
  ir_build_motif_plot <- ir_env$ir_build_motif_plot
  expect_null(ir_build_motif_plot(NULL, color_by = NULL))
})

# --- ir_build_motif_visnet -------------------------------------------------

test_that("ir_build_motif_visnet builds nodes/edges with tooltips", {
  skip_if_not_installed("igraph")
  data <- list(
    s1 = data.frame(
      barcode = paste0("b", 1:4),
      CTgene = rep("TRBV1..TRBJ1.TRBC1", 4),
      CTaa = c("CASSL", "CASSL", "CASSF", "CASSF"),
      sample = c("s1", "s1", "s1", "s1"),
      cell_type = c("CD8 T", "CD4 T", "CD8 T", "CD8 T"),
      stringsAsFactors = FALSE
    )
  )
  ir_build_motif_graph <- ir_env$ir_build_motif_graph
  ir_build_motif_visnet <- ir_env$ir_build_motif_visnet
  g <- ir_build_motif_graph(
    data,
    chain = "TRB",
    threshold = 1,
    by_v = FALSE,
    min_size = 1
  )
  vn <- ir_build_motif_visnet(g, color_by = NULL, chain = "TRB")
  expect_true(all(c("nodes", "edges") %in% names(vn)))
  real <- vn$nodes[vn$nodes$shape == "dot", ]
  titles_n <- vn$nodes[vn$nodes$shape == "text", ]
  # One real point per CDR3 node in the graph.
  expect_equal(nrow(real), igraph::vcount(g))
  # Each real point is labelled with only its VARIABLE residue at the consensus
  # 'x' position: CASSL -> "L", CASSF -> "F".
  expect_setequal(real$label, c("L", "F"))
  # The consensus (CASSL + CASSF -> "CASSx") appears once, as a text title node.
  expect_equal(nrow(titles_n), 1)
  expect_equal(titles_n$label, "CASSx")
  # The full CDR3s live in the tooltip (title) of the real points.
  expect_true(all(grepl("CASS", real$title)))
  expect_true(any(grepl("Clone size", real$title)))
  expect_true(any(grepl("type", real$title)))
  # Extended tooltip fields (A + B).
  expect_true(all(grepl("Length: 5 aa", real$title)))
  expect_true(all(grepl("Motif cluster", real$title)))
  expect_true(all(grepl("Variable residue: [LF]", real$title)))
  expect_true(all(grepl("Neighbours: 1 &middot; cluster size 2", real$title)))
  # clone_count 2 of total 4 cells -> 50.0%.
  expect_true(all(grepl("Clone size: 2 \\(50.0%\\)", real$title)))
  # The title node is physics-free and tagged with the cluster it labels, so
  # the client can pin it over that cluster's points. No tether edge is added.
  expect_false(titles_n$physics)
  expect_true(titles_n$cl %in% real$cl)
  expect_equal(ncol(vn$edges), 2L)
})

test_that("ir_build_motif_visnet tooltip shows the active colour column's distribution", {
  skip_if_not_installed("igraph")
  # Two CDR3s in a cluster, each from a different sample -> colouring by sample
  # should surface a "sample: ..." distribution line in the tooltip.
  data <- list(
    s1 = data.frame(
      barcode = paste0("b", 1:2),
      CTgene = rep("TRBV1..TRBJ1.TRBC1", 2),
      CTaa = c("CASSL", "CASSF"),
      sample = c("sample_1", "sample_2"),
      cell_type = c("CD8 T", "CD4 T"),
      stringsAsFactors = FALSE
    )
  )
  ir_build_motif_graph <- ir_env$ir_build_motif_graph
  ir_build_motif_visnet <- ir_env$ir_build_motif_visnet
  g <- ir_build_motif_graph(
    data,
    chain = "TRB",
    threshold = 1,
    by_v = FALSE,
    min_size = 1
  )
  vn <- ir_build_motif_visnet(g, color_by = "sample", chain = "TRB")
  real <- vn$nodes[vn$nodes$shape == "dot", ]
  expect_true(any(grepl("sample: ", real$title)))
  # cluster colouring does NOT add a colour-distribution line.
  vn2 <- ir_build_motif_visnet(g, color_by = NULL, chain = "TRB")
  real2 <- vn2$nodes[vn2$nodes$shape == "dot", ]
  expect_false(any(grepl("cluster: ", real2$title)))
})

test_that("ir_build_motif_visnet titles only multi-node clusters", {
  skip_if_not_installed("igraph")
  # Two separate 2-node clusters + one isolated CDR3 (show_isolated) → two
  # consensus title nodes; the isolated CDDDD gets no title and no label.
  data <- list(
    s1 = data.frame(
      barcode = paste0("b", 1:5),
      CTgene = rep("TRBV1..TRBJ1.TRBC1", 5),
      CTaa = c("CASSL", "CASSF", "CWWWY", "CWWWH", "CDDDD"),
      sample = rep("s1", 5),
      stringsAsFactors = FALSE
    )
  )
  ir_build_motif_graph <- ir_env$ir_build_motif_graph
  ir_build_motif_visnet <- ir_env$ir_build_motif_visnet
  g <- ir_build_motif_graph(
    data,
    chain = "TRB",
    threshold = 1,
    by_v = FALSE,
    min_size = 1,
    show_isolated = TRUE
  )
  vn <- ir_build_motif_visnet(g, color_by = NULL, chain = "TRB")
  titles_n <- vn$nodes[vn$nodes$shape == "text", ]
  # Two multi-node clusters → two consensus title nodes.
  expect_equal(nrow(titles_n), 2)
  # The isolated singleton is neither titled nor variable-labelled.
  real <- vn$nodes[vn$nodes$shape == "dot", ]
  cdddd_label <- real$label[grepl("CDDDD", real$title)]
  expect_true(all(cdddd_label == ""))
})

test_that("ir_build_motif_visnet emits a size legend when clone sizes differ", {
  skip_if_not_installed("igraph")
  # CASSL appears in 5 cells (clone_count 5), CASSF in 1 (clone_count 1) -> the
  # two nodes differ in size, so a size legend spanning 1..5 is produced.
  data <- list(
    s1 = data.frame(
      barcode = paste0("b", 1:6),
      CTgene = rep("TRBV1..TRBJ1.TRBC1", 6),
      CTaa = c("CASSL", "CASSL", "CASSL", "CASSL", "CASSL", "CASSF"),
      sample = rep("s1", 6),
      stringsAsFactors = FALSE
    )
  )
  ir_build_motif_graph <- ir_env$ir_build_motif_graph
  ir_build_motif_visnet <- ir_env$ir_build_motif_visnet
  g <- ir_build_motif_graph(
    data,
    chain = "TRB",
    threshold = 1,
    by_v = FALSE,
    min_size = 1
  )
  vn <- ir_build_motif_visnet(g, color_by = NULL, chain = "TRB")
  expect_false(is.null(vn$size_legend))
  # Only representative values are returned; the swatch radius is read back from
  # vis on the client so the circles match the drawn points exactly.
  expect_true("value" %in% names(vn$size_legend))
  expect_false("radius" %in% names(vn$size_legend))
  # Spans the observed clone-size range (min 1, max 5).
  expect_equal(min(vn$size_legend$value), 1)
  expect_equal(max(vn$size_legend$value), 5)
})

test_that("ir_build_motif_visnet collapses the size legend to one row when all points match", {
  skip_if_not_installed("igraph")
  # Every CDR3 is one cell -> no clone-size variation -> a single-row legend
  # (still shown, so the point-size -> clone-size mapping is always explained).
  data <- list(
    s1 = data.frame(
      barcode = paste0("b", 1:2),
      CTgene = rep("TRBV1..TRBJ1.TRBC1", 2),
      CTaa = c("CASSL", "CASSF"),
      sample = rep("s1", 2),
      stringsAsFactors = FALSE
    )
  )
  ir_build_motif_graph <- ir_env$ir_build_motif_graph
  ir_build_motif_visnet <- ir_env$ir_build_motif_visnet
  g <- ir_build_motif_graph(
    data,
    chain = "TRB",
    threshold = 1,
    by_v = FALSE,
    min_size = 1
  )
  vn <- ir_build_motif_visnet(g, color_by = NULL, chain = "TRB")
  expect_false(is.null(vn$size_legend))
  expect_equal(nrow(vn$size_legend), 1)
  expect_equal(vn$size_legend$value, 1)
})

test_that("ir_build_motif_visnet returns NULL for a NULL graph", {
  ir_build_motif_visnet <- ir_env$ir_build_motif_visnet
  expect_null(ir_build_motif_visnet(NULL, color_by = NULL, chain = "TRB"))
})

test_that("ir_build_motif_visnet builds a palette-matched legend", {
  skip_if_not_installed("igraph")
  data <- list(
    s1 = data.frame(
      barcode = paste0("b", 1:4),
      CTgene = rep("TRBV1..TRBJ1.TRBC1", 4),
      CTaa = c("CASSL", "CASSL", "CASSF", "CASSF"),
      sample = c("s1", "s1", "s1", "s1"),
      cell_type = c("CD8 T", "CD4 T", "CD8 T", "CD8 T"),
      stringsAsFactors = FALSE
    )
  )
  ir_build_motif_graph <- ir_env$ir_build_motif_graph
  ir_build_motif_visnet <- ir_env$ir_build_motif_visnet
  g <- ir_build_motif_graph(
    data,
    chain = "TRB",
    threshold = 1,
    by_v = FALSE,
    min_size = 1
  )
  vn <- ir_build_motif_visnet(g, color_by = NULL, chain = "TRB")
  # Legend present with a title and one row per colour level.
  expect_true(all(c("legend", "legend_title") %in% names(vn)))
  expect_equal(vn$legend_title, "Motif cluster")
  expect_true(all(c("label", "color", "shape") %in% names(vn$legend)))
  expect_match(vn$legend$label[1], "Cluster")
  # Every real point's colour comes from the legend palette (they share it);
  # consensus title nodes are text-only and not palette-coloured.
  real <- vn$nodes[vn$nodes$shape == "dot", ]
  expect_true(all(real$color %in% vn$legend$color))
})

test_that("ir_build_motif_visnet titles the legend by the metadata column", {
  skip_if_not_installed("igraph")
  data <- list(
    s1 = data.frame(
      barcode = paste0("b", 1:3),
      CTgene = rep("TRBV1..TRBJ1.TRBC1", 3),
      CTaa = c("CASSL", "CASSF", "CASTL"),
      sample = c("a", "b", "a"),
      stringsAsFactors = FALSE
    )
  )
  ir_build_motif_graph <- ir_env$ir_build_motif_graph
  ir_build_motif_visnet <- ir_env$ir_build_motif_visnet
  g <- ir_build_motif_graph(
    data,
    chain = "TRB",
    threshold = 1,
    by_v = FALSE,
    min_size = 1
  )
  vn <- ir_build_motif_visnet(g, color_by = "sample", chain = "TRB")
  expect_equal(vn$legend_title, "sample")
  # Metadata legend labels are the raw values, not "Cluster N".
  expect_true(all(vn$legend$label %in% c("a", "b")))
})

test_that("ir_build_motif_visnet hides legend past the cluster threshold", {
  skip_if_not_installed("igraph")
  # Build many singleton clusters so the level count exceeds the threshold.
  ir_build_motif_visnet <- ir_env$ir_build_motif_visnet
  n <- IR_MOTIF_MAX_LEGEND_CLUSTERS + 3
  g <- igraph::make_empty_graph(n = n, directed = FALSE)
  igraph::V(g)$name <- paste0("C", seq_len(n))
  igraph::V(g)$cluster <- seq_len(n)
  igraph::V(g)$clone_count <- 1
  igraph::V(g)$v_gene <- "TRBV1"
  igraph::V(g)$j_gene <- "TRBJ1"
  igraph::V(g)$cell_type_dist <- NA_character_
  vn <- ir_build_motif_visnet(g, color_by = NULL, chain = "TRB")
  expect_true(vn$hide_legend)
})

test_that("ir_build_motif_plot adds BCR caveat subtitle for IGH", {
  skip_if_not_installed("ggraph")
  data <- list(
    s1 = data.frame(
      barcode = paste0("b", 1:3),
      CTgene = rep("IGHV1..IGHJ1.IGHG1", 3),
      CTaa = c("CARDL", "CARDF", "CARTL"),
      sample = c("s1", "s1", "s1"),
      stringsAsFactors = FALSE
    )
  )
  ir_build_motif_graph <- ir_env$ir_build_motif_graph
  ir_build_motif_plot <- ir_env$ir_build_motif_plot
  g <- ir_build_motif_graph(
    data,
    chain = "IGH",
    threshold = 1,
    by_v = FALSE,
    min_size = 1
  )
  p <- ir_build_motif_plot(g, color_by = NULL, chain = "IGH")
  expect_s3_class(p, "ggplot")
  expect_true(grepl("SHM", p$labels$subtitle %||% ""))
})

# --- ir_build_motif_graph show_isolated ------------------------------------

test_that("ir_build_motif_graph drops isolated CDR3s by default", {
  data <- list(
    s1 = data.frame(
      barcode = paste0("b", 1:4),
      CTgene = rep("TRBV1..TRBJ1.TRBC1", 4),
      CTaa = c("CASSL", "CASSF", "CASTL", "CWXYZ"),
      sample = rep("s1", 4),
      stringsAsFactors = FALSE
    )
  )
  ir_build_motif_graph <- ir_env$ir_build_motif_graph
  g <- ir_build_motif_graph(
    data,
    chain = "TRB",
    threshold = 1,
    by_v = FALSE,
    min_size = 1
  )
  # CWXYZ is isolated -> dropped; only the 3-node cluster remains.
  expect_equal(igraph::vcount(g), 3)
})

test_that("ir_build_motif_graph show_isolated keeps isolated CDR3s", {
  data <- list(
    s1 = data.frame(
      barcode = paste0("b", 1:4),
      CTgene = rep("TRBV1..TRBJ1.TRBC1", 4),
      CTaa = c("CASSL", "CASSF", "CASTL", "CWXYZ"),
      sample = rep("s1", 4),
      stringsAsFactors = FALSE
    )
  )
  ir_build_motif_graph <- ir_env$ir_build_motif_graph
  g <- ir_build_motif_graph(
    data,
    chain = "TRB",
    threshold = 1,
    by_v = FALSE,
    min_size = 1,
    show_isolated = TRUE
  )
  # All 4 CDR3s are nodes; CWXYZ is an isolated (degree-0) vertex.
  expect_equal(igraph::vcount(g), 4)
  expect_true("CWXYZ" %in% igraph::V(g)$cdr3)
  expect_equal(sum(igraph::degree(g) == 0), 1)
})

test_that("ir_build_motif_graph show_isolated renders even with no edges", {
  # Two CDR3s far apart (no Hamming-1 edge) — default returns NULL, but
  # show_isolated should still yield a 2-node edgeless graph.
  data <- list(
    s1 = data.frame(
      barcode = c("b1", "b2"),
      CTgene = rep("TRBV1..TRBJ1.TRBC1", 2),
      CTaa = c("CASSL", "CWXYZ"),
      sample = c("s1", "s1"),
      stringsAsFactors = FALSE
    )
  )
  ir_build_motif_graph <- ir_env$ir_build_motif_graph
  expect_null(ir_build_motif_graph(
    data,
    chain = "TRB",
    threshold = 1,
    by_v = FALSE,
    min_size = 1
  ))
  g <- ir_build_motif_graph(
    data,
    chain = "TRB",
    threshold = 1,
    by_v = FALSE,
    min_size = 1,
    show_isolated = TRUE
  )
  expect_true(inherits(g, "igraph"))
  expect_equal(igraph::vcount(g), 2)
  expect_equal(igraph::ecount(g), 0)
})

# --- ir_build_motif_plot legend suppression --------------------------------

test_that("ir_build_motif_plot hides the cluster legend when clusters are many", {
  skip_if_not_installed("ggraph")
  # 25 mutually dissimilar CDR3s -> 25 singleton clusters via show_isolated.
  aa <- vapply(
    1:25,
    function(i) {
      paste0("CASS", LETTERS[((i - 1) %% 26) + 1], sprintf("%02d", i))
    },
    character(1)
  )
  data <- list(
    s1 = data.frame(
      barcode = paste0("b", seq_along(aa)),
      CTgene = rep("TRBV1..TRBJ1.TRBC1", length(aa)),
      CTaa = aa,
      sample = rep("s1", length(aa)),
      stringsAsFactors = FALSE
    )
  )
  ir_build_motif_graph <- ir_env$ir_build_motif_graph
  ir_build_motif_plot <- ir_env$ir_build_motif_plot
  g <- ir_build_motif_graph(
    data,
    chain = "TRB",
    threshold = 1,
    by_v = FALSE,
    min_size = 1,
    show_isolated = TRUE
  )
  expect_gt(
    length(unique(igraph::V(g)$cluster)),
    IR_MOTIF_MAX_LEGEND_CLUSTERS
  )
  p <- ir_build_motif_plot(g, color_by = NULL)
  expect_equal(p$theme$legend.position, "none")
})

test_that("ir_build_motif_plot keeps the legend for a few clusters", {
  skip_if_not_installed("ggraph")
  data <- list(
    s1 = data.frame(
      barcode = paste0("b", 1:3),
      CTgene = rep("TRBV1..TRBJ1.TRBC1", 3),
      CTaa = c("CASSL", "CASSF", "CASTL"),
      sample = rep("s1", 3),
      stringsAsFactors = FALSE
    )
  )
  ir_build_motif_graph <- ir_env$ir_build_motif_graph
  ir_build_motif_plot <- ir_env$ir_build_motif_plot
  g <- ir_build_motif_graph(
    data,
    chain = "TRB",
    threshold = 1,
    by_v = FALSE,
    min_size = 1
  )
  p <- ir_build_motif_plot(g, color_by = NULL)
  expect_equal(p$theme$legend.position, "right")
})

test_that("ir_build_motif_plot hides the legend when show_legend = 'hide'", {
  skip_if_not_installed("ggraph")
  data <- list(
    s1 = data.frame(
      barcode = paste0("b", 1:3),
      CTgene = rep("TRBV1..TRBJ1.TRBC1", 3),
      CTaa = c("CASSL", "CASSF", "CASTL"),
      sample = rep("s1", 3),
      stringsAsFactors = FALSE
    )
  )
  ir_build_motif_graph <- ir_env$ir_build_motif_graph
  ir_build_motif_plot <- ir_env$ir_build_motif_plot
  g <- ir_build_motif_graph(
    data,
    chain = "TRB",
    threshold = 1,
    by_v = FALSE,
    min_size = 1
  )
  # Only a few clusters (auto-hide wouldn't fire), but hide is explicit.
  p <- ir_build_motif_plot(g, color_by = NULL, show_legend = "hide")
  expect_equal(p$theme$legend.position, "none")
})

test_that("ir_build_motif_plot honours legend_pos when shown", {
  skip_if_not_installed("ggraph")
  data <- list(
    s1 = data.frame(
      barcode = paste0("b", 1:3),
      CTgene = rep("TRBV1..TRBJ1.TRBC1", 3),
      CTaa = c("CASSL", "CASSF", "CASTL"),
      sample = rep("s1", 3),
      stringsAsFactors = FALSE
    )
  )
  ir_build_motif_graph <- ir_env$ir_build_motif_graph
  ir_build_motif_plot <- ir_env$ir_build_motif_plot
  g <- ir_build_motif_graph(
    data,
    chain = "TRB",
    threshold = 1,
    by_v = FALSE,
    min_size = 1
  )
  p <- ir_build_motif_plot(
    g,
    color_by = NULL,
    show_legend = "show",
    legend_pos = "bottom"
  )
  expect_equal(p$theme$legend.position, "bottom")
})

test_that("ir_build_motif_plot auto-hides many cluster legend even when shown", {
  skip_if_not_installed("ggraph")
  aa <- vapply(
    1:25,
    function(i) {
      paste0("CASS", LETTERS[((i - 1) %% 26) + 1], sprintf("%02d", i))
    },
    character(1)
  )
  data <- list(
    s1 = data.frame(
      barcode = paste0("b", seq_along(aa)),
      CTgene = rep("TRBV1..TRBJ1.TRBC1", length(aa)),
      CTaa = aa,
      sample = rep("s1", length(aa)),
      stringsAsFactors = FALSE
    )
  )
  ir_build_motif_graph <- ir_env$ir_build_motif_graph
  ir_build_motif_plot <- ir_env$ir_build_motif_plot
  g <- ir_build_motif_graph(
    data,
    chain = "TRB",
    threshold = 1,
    by_v = FALSE,
    min_size = 1,
    show_isolated = TRUE
  )
  # show_legend = "show" but colouring by cluster with >10 levels -> still hidden.
  p <- ir_build_motif_plot(
    g,
    color_by = NULL,
    show_legend = "show",
    legend_pos = "right"
  )
  expect_equal(p$theme$legend.position, "none")
})

test_that("ir_build_motif_plot keeps a metadata legend even with many clusters", {
  skip_if_not_installed("ggraph")
  aa <- vapply(
    1:25,
    function(i) {
      paste0("CASS", LETTERS[((i - 1) %% 26) + 1], sprintf("%02d", i))
    },
    character(1)
  )
  data <- list(
    s1 = data.frame(
      barcode = paste0("b", seq_along(aa)),
      CTgene = rep("TRBV1..TRBJ1.TRBC1", length(aa)),
      CTaa = aa,
      sample = rep(c("s1", "s2"), length.out = length(aa)),
      stringsAsFactors = FALSE
    )
  )
  ir_build_motif_graph <- ir_env$ir_build_motif_graph
  ir_build_motif_plot <- ir_env$ir_build_motif_plot
  g <- ir_build_motif_graph(
    data,
    chain = "TRB",
    threshold = 1,
    by_v = FALSE,
    min_size = 1,
    show_isolated = TRUE
  )
  # colouring by a metadata column (few categories) -> legend kept
  p <- ir_build_motif_plot(g, color_by = "sample")
  expect_equal(p$theme$legend.position, "right")
})

# --- ir_build_motif_plot consensus labels & cluster count ------------------

test_that("ir_build_motif_plot labels only multi-node clusters", {
  skip_if_not_installed("ggraph")
  # One real 3-node cluster + 24 isolated singletons via show_isolated.
  singles <- vapply(
    1:24,
    function(i) {
      paste0("CWXY", LETTERS[((i - 1) %% 26) + 1], sprintf("%02d", i))
    },
    character(1)
  )
  aa <- c("CASSL", "CASSF", "CASTL", singles)
  data <- list(
    s1 = data.frame(
      barcode = paste0("b", seq_along(aa)),
      CTgene = rep("TRBV1..TRBJ1.TRBC1", length(aa)),
      CTaa = aa,
      sample = rep("s1", length(aa)),
      stringsAsFactors = FALSE
    )
  )
  ir_build_motif_graph <- ir_env$ir_build_motif_graph
  ir_build_motif_plot <- ir_env$ir_build_motif_plot
  g <- ir_build_motif_graph(
    data,
    chain = "TRB",
    threshold = 1,
    by_v = FALSE,
    min_size = 1,
    show_isolated = TRUE
  )
  p <- ir_build_motif_plot(g, color_by = NULL)
  # The consensus-label layer is the GeomLabel layer; only the single
  # multi-node cluster gets a label, not the 24 isolated singletons.
  lab_layer <- p$layers[[
    which(vapply(
      p$layers,
      function(l) inherits(l$geom, "GeomLabel"),
      logical(1)
    ))
  ]]
  expect_equal(nrow(lab_layer$data), 1)
})

test_that("ir_build_motif_plot subtitle counts only multi-node clusters", {
  skip_if_not_installed("ggraph")
  singles <- vapply(
    1:24,
    function(i) {
      paste0("CWXY", LETTERS[((i - 1) %% 26) + 1], sprintf("%02d", i))
    },
    character(1)
  )
  aa <- c("CASSL", "CASSF", "CASTL", singles)
  data <- list(
    s1 = data.frame(
      barcode = paste0("b", seq_along(aa)),
      CTgene = rep("TRBV1..TRBJ1.TRBC1", length(aa)),
      CTaa = aa,
      sample = rep("s1", length(aa)),
      stringsAsFactors = FALSE
    )
  )
  ir_build_motif_graph <- ir_env$ir_build_motif_graph
  ir_build_motif_plot <- ir_env$ir_build_motif_plot
  g <- ir_build_motif_graph(
    data,
    chain = "TRB",
    threshold = 1,
    by_v = FALSE,
    min_size = 1,
    show_isolated = TRUE
  )
  p <- ir_build_motif_plot(g, color_by = NULL)
  # Only the single multi-node cluster is a real motif cluster; the 24
  # singletons must not inflate the count.
  expect_match(p$labels$subtitle %||% "", "1 motif cluster")
})

# --- ir_apply_display legend precedence ------------------------------------
# Motif Network sets its own legend.position (manual Hide / auto-hide / place),
# then the plot flows through safeRenderPlot -> ir_apply_display. That hook must
# NOT re-apply legend.position when skip_legend = TRUE, or it clobbers the plot's
# own decision (the "legend flickers on then off" bug). These tests lock that in.

test_that("ir_apply_display leaves legend.position alone when skip_legend = TRUE", {
  skip_if(is.null(ir_apply_display), "ir_apply_display not extractable")
  # A plot that hid its own legend, as ir_build_motif_plot does for auto-hide.
  p <- ggplot2::ggplot(
    data.frame(x = 1:3, y = 1:3, g = letters[1:3]),
    ggplot2::aes(x, y, colour = g)
  ) +
    ggplot2::geom_point() +
    ggplot2::theme(legend.position = "none")
  params <- list(ir_d_legend_show = "show", ir_d_legend_pos = "right")
  out <- ir_apply_display(p, params = params, skip_legend = TRUE)
  # skip_legend must preserve the plot's own "none".
  expect_equal(out$theme$legend.position, "none")
})

test_that("ir_apply_display DOES apply legend.position when skip_legend = FALSE", {
  skip_if(is.null(ir_apply_display), "ir_apply_display not extractable")
  # Same plot; without skip_legend the generic hook takes over positioning,
  # overriding the plot's own value. This is the behaviour Motif Network must
  # opt out of, and the reason skip_legend exists.
  p <- ggplot2::ggplot(
    data.frame(x = 1:3, y = 1:3, g = letters[1:3]),
    ggplot2::aes(x, y, colour = g)
  ) +
    ggplot2::geom_point() +
    ggplot2::theme(legend.position = "none")
  params <- list(ir_d_legend_show = "show", ir_d_legend_pos = "bottom")
  out <- ir_apply_display(p, params = params, skip_legend = FALSE)
  expect_equal(out$theme$legend.position, "bottom")
})

test_that("auto-hidden motif legend survives ir_apply_display(skip_legend=TRUE)", {
  skip_if_not_installed("ggraph")
  skip_if(is.null(ir_apply_display), "ir_apply_display not extractable")
  # End-to-end: many clusters -> ir_build_motif_plot hides the legend; the
  # display hook (skip_legend = TRUE, as Motif Network calls it) must keep it
  # hidden in a single render, not flip it back to "right".
  aa <- vapply(
    1:25,
    function(i) {
      paste0("CASS", LETTERS[((i - 1) %% 26) + 1], sprintf("%02d", i))
    },
    character(1)
  )
  data <- list(
    s1 = data.frame(
      barcode = paste0("b", seq_along(aa)),
      CTgene = rep("TRBV1..TRBJ1.TRBC1", length(aa)),
      CTaa = aa,
      sample = rep("s1", length(aa)),
      stringsAsFactors = FALSE
    )
  )
  ir_build_motif_graph <- ir_env$ir_build_motif_graph
  ir_build_motif_plot <- ir_env$ir_build_motif_plot
  g <- ir_build_motif_graph(
    data,
    chain = "TRB",
    threshold = 1,
    by_v = FALSE,
    min_size = 1,
    show_isolated = TRUE
  )
  p <- ir_build_motif_plot(
    g,
    color_by = NULL,
    show_legend = "show",
    legend_pos = "right"
  )
  expect_equal(p$theme$legend.position, "none")
  params <- list(ir_d_legend_show = "show", ir_d_legend_pos = "right")
  out <- ir_apply_display(p, params = params, skip_legend = TRUE)
  expect_equal(out$theme$legend.position, "none")
})

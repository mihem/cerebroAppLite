##----------------------------------------------------------------------------##
## Tab: Trekker — server.
##
## Sourced into the main server scope (try_source with local = parent.frame()),
## so `input`, `output`, `session` and `data_set` are in scope.
##
## Responsibilities:
##   1. render the parameter controls (standard app widgets), so the page uses
##      the same components/theme as every other tab;
##   2. push the loaded .crb's `trekker` slot to the client (www/trekker.js);
##   3. answer whole-transcriptome gene-colouring requests, returning a 0-255
##      vector aligned to the page's nuclei (via the slot's `barcodes` order).
##
## The controls are Shiny inputs; www/trekker.js listens to `shiny:inputchanged`
## and updates the canvases client-side (instant), so dragging a slider does not
## round-trip to the server. Only gene expression needs the server (it holds the
## matrix), so that one path is a request/response.
##----------------------------------------------------------------------------##

trekker_slot <- reactive({
  req(data_set())
  tryCatch(data_set()$getTrekker(), error = function(e) NULL)
})

## Genes offered first in the picker: the upstream Moran's I top genes plus
## canonical mouse-brain markers, restricted to genes actually measured. The full
## ~21k measured genes remain selectable (the picker searches the whole list).
trekker_gene_suggest <- function(tk, gene_names) {
  markers <- c(
    "Snap25",
    "Slc17a7",
    "Gad1",
    "Gad2",
    "Plp1",
    "Mbp",
    "Aqp4",
    "Gfap",
    "Cx3cr1",
    "C1qa",
    "Csf1r",
    "Pdgfra",
    "Prox1"
  )
  moran_genes <- vapply(tk$moran, function(m) m$gene, character(1))
  cand <- unique(c(moran_genes, markers))
  cand[cand %in% gene_names]
}

trekker_gene_names <- reactive({
  tryCatch(rownames(data_set()$expression), error = function(e) character(0))
})

##----------------------------------------------------------------------------##
## Parameter controls (standard widgets, rendered only when Trekker data exists)
##----------------------------------------------------------------------------##
output[["trekker_parameters_ui"]] <- renderUI({
  req(trekker_slot())
  suggest <- trekker_gene_suggest(trekker_slot(), trekker_gene_names())
  default_gene <- if (length(suggest)) suggest[1] else trekker_gene_names()[1]
  tagList(
    selectInput(
      "trekker_view",
      label = "View",
      choices = c("Side by side" = "pair", "Morph" = "morph")
    ),
    selectInput(
      "trekker_mode",
      label = "Colour by",
      choices = c(
        "Cell type" = "celltype",
        "Cluster" = "cluster",
        "Gene expression" = "gene"
      )
    ),
    conditionalPanel(
      condition = "input.trekker_mode == 'gene'",
      ## Suggested genes (upstream Moran + canonical markers) are offered as
      ## options; `create = TRUE` lets the user type ANY of the ~21k measured
      ## genes (the server validates it), which keeps this lightweight instead of
      ## rendering 21k <option> nodes -- same pattern as the Gene expression tab.
      selectizeInput(
        "trekker_gene_pick",
        label = "Gene",
        choices = suggest,
        selected = default_gene,
        multiple = FALSE,
        options = list(create = TRUE, placeholder = "search or type a gene...")
      )
    ),
    conditionalPanel(
      condition = "input.trekker_view == 'morph'",
      sliderInput(
        "trekker_morph",
        label = "Morph (UMAP to Spatial)",
        min = 0,
        max = 1,
        value = 0,
        step = 0.01
      )
    ),
    sliderInput(
      "trekker_ps",
      label = "Point size",
      min = 0.6,
      max = 6,
      value = 2.2,
      step = 0.2
    ),
    sliderInput(
      "trekker_nr",
      label = "Niche radius (um)",
      min = 50,
      max = 500,
      value = 250,
      step = 25
    ),
    shinyWidgets::materialSwitch(
      "trekker_evtoggle",
      label = "Mark nuclei with positioning evidence",
      value = TRUE,
      status = "primary",
      right = TRUE
    )
  )
})

output[["trekker_coordsource_ui"]] <- renderUI({
  req(trekker_slot())
  tagList(
    selectInput(
      "trekker_src",
      label = NULL,
      choices = c(
        "Location CSV (canonical)" = "csv",
        "@images (current extractor)" = "img",
        "SPATIAL reduction" = "red"
      )
    ),
    div(class = "trekker-page", div(class = "tk-hint", id = "tk-srchint"))
  )
})

## Render the controls eagerly (not only when the tab is shown) so they exist and
## stay in sync with the canvas as soon as a Trekker data set is loaded.
outputOptions(output, "trekker_parameters_ui", suspendWhenHidden = FALSE)
outputOptions(output, "trekker_coordsource_ui", suspendWhenHidden = FALSE)

##----------------------------------------------------------------------------##
## Push the slot to the client on (re)connect or data-set change
##----------------------------------------------------------------------------##
observe({
  input[["trekker_ready"]]
  tk <- trekker_slot()
  if (is.null(tk)) {
    return()
  }
  tk$gene_suggest <- trekker_gene_suggest(tk, trekker_gene_names())
  session$sendCustomMessage("trekker_data", tk)
})

##----------------------------------------------------------------------------##
## Gene colouring (whole transcriptome): send a 0-255 vector aligned to the
## page's nuclei whenever gene mode is active and a gene is selected.
##----------------------------------------------------------------------------##
observeEvent(
  list(input[["trekker_mode"]], input[["trekker_gene_pick"]]),
  {
    tk <- trekker_slot()
    if (is.null(tk) || is.null(input[["trekker_mode"]])) {
      return()
    }
    if (input[["trekker_mode"]] != "gene") {
      return()
    }
    g <- input[["trekker_gene_pick"]]
    if (is.null(g) || !nzchar(g)) {
      return()
    }
    if (!(g %in% trekker_gene_names())) {
      session$sendCustomMessage("trekker_geneval", list(gene = g, ok = FALSE))
      return()
    }
    mat <- tryCatch(
      data_set()$getExpressionMatrix(cells = tk$barcodes, genes = g),
      error = function(e) NULL
    )
    if (is.null(mat)) {
      session$sendCustomMessage("trekker_geneval", list(gene = g, ok = FALSE))
      return()
    }
    v <- as.numeric(mat)
    mx <- suppressWarnings(max(v, na.rm = TRUE))
    q <- if (is.finite(mx) && mx > 0) {
      as.integer(round(v / mx * 255))
    } else {
      rep(0L, length(v))
    }
    session$sendCustomMessage(
      "trekker_geneval",
      list(gene = g, ok = TRUE, v = q, max = round(mx, 3))
    )
  },
  ignoreInit = TRUE
)

## Moran's I "Show in plot" link: switch to gene mode and select the gene. The
## widget updates drive the observers above, which send the expression vector.
observeEvent(input[["trekker_moran_gene"]], {
  g <- input[["trekker_moran_gene"]]
  req(g, nzchar(g))
  updateSelectInput(session, "trekker_mode", selected = "gene")
  updateSelectizeInput(session, "trekker_gene_pick", selected = g)
})

##----------------------------------------------------------------------------##
## Info modals (same pattern as the other tabs)
##----------------------------------------------------------------------------##
observeEvent(input[["trekker_parameters_info"]], {
  showModal(modalDialog(
    title = "Parameters",
    easyClose = TRUE,
    footer = NULL,
    size = "l",
    HTML(
      "<ul>
        <li><b>View:</b> <i>Side by side</i> shows the spatial and UMAP scatter
          together; <i>Morph</i> interpolates each nucleus between its UMAP and
          its spatial position.</li>
        <li><b>Colour by:</b> cell type, cluster, or a single gene's expression
          (any of the whole-transcriptome genes).</li>
        <li><b>Point size / Niche radius:</b> display size, and the radius (in um)
          used for the physical-neighbour counts in the Cell inspector.</li>
        <li><b>Mark nuclei with positioning evidence:</b> ring the 50 nuclei that
          carry an official positioning-evidence image.</li>
      </ul>"
    )
  ))
})

observeEvent(input[["trekker_coordsource_info"]], {
  showModal(modalDialog(
    title = "Coordinate source",
    easyClose = TRUE,
    footer = NULL,
    size = "l",
    HTML(
      "The same nuclei appear in three orientations. <b>Location CSV</b> is the
      vendor's canonical coordinate authority. <b>@images</b> is what the generic
      spatial extractor reads — and it is <b>transposed</b> relative to canonical
      (it would silently draw the tissue rotated). The <b>SPATIAL reduction</b> is
      <b>y-mirrored</b>. Only the canonical coordinates are stored; the other two
      are derived so the discrepancy is visible rather than hidden."
    )
  ))
})

observeEvent(input[["trekker_qc_info"]], {
  showModal(modalDialog(
    title = "Data and QC",
    easyClose = TRUE,
    footer = NULL,
    size = "l",
    HTML(
      "Positioning QC in the vendor's own field names; a missing metric stays
      <i>missing</i>, never replaced by 0. <b>Confidently positioned</b> is not the
      same as \"exactly one location\": a fraction are vendor-salvaged
      multi-location nuclei, so the set is labelled
      <code>vendor_confidently_positioned</code>. The app reports when a value is
      below the vendor's reference range but does not adjudicate sample
      usability."
    )
  ))
})

observeEvent(input[["trekker_moran_info"]], {
  showModal(modalDialog(
    title = "Moran's I (upstream)",
    easyClose = TRUE,
    footer = NULL,
    size = "l",
    HTML(
      "Spatial autocorrelation from the upstream Trekker pipeline
      (<code>..._variable_features_spatial_moransi.txt</code>). It is computed
      differently from Cerebro's own Moran's I (Euclidean 6-NN), so the two are
      labelled separately and are not interchangeable."
    )
  ))
})

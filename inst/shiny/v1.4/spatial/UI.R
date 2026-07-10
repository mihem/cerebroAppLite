##----------------------------------------------------------------------------##
## Tab: Spatial
##----------------------------------------------------------------------------##
## Prepend the shared plotly layout factory; see overview/UI.R for context.
js_code_spatial_projection <- paste(
  readr::read_file(
    paste0(
      Cerebro.options[["cerebro_root"]],
      "/shiny/v1.4/www/projection_layouts.js"
    )
  ),
  ## Background-overlay layer, split out of js_projection_update_plot.js but
  ## concatenated back into the SAME extendShinyjs() text, so all functions
  ## still share one global scope (see the header in js_spatial_background.js).
  readr::read_file(
    paste0(
      Cerebro.options[["cerebro_root"]],
      "/shiny/v1.4/spatial/js_spatial_background.js"
    )
  ),
  readr::read_file(
    paste0(
      Cerebro.options[["cerebro_root"]],
      "/shiny/v1.4/spatial/js_projection_update_plot.js"
    )
  ),
  sep = "\n"
)

tab_spatial <- tabItem(
  tabName = "spatial",
  ## necessary to ensure alignment of table headers and content
  shinyjs::inlineCSS(
    "
    #spatial_details_selected_cells_table .table th {
      text-align: center;
    }
    #spatial_details_selected_cells_table .dt-middle {
      vertical-align: middle;
    }

    /* ---- Custom draggable legend for the spatial projection --------------- */
    /* The JS builds these elements but ships no styles (the upstream CSS was
       never committed), so define them here. The categorical legend and the
       continuous legend now render inside ONE shared container
       (#spatial_projection_legend); the continuous variant is marked with the
       .is-continuous class. */
    /* The legend is a fixed horizontal bar ABOVE the plot area (not a floating
       overlay), so it never covers data points and uses the otherwise-empty
       band between the box header and the plot. Categorical items flow
       left-to-right and wrap onto new lines when there are many groups; the
       continuous variant shows a single gradient bar with min/max labels. */
    /* Both the categorical and the continuous legend render inside THIS single
       shared container, so they occupy the exact same flex bar above the plot
       and push the plot down by the identical amount. Switching colour type
       never shifts the scatter/background alignment. */
    #spatial_projection_legend {
      position: static;
      display: flex;
      flex-wrap: wrap;
      align-items: center;
      gap: 4px 12px;
      background: rgba(255, 255, 255, 0.6);
      border: 1px solid #e5e5e5;
      border-radius: 6px;
      padding: 5px 10px;
      margin: 0 0 6px 0;
      font-family: inherit;
      user-select: none;
    }
    /* Legend title sits inline at the start of the bar. */
    #spatial_projection_legend .legend-header {
      display: flex;
      align-items: center;
      gap: 6px;
      margin: 0;
    }
    /* Continuous variant: give the title a little right margin so it doesn't
       hug the gradient block. */
    #spatial_projection_legend.is-continuous .legend-header {
      margin: 0 8px 0 0;
    }
    #spatial_projection_legend .legend-title-text {
      font-weight: 600;
      font-size: 13px;
      color: #333;
    }
    /* six-dot drag handle */
    #spatial_projection_legend .legend-drag-handle {
      display: flex;
      flex-direction: column;
      gap: 2px;
    }
    #spatial_projection_legend .legend-drag-handle-dots {
      display: flex;
      gap: 2px;
    }
    #spatial_projection_legend .legend-drag-handle-dot {
      width: 3px;
      height: 3px;
      border-radius: 50%;
      background: #b0b0b0;
    }
    /* one legend row: swatch + label */
    #spatial_projection_legend .custom-legend-item {
      display: flex;
      align-items: center;
      gap: 7px;
      cursor: pointer;
      border-radius: 3px;
    }
    #spatial_projection_legend .custom-legend-item:hover {
      background: rgba(0, 0, 0, 0.05);
    }
    /* colour swatch rendered as a filled circle */
    #spatial_projection_legend .legend-color-box {
      display: inline-block;
      flex: 0 0 auto;
      border-radius: 50%;
      border: 1px solid rgba(0, 0, 0, 0.15);
    }
    #spatial_projection_legend .legend-text {
      color: #333;
      white-space: nowrap;
    }
    /* clicked-to-hide state */
    #spatial_projection_legend .legend-item-hidden {
      opacity: 0.35;
    }
    #spatial_projection_legend .legend-item-hidden .legend-text {
      text-decoration: line-through;
    }
    /* first-time drag hint */
    #spatial_projection_legend .legend-drag-tip {
      font-size: 11px;
      color: #888;
      margin-top: 4px;
      font-style: italic;
    }
    /* continuous colour legend: a flat HORIZONTAL bar — min label, gradient,
       max label all on one line — so it stays short and doesn't eat vertical
       space above the plot. */
    #spatial_projection_legend .continuous-legend-content {
      display: flex;
      flex-direction: row;
      align-items: center;
      gap: 6px;
    }
    #spatial_projection_legend .continuous-legend-gradient {
      width: 120px;
      height: 12px;
      flex: 0 0 auto;
      border-radius: 3px;
      border: 1px solid rgba(0, 0, 0, 0.15);
    }
    #spatial_projection_legend .continuous-legend-label {
      font-size: 11px;
      color: #333;
    }

    /* ---- Additional-parameters panel: internal scroll ------------------- */
    /* The background-image controls are tall; on shorter screens adjusting
       Rotate/Move used to push the plot out of view. Cap the panel body and
       let it scroll internally instead of scrolling the whole page, so the
       plot stays put. The scrollbar is hidden and a soft top/bottom fade hints
       that more content is scrollable. */
    #spatial_additional_parameters_wrapper .box-body {
      max-height: calc(100vh - 320px);
      overflow-y: auto;
      /* hide scrollbar: Firefox + legacy, WebKit handled below */
      scrollbar-width: none;
      -ms-overflow-style: none;
      /* soft fade at top and bottom edges */
      -webkit-mask-image: linear-gradient(
        to bottom,
        transparent 0,
        #000 14px,
        #000 calc(100% - 14px),
        transparent 100%
      );
      mask-image: linear-gradient(
        to bottom,
        transparent 0,
        #000 14px,
        #000 calc(100% - 14px),
        transparent 100%
      );
    }
    #spatial_additional_parameters_wrapper .box-body::-webkit-scrollbar {
      width: 0;
      height: 0;
    }
    /* 'more below' pill: a small hint that the panel scrolls. Shown only while
       the body is scrollable and not yet at the bottom (toggled from JS), and it
       fades out as the user reaches the end. */
    #spatial_additional_parameters_wrapper {
      position: relative;
    }
    #spatial_additional_scroll_hint {
      position: absolute;
      left: 50%;
      bottom: 8px;
      transform: translateX(-50%);
      z-index: 5;
      display: none;
      align-items: center;
      justify-content: center;
      width: 26px;
      height: 26px;
      border-radius: 50%;
      background: rgba(51, 122, 183, 0.9);
      color: #fff;
      font-size: 15px;
      line-height: 1;
      box-shadow: 0 1px 4px rgba(0, 0, 0, 0.25);
      pointer-events: none;
      opacity: 0;
      transition: opacity 0.25s ease;
      animation: spatial-scroll-bob 1.4s ease-in-out infinite;
    }
    #spatial_additional_scroll_hint.is-visible {
      display: flex;
      opacity: 1;
    }
    @keyframes spatial-scroll-bob {
      0%, 100% { transform: translateX(-50%) translateY(0); }
      50% { transform: translateX(-50%) translateY(3px); }
    }
    "
  ),
  shinyjs::extendShinyjs(
    text = js_code_spatial_projection,
    functions = c(
      "updatePlot2DContinuousSpatial",
      "updatePlot3DContinuousSpatial",
      "updatePlot2DCategoricalSpatial",
      "updatePlot3DCategoricalSpatial",
      "updateSpatialBackgroundAppearance",
      "getContainerDimensions",
      "spatialClearSelection",
      "showScrollDownIndicator",
      "hideScrollDownIndicator"
    )
  ),
  uiOutput("spatial_projection_UI"),
  uiOutput("spatial_selected_cells_plot_UI"),
  uiOutput("spatial_selected_cells_table_UI")
)

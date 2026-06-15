##----------------------------------------------------------------------------##
## Tab: Immune Repertoire server — entry point
##----------------------------------------------------------------------------##

local({

  has_scRepertoire <- function() {
    requireNamespace("scRepertoire", quietly = TRUE)
  }

  safeRenderPlot <- function(expr, plot_name = "unknown") {
    tryCatch({
      expr
    }, error = function(e) {
      message("[IR ERROR] Plot '", plot_name, "' failed: ", e$message)
      plot.new()
      text(0.5, 0.5, paste("Error in", plot_name, ":\n", e$message), cex = 0.8)
    })
  }

  source(paste0(Cerebro.options[["cerebro_root"]], "/shiny/v1.4/immune_repertoire/data.R"), local = TRUE)
  source(paste0(Cerebro.options[["cerebro_root"]], "/shiny/v1.4/immune_repertoire/visualizations.R"), local = TRUE)

})

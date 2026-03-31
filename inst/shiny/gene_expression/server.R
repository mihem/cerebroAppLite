##----------------------------------------------------------------------------##
## Tab: Gene (set) expression
##----------------------------------------------------------------------------##

## Track if gene expression tab has been initialized
gene_expression_initialized <- reactiveVal(FALSE)

##----------------------------------------------------------------------------##
## Show progress bar immediately when switching to this tab.
##----------------------------------------------------------------------------##
observeEvent(input[["sidebar"]], {
  req(input[["sidebar"]] == "geneExpression")
  ## Only show loading progress if the tab hasn't been initialized yet
  if (!gene_expression_initialized()) {
    withProgress(message = 'Loading gene expression tab...', value = 0.3, {
      ## This progress bar shows immediately while UI elements initialize
      Sys.sleep(0.1)
    })
  }
}, ignoreInit = TRUE)

files_to_load <- list.files(
  paste0(Cerebro.options[["cerebro_root"]], "/shiny/gene_expression"),
  pattern = "func_|obj_|UI_|out_|event_",
  full.names = TRUE
)

for ( i in files_to_load ) {
  source(i, local = TRUE)
}

# Ideas of what to implement in cerebroApp in the future

## cerebroApp

- increase speed of gene expression
- remove unnecessary functions

## Gene expression page — known issues

### 1. “Gene set” option is hidden

- The Gene set code paths still exist in `gene_expression/`, but the
  radio button in `UI_projection.R` only offers `c("Gene(s)")`, so users
  can’t reach it.
- `getGenesForGeneSet()` also uses `msigdbr:::msigdbr_genesets`
  (internal), which was removed in msigdbr 7.x — it would crash even if
  exposed.
- Fix later: rewrite `getGenesForGeneSet()` with the public `msigdbr()`
  API, then add `"Gene set"` back to the radio choices. Optional:
  support user-supplied GMT/JSON files.

### 2. UMAP doesn’t update when genes change

- Picking genes on the Gene expression page doesn’t redraw the plot —
  color stays at 0.
- Cause: a partial merge. Commit 035d2f5 brought the consumer side (a
  reference to `input$expression_projection_update_button` plus
  `isolate()` around `expression_selected_genes()` and
  `expression_projection_expression_levels()`), but the producer side
  from commit a49cb03 (on `mischko` / `mischko-03-refresh`) was never
  merged into `mischko-01-foundation`. Three pieces are missing:
  1.  The
      `actionButton("expression_projection_update_button", "Plot Expression", ...)`
      in `UI_projection_input_type.R`.
  2.  `obj_selected_genes.R` should be
      `eventReactive(input$update_button, { ... }, ignoreNULL = FALSE)`,
      not a plain `reactive(...)`.
  3.  The `serverSideGeneSelector` helper (defined in dev’s
      `utility_functions.R`).

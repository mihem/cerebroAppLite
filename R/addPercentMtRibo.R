#' @title
#' Add percentage of mitochondrial and ribosomal transcripts.
#'
#' @description
#' Get percentage of transcripts of gene list compared to all transcripts per
#' cell.
#'
#' @param object Seurat object.
#' @param assay Assay to pull counts from; defaults to 'RNA'. Only relevant in
#' Seurat v3.0 or higher since the concept of assays wasn't implemented before.
#' @param organism Organism, can be either human ('hg') or mouse ('mm'). Genes
#' need to annotated as gene symbol, e.g. MKI67 (human) / Mki67 (mouse).
#' @param gene_nomenclature Define if genes are saved by their name ('name'),
#' ENSEMBL ID ('ensembl') or GENCODE ID ('gencode_v27', 'gencode_vM16').
#'
#' @return
#' Seurat object with two new meta data columns containing the percentage of
#' mitochondrial and ribosomal gene expression for each cell.
#'
#' @examples
#' pbmc <- readRDS(system.file("extdata/v1.3/pbmc_seurat.rds",
#'   package = "cerebroApp"))
#' pbmc <- addPercentMtRibo(
#'   object = pbmc,
#'   assay = 'RNA',
#'   organism = 'hg',
#'   gene_nomenclature = 'name'
#' )
#'
#' @import dplyr
#' @importFrom readr cols read_tsv
#'
#' @export
#'
addPercentMtRibo <- function(
  object,
  assay = 'RNA',
  organism,
  gene_nomenclature
) {

  ##--------------------------------------------------------------------------##
  ## safety checks before starting to do anything
  ##--------------------------------------------------------------------------##

  ## check if Seurat is installed
  if ( !requireNamespace("Seurat", quietly = TRUE) ) {
    stop(
      "The 'Seurat' package is needed for this function to work. Please install it.",
      call. = FALSE
    )
  }

  ## check that Seurat package is at least v3.0
  if ( utils::packageVersion('Seurat') < "3" ) {
    stop(
      paste0(
        "The installed Seurat package is of version `", utils::packageVersion('Seurat'),
        "`, but at least v3.0 is required."
      ),
      call. = FALSE
    )
  }

  ## check if provided object is of class "Seurat"
  if ( class(object) != "Seurat" ) {
    stop(
      paste0(
        "Provided object is of class `", class(object), "` but must be of class 'Seurat'."
      ),
      call. = FALSE
    )
  }

  ## check version of Seurat object and stop if it is lower than 3
  if ( object@version < "3" ) {
    stop(
      paste0(
        "Provided Seurat object has version `", object@version, "` but must be at least 3.0."
      ),
      call. = FALSE
    )
  }

  ## check if organism is supported
  supported_organisms <- c('hg','mm')
  if ( !(organism %in% supported_organisms) ) {
    stop(
      paste0(
        "User-specified organism ('", organism,
        "') not in list of supported organisms: ",
        paste(supported_organisms, collapse = ', ')
      )
    )
  }

  ## check if nomenclature is supported
  supported_nomenclatures <- c('name','ensembl','gencode_v27','gencode_vM16')
  if ( !(gene_nomenclature %in% supported_nomenclatures) ) {
    stop(
      paste0(
        "User-specified gene nomenclature ('", gene_nomenclature,
        "') not in list of supported nomenclatures: ",
        paste(supported_nomenclatures, collapse = ', ')
      )
    )
  }

  ##--------------------------------------------------------------------------##
  ## load mitochondrial and ribosomal gene lists from extdata
  ##--------------------------------------------------------------------------##

  genes_mt <- readr::read_tsv(
      system.file(
        paste0(
          'extdata/genes_mt_', organism, '_', gene_nomenclature, '.tsv.gz'
        ),
        package = 'cerebroApp'
      ),
      col_types = readr::cols(),
      col_names = FALSE
    ) %>%
    dplyr::select(1) %>%
    t() %>%
    as.vector()
  genes_ribo <- readr::read_tsv(
      system.file(
        paste0(
          'extdata/genes_ribo_', organism, '_', gene_nomenclature, '.tsv.gz'
        ),
        package = 'cerebroApp'
      ),
      col_types = readr::cols(),
      col_names = FALSE
    ) %>%
    dplyr::select(1) %>%
    t() %>%
    as.vector()

  ##--------------------------------------------------------------------------##
  ## keep only genes that are present in data set
  ##--------------------------------------------------------------------------##

  if ( object@version < "3" ) {
    ## check if `raw.data` matrix exist in provided Seurat object
    if ( ( is.null(object@raw.data) ) ) {
      stop(
        paste0(
          '`raw.data` matrix could not be found in provided Seurat ',
          'object.'
        ),
        call. = FALSE
      )
    }
    genes_mt_here <- intersect(genes_mt, rownames(object@raw.data))
    genes_ribo_here <- intersect(genes_ribo, rownames(object@raw.data))
  } else {
    ## check if provided assay exists
    if ( (assay %in% names(object@assays) == FALSE ) ) {
      stop(
        paste0(
          'Assay slot `', assay, '` could not be found in provided Seurat ',
          'object.'
        ),
        call. = FALSE
      )
    }
    ## check if `counts` matrix exist in provided assay
    if ( is.null(object@assays[[assay]]@counts) ) {
      stop(
        paste0(
          '`counts` matrix could not be found in `', assay, '` assay slot.'
        ),
        call. = FALSE
      )
    }
    genes_mt_here <- intersect(
      genes_mt, rownames(object@assays[[assay]]@counts)
    )
    genes_ribo_here <- intersect(
      genes_ribo, rownames(object@assays[[assay]]@counts)
    )
  }

  ##--------------------------------------------------------------------------##
  ## prepare slot in Seurat object to store gene lists (if it doesn't already
  ## exist)
  ##--------------------------------------------------------------------------##

  if ( is.null(object@misc$gene_lists) ) {
    object@misc$gene_lists <- list()
  }

  ##--------------------------------------------------------------------------##
  ## calculate mitochondrial gene expression
  ##--------------------------------------------------------------------------##

  if ( length(genes_mt_here) > 0 ) {
    object@misc$gene_lists$mitochondrial_genes <- genes_mt_here
    message(
      paste0(
        '[', format(Sys.time(), '%H:%M:%S'), '] Calculate percentage of ',
        length(genes_mt_here),
        ' mitochondrial transcript(s) present in the data set...'
      )
    )
    values_mt <- cerebroApp::calculatePercentGenes(
      object,
      assay = assay,
      list('genes_mt' = genes_mt_here)
    )
  } else {
    object@misc$gene_lists$mitochondrial_genes <- 'no_mitochondrial_genes_found'
    message(
      paste0(
        '[', format(Sys.time(), '%H:%M:%S'),
        '] No mitochondrial genes found in data set.'
      )
    )
    values_mt <- 0
  }

  ##--------------------------------------------------------------------------##
  ## calculate ribosomal gene expression
  ##--------------------------------------------------------------------------##

  if ( length(genes_ribo_here) > 0 ) {
    object@misc$gene_lists$ribosomal_genes <- genes_ribo_here
    message(
      paste0(
        '[', format(Sys.time(), '%H:%M:%S'), '] Calculate percentage of ',
        length(genes_ribo_here),
        ' ribosomal transcript(s) present in the data set...'
      )
    )
    values_ribo <- cerebroApp::calculatePercentGenes(
      object,
      assay = assay,
      list('genes_ribo' = genes_ribo_here)
    )
  } else {
    object@misc$gene_lists$ribosomal_genes <- 'no_ribosomal_genes_found'
    message(
      paste0(
        '[', format(Sys.time(), '%H:%M:%S'),
        '] No ribosomal genes found in data set.'
      )
    )
    values_ribo <- 0
  }

  ##--------------------------------------------------------------------------##
  ## add results to Seurat object
  ##--------------------------------------------------------------------------##

  if ( object@version < "3" ) {
    object <- Seurat::AddMetaData(
      object,
      data.frame(
        row.names = colnames(object@raw.data),
        'percent_mt' = values_mt,
        'percent_ribo' = values_ribo
      )
    )
  } else {
    object$percent_mt <- values_mt
    object$percent_ribo <- values_ribo
  }

  ##--------------------------------------------------------------------------##
  ##
  ##--------------------------------------------------------------------------##
  return(object)
}

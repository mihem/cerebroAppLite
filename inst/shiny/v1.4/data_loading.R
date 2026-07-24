##----------------------------------------------------------------------------##
## Process-level data-loading helpers (A4).
##
## Sourced ONCE per R process from the top of shiny_server.R (outside the
## server() function), NOT per session. Cerebro objects are read-only and R
## Shiny runs a single-threaded event loop, so one shared .crb_cache lets every
## session reuse the same decompressed object instead of each holding its own
## copy. These functions carry no session state: .attachExternalExpression reads
## Cerebro.options from .GlobalEnv and the object's own methods only.
##----------------------------------------------------------------------------##

##----------------------------------------------------------------------------##
## Cerebro file reader (.rds via readRDS).
##----------------------------------------------------------------------------##
read_cerebro_file <- function(file) {
  readRDS(file)
}

##----------------------------------------------------------------------------##
## Process-level LRU cache for loaded .crb files (A4).
##
## Keyed by normalized path + size + mtime, so overwriting a .crb in place is
## detected (a new key -> a reload) without a process restart. Bounded by
## .crb_cache_max via least-recently-used eviction, so a long-lived process
## serving many data sets does not grow without limit. drop_crb_cache() lets a
## session release its uploaded file's object when it ends.
##----------------------------------------------------------------------------##
.crb_cache <- new.env(parent = emptyenv())
.crb_cache_order <- character(0) # cache keys, least-recently-used first
.crb_cache_max <- 8L

.crb_cache_key <- function(path) {
  info <- file.info(path)
  paste(
    normalizePath(path, mustWork = FALSE),
    info$size,
    as.numeric(info$mtime),
    sep = "|"
  )
}

.crb_cache_touch <- function(key) {
  .crb_cache_order <<- c(setdiff(.crb_cache_order, key), key)
}

get_or_load_crb <- function(path) {
  key <- .crb_cache_key(path)
  if (is.null(.crb_cache[[key]])) {
    print(glue::glue("[{Sys.time()}] CRB cache miss, loading: {path}"))
    obj <- read_cerebro_file(path)
    obj <- .attachExternalExpression(obj, path)
    assign(key, obj, envir = .crb_cache)
    .crb_cache_touch(key)
    ## Evict least-recently-used entries once over the cap.
    while (length(.crb_cache_order) > .crb_cache_max) {
      evict <- .crb_cache_order[1]
      if (exists(evict, envir = .crb_cache, inherits = FALSE)) {
        rm(list = evict, envir = .crb_cache)
      }
      .crb_cache_order <<- .crb_cache_order[-1]
    }
  } else {
    print(glue::glue("[{Sys.time()}] CRB cache hit: {path}"))
    .crb_cache_touch(key)
  }
  .crb_cache[[key]]
}

## Drop every cache entry for a path (any size/mtime variant), freeing an
## uploaded file's object when its session ends.
drop_crb_cache <- function(path) {
  prefix <- paste0(normalizePath(path, mustWork = FALSE), "|")
  keys <- ls(.crb_cache, all.names = TRUE)
  hit <- keys[startsWith(keys, prefix)]
  if (length(hit) > 0) {
    rm(list = hit, envir = .crb_cache)
    .crb_cache_order <<- setdiff(.crb_cache_order, hit)
  }
}

##----------------------------------------------------------------------------##
## Resolve an external expression backend at load time (B3).
##
## bpcells crbs ship a sibling <stem>.bpcells/ directory; the IterableMatrix
## handle persisted into the crb carries the writer's absolute @dir, which
## breaks once the crb is moved. This helper rebuilds the handle from a path
## rooted at the caller's view of the filesystem.
##
## Path priority:
##   1. Cerebro.options[["expression_matrix_BPCells"]] absolute override
##   2. dirname(crb_path) + getExpressionBackend()$location  (default)
##----------------------------------------------------------------------------##
.attachExternalExpression <- function(obj, crb_path) {
  if (!any(grepl("Cerebro", class(obj)))) {
    return(obj)
  }
  if (!is.function(obj$getExpressionBackend)) {
    ## Legacy crb without an expression_backend field. If the host app has
    ## configured an external matrix override, synthesise the backend tag
    ## from it so the runtime can still attach an h5 / bpcells sibling.
    ## Otherwise fall back to embedded (returned early below).
    opts <- if (
      exists("Cerebro.options", envir = .GlobalEnv, inherits = FALSE)
    ) {
      get("Cerebro.options", envir = .GlobalEnv)
    } else {
      list()
    }
    if (!is.null(opts[["expression_matrix_h5"]])) {
      be <- list(
        type = "h5",
        location = basename(opts[["expression_matrix_h5"]])
      )
    } else if (!is.null(opts[["expression_matrix_BPCells"]])) {
      be <- list(
        type = "bpcells",
        location = basename(opts[["expression_matrix_BPCells"]])
      )
    } else {
      be <- list(type = "embedded", location = NULL)
    }
  } else {
    be <- obj$getExpressionBackend()
  }

  if (is.null(be) || identical(be$type, "embedded")) {
    return(obj)
  }

  override <- NULL
  if (exists("Cerebro.options", envir = .GlobalEnv, inherits = FALSE)) {
    opts <- get("Cerebro.options", envir = .GlobalEnv)
    override_key <- switch(
      be$type,
      bpcells = "expression_matrix_BPCells",
      h5 = "expression_matrix_h5",
      NULL
    )
    if (!is.null(override_key) && !is.null(opts[[override_key]])) {
      override <- opts[[override_key]]
    }
  }

  if (!is.null(override)) {
    loc_abs <- override
  } else if (!is.null(be$location)) {
    crb_dir <- dirname(normalizePath(crb_path, mustWork = FALSE))
    loc_abs <- file.path(crb_dir, be$location)
  } else {
    stop(
      sprintf(
        "External expression backend '%s' for crb '%s' has no location tag; ",
        be$type,
        crb_path
      ),
      "cannot attach. This crb may have been generated by a buggy exporter.",
      call. = FALSE
    )
  }

  if (be$type == "bpcells") {
    if (!requireNamespace("BPCells", quietly = TRUE)) {
      stop(
        "bpcells-backed crb requires the BPCells package; please install it.",
        call. = FALSE
      )
    }
    if (!dir.exists(loc_abs)) {
      stop(
        sprintf(
          "Expected BPCells matrix directory at '%s' (derived from crb '%s' + backend location '%s'), but the directory does not exist. ",
          loc_abs,
          crb_path,
          be$location
        ),
        "Did the .bpcells/ sibling get moved or dropped when the crb was copied? ",
        "You can also point at a different absolute location via ",
        "Cerebro.options[['expression_matrix_BPCells']].",
        call. = FALSE
      )
    }
    print(glue::glue("[{Sys.time()}] Attaching bpcells backend: {loc_abs}"))
    obj$expression <- BPCells::open_matrix_dir(dir = loc_abs)
  } else if (be$type == "h5") {
    if (!requireNamespace("HDF5Array", quietly = TRUE)) {
      stop(
        "h5-backed crb requires the HDF5Array package; please install it ",
        "via BiocManager::install(\"HDF5Array\").",
        call. = FALSE
      )
    }
    if (!file.exists(loc_abs)) {
      stop(
        sprintf(
          "Expected h5 file at '%s' (derived from crb '%s' + backend location '%s'), but the file does not exist. ",
          loc_abs,
          crb_path,
          be$location
        ),
        "Did the .h5 sibling get moved or dropped when the crb was copied? ",
        "You can also point at a different absolute location via ",
        "Cerebro.options[['expression_matrix_h5']].",
        call. = FALSE
      )
    }
    print(glue::glue(
      "[{Sys.time()}] Attaching h5 backend (lazy TENxMatrix): {loc_abs}"
    ))

    ## On-disk layout is cells x genes (TENxMatrix orientation, optimised for
    ## per-gene column reads). Cerebro's internal layout is genes x cells, so
    ## we transpose lazily — DelayedArray::t() is O(1), no data is read.
    ## The matrix is never materialised into a dgCMatrix at attach time;
    ## queries stream from disk through the DelayedMatrix path in
    ## getExpressionRow / getExpressionBlock.
    m_disk <- HDF5Array::TENxMatrix(loc_abs, group = "expression")
    obj$expression <- t(m_disk)
  } else {
    stop(
      sprintf(
        "Unknown expression backend type '%s' in crb '%s'.",
        be$type,
        crb_path
      ),
      call. = FALSE
    )
  }

  obj
}

# Create a self-contained Shiny app folder for Cerebro v1.4

Bundles a Cerebro v1.4 Shiny app into `result_dir`, copying the
`inst/shiny/v1.4/` sources, the requested `.crb` data file(s), and
`extdata/`, and writes an `app.R` that sources the bundled UI/server.
The output directory can be served directly by shiny-server or run with
`shiny::runApp(result_dir)`.

## Usage

``` r
createShinyApp(
  cerebro_data,
  result_dir = NULL,
  max_request_size = 8000,
  port = 8080,
  host = "127.0.0.1",
  launch_browser = TRUE,
  quiet = FALSE,
  display_mode = "normal",
  colors = NULL,
  cerebro_options = list(exclude_trivial_metadata = TRUE),
  overwrite = TRUE,
  verbose = TRUE,
  crb_pick_smallest_file = TRUE,
  show_upload_ui = TRUE,
  welcome_message = "Welcome to Cerebro App!",
  point_size = list(overview_projection_point_size = NULL),
  variable_to_compare = NULL,
  ...
)
```

## Arguments

- cerebro_data:

  Named character vector or list of `.crb` (or `.rds`) file paths. Names
  are used as dataset labels.

- result_dir:

  Output directory.

- max_request_size:

  Max upload size in MB; defaults to 8000.

- port:

  Port the generated app listens on; defaults to 1337.

- host:

  Host the generated app binds to; defaults to "127.0.0.1".

- launch_browser:

  Whether to launch a browser; defaults to TRUE.

- quiet:

  Passed to
  [`shiny::runApp`](https://rdrr.io/pkg/shiny/man/runApp.html); defaults
  to FALSE.

- display_mode:

  [`shiny::runApp`](https://rdrr.io/pkg/shiny/man/runApp.html) display
  mode; defaults to "normal".

- colors:

  Optional named list of colour palettes per dataset.

- cerebro_options:

  Extra entries merged into `Cerebro.options` in the generated app.

- overwrite:

  If `TRUE` (default), wipe `result_dir` first.

- verbose:

  Print progress messages; defaults to TRUE.

- crb_pick_smallest_file:

  Forwarded to `Cerebro.options`.

- show_upload_ui:

  Forwarded to `Cerebro.options`.

- welcome_message:

  Welcome message shown in the Load Data tab.

- point_size:

  Named list with `overview_projection_point_size` (and optionally other
  keys) forwarded to `Cerebro.options`.

- variable_to_compare:

  Forwarded to `Cerebro.options`.

- ...:

  Currently unused; reserved for future arguments.

## Value

Invisibly returns `result_dir`.

## Details

This is mischko's slimmed-down variant: auth, spatial, bpcells, and
Docker template handling were dropped — they depend on dev-only modules.
Re-add those switches as the corresponding modules land.

# Launch Cerebro v1.2

Launch the Cerebro v1.2 Shiny application.

## Usage

``` r
launchCerebroV1.2(maxFileSize = 800, ...)
```

## Arguments

- maxFileSize:

  Maximum size of input file; defaults to `800` (800 MB).

- ...:

  Further parameters that are used by
  [`shiny::runApp`](https://rdrr.io/pkg/shiny/man/runApp.html), e.g.
  `host` or `port`.

## Value

Shiny application.

## Examples

``` r
if ( interactive() ) {
  launchCerebroV1.2(maxFileSize = 800)
}
```

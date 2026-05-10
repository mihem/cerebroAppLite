# Launch Cerebro interface.

Launch Cerebro interface.

## Usage

``` r
launchCerebro(version = "v1.4", ...)
```

## Arguments

- version:

  Which version of Cerebro to launch: "v1.0", "v1.1", "v1.2", "v1.3",
  "v1.4"; defaults to "v1.4".

- ...:

  Further parameters that are used by
  [`shiny::runApp`](https://rdrr.io/pkg/shiny/man/runApp.html), e.g.
  `host` an `port`, and the specific versions of Cerebro. See
  `launchCerebroV1.x` for details.

## Value

Shiny application.

## See also

[`launchCerebroV1.0`](https://mihem.github.io/cerebroAppLite/reference/launchCerebroV1.0.md),
[`launchCerebroV1.1`](https://mihem.github.io/cerebroAppLite/reference/launchCerebroV1.1.md),
[`launchCerebroV1.2`](https://mihem.github.io/cerebroAppLite/reference/launchCerebroV1.2.md),
[`launchCerebroV1.3`](https://mihem.github.io/cerebroAppLite/reference/launchCerebroV1.3.md)

## Examples

``` r
if ( interactive() ) {
  launchCerebro(
    version = "v1.4",
    options = list(port = 1337)
  )
}
```

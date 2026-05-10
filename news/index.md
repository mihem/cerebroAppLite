# Changelog

## cerebroAppLite 1.6.0

### Bug fixes

- Fixed all errors and warnings identified by R CMD CHECK, making the
  package ready for CRAN submission
- Fixed Seurat v5 API: replaced deprecated slot access (`@counts`,
  `@data`) with
  [`GetAssayData()`](https://satijalab.github.io/seurat-object/reference/AssayData.html)
  across multiple functions
- Fixed `addPercentMtRibo`, `calculatePercentGenes`,
  `getMostExpressedGenes`, `performGeneSetEnrichmentAnalysis`,
  `getMarkerGenes`, `getEnrichedPathways`, `exportFromSCE`,
  `exportFromSeurat`
- Fixed GSVA v2.x API compatibility: now uses `gsvaParam()` with version
  check for backward compatibility
- Fixed `class(x) == "..."` checks replaced with
  [`inherits()`](https://rdrr.io/r/base/class.html) across all relevant
  functions
- Fixed [`require()`](https://rdrr.io/r/base/library.html) replaced with
  [`requireNamespace()`](https://rdrr.io/r/base/ns-load.html) throughout
- Fixed cross-references and examples in documentation

### Testing

- Added unit tests for all core R functions
- Added shinytest2 integration tests for the full Cerebro interface,
  covering gene expression, group/marker genes, color management, and
  more
- Tests run in a reproducible Nix environment via GitHub Actions

### CI/CD

- Added Nix-based GitHub Actions workflows for R CMD CHECK, R tests,
  pkgdown, code style, and automatic `default.nix` updates
- Added `update-nix` workflow: regenerates `default.nix` weekly via
  `create_env.R` and opens a PR automatically; BPCells commit SHA is now
  auto-fetched from GitHub
- Added `style` workflow: formats R code via
  [air](https://github.com/posit-dev/air) on every PR
- Added `sync-dev` workflow: automatically merges master back into dev
  after every merge to keep branches in sync
- Switched Nix environment to `bleeding-edge` for always up-to-date CRAN
  packages
- Branch protection rulesets configured for both `master` and `dev` with
  required status checks and auto-merge

### Documentation

- Added pkgdown site at <https://mihem.github.io/cerebroAppLite/> with
  light/dark/auto theme switch, search, and all vignettes as articles
- Site automatically builds and deploys to GitHub Pages on push to
  master

## cerebroAppLite 1.5.3

- several bug fixes so that launchCerebro should work again

## cerebroAppLite 1.5.2

- allow plot settings (size, opacity, number of cells to show) to be
  different in gene expression and overview (useful for large datasets
  with slow gene expression)

## cerebroAppLite 1.5.1

- remove unused functions in group

## cerebroAppLite 1.5.0

- make compatible with Seuratv5, especially with BPCells Matrix

## cerebroAppLite 1.4.1

- timeout function added. This logs out the user after 600 second of
  inactivity (can be changed in `shiny_ui.R`). The JS function was taken
  from <https://stackoverflow.com/a/53207050/21417317>.
- add option to show up to 1000 cells in `Main`, which is useful for
  exports.

## cerebroAppLite 1.4.0

This is the first update of this cerebroApp fork. Its aim is to continue
a lightweight version of the excellent cerebroApp with only the main
function as the cerebroApp by Roman Hillje is sadly discontinued.

### Major changes

- remove enriched pathways, extra material, most expressed genes and
  trajectory functions since the goal of this fork is to continue with a
  lightweight version

### Minor changes

- `Load Data` is renamed to `Data info` and `Overview` to `Main`
- Preferences about WebGL and hover info are now show in the first tab
  called `Data info`
- more colorful boxes for the sample information
- different icons for tabs `Data info`, `Main`, `Groups` and
  `Marker Groups`

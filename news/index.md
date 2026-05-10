# Changelog

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

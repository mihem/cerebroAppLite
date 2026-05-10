<!-- badges: start -->
[![R-CMD-check](https://github.com/mihem/cerebroAppLite/actions/workflows/R-cmd-check.yaml/badge.svg)](https://github.com/mihem/cerebroAppLite/actions/workflows/R-cmd-check.yaml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
![Lifecycle: stable](https://lifecycle.r-lib.org/articles/figures/lifecycle-stable.svg)
<!-- badges: end -->

This is a continuation of the excellent [cerebroApp](https://github.com/romanhaa/cerebroApp) R package from [Roman Hillje](https://github.com/romanhaa), which was sadly discontinued.
This is supposed to be a lightweight version that only keeps the key functions and focuses on speed.

The package can be installed with

```r
remotes::install_github('mihem/cerebroAppLite')
```

# cerebroApp

R package that provides an interactive visualization of single cell RNA-seq data.
[Seurat](https://github.com/satijalab/seurat) v3, v4 and v5 are supported.
To increase speed use [h5](https://github.com/Bioconductor/HDF5Array) or [BPCells](https://github.com/bnprks/BPCells) matrix.
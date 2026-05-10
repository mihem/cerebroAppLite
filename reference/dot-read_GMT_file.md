# Read GMT file.

This functions reads a (tab-delimited) GMT file which contains the gene
set name in the first column, the gene set description in the second
column, and the gene names in the following columns.

## Usage

``` r
.read_GMT_file(file)
```

## Arguments

- file:

  Path to GMT file.

## Value

Returns an object in the same format as from the GSA.read.gmt function
(GSA package) with gene sets, gene set names, and gene set descriptions
stored in lists.

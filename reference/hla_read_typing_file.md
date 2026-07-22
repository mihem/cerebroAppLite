# Read an uploaded HLA typing file into a raw data.frame

Delimiter is sniffed from the file name (\`.tsv\` -\> tab, otherwise
comma), so the name matters even when the bytes live in a temp file, as
they do behind a Shiny fileInput.

## Usage

``` r
hla_read_typing_file(path, name = path)
```

## Arguments

- path:

  Path to the file on disk.

- name:

  Original file name, used only to pick the delimiter. Defaults to
  \`path\`.

## Value

A data.frame with column names exactly as written in the file.

## Details

\`check.names = FALSE\` is the entire reason this is a function. R's
default rewrites any column name that is not a syntactic identifier,
which turns the documented wide format's \`HLA-A_1\` into \`HLA.A_1\` –
and \[.hla_wide_to_long\] matches columns on \`^HLA-\`. With the
default, the wide upload the Data & QC tab advertises cannot survive its
own read: every real wide file dies as "no valid HLA alleles found",
pointing the user at their data instead of at this line. Long uploads
are unaffected either way (\`sample\`, \`locus\`, \`allele\` are already
syntactic).

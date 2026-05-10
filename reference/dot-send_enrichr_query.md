# Gene enrichment using Enrichr.

Gene enrichment using Enrichr.

## Usage

``` r
.send_enrichr_query(genes, databases = NULL, URL_API = NULL)
```

## Arguments

- genes:

  Gene names or dataframe of gene names in first column and a score
  between 0 and 1 in the other.

- databases:

  Databases to search.

- URL_API:

  URL to send requests to (Enrichr API). See
  https://maayanlab.cloud/Enrichr/#stats for available databases.

## Value

Returns a data frame of enrichment terms, p-values, ...

## Author

Wajid Jawaid, modified by Roman Hillje

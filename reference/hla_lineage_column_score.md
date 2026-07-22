# Score how well a column's values read as a CD4/CD8 lineage label

Used to INFER the lineage column when a data set does not declare
\`technical_info\$lineage_column\`. The score is the share of values
that resolve to a real lineage AND do not read as an experimental
condition. Counting conditions would let a treatment or study-arm column
win the lineage role and silently change which cells the Class I / Class
II scope keeps.

## Usage

``` r
hla_lineage_column_score(values)
```

## Arguments

- values:

  A character vector of the column's values.

## Value

A share in \`\[0, 1\]\`; 0 when nothing qualifies.

# Tally every group's values in one pass

The per-node summaries (\`mode\` + \`\_dist\`) both need one thing: how
often each value occurs within each node. Computing that with
\`table()\` per node per column is what made aggregation ~95 its input
and re-pays \`match.arg\`/\`deparse\`/\`sys.call\` on every one of tens
of thousands of calls, and \`mode\` and \`\_dist\` each built their own
copy of the identical tally.

## Usage

``` r
hla_group_tally(g, v)
```

## Arguments

- g:

  Integer group id per row (1..K).

- v:

  Values, one per row. NA / "" are dropped (a cell with no label is
  absent from the summary, never a level called "NA").

## Value

list(g, v, n): one entry per (group, distinct value) pair.

## Details

This does it once per column, for every group at once: one radix
\`order()\` drops into C, and the run boundaries of the sorted \`(group,
value)\` pairs ARE the tally. Sparse by construction — a dense group x
level matrix would be 630 columns wide on a cohort like Emerson, nearly
all of it zero.

Runs come out ALPHABETICAL within each group, which is what makes the
tie-breaks below match \`sort(table(x))\`: see \[hla_group_mode()\].

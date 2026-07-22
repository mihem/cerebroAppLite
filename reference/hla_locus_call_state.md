# How completely a locus was called, per sample

A negative call ("this donor does not carry X") is only valid once BOTH
copies of the locus are known: a donor typed \`A\*01:01\` at one copy
may still carry \`A\*02:01\` at the other. Sources differ here – the
synthetic fixture writes a homozygote as two identical rows, while
published carrier calls (e.g. DeWitt) list positives only and never
repeat a homozygote – and the \`copy\` column is re-numbered by row
order on import, so it cannot tell the two apart. Row count per sample x
locus is therefore the only honest signal, and one row has to read as
"unknown second copy", not "homozygous".

## Usage

``` r
hla_locus_call_state(typing, samples, locus)
```

## Arguments

- typing:

  Canonical HLA typing table.

- samples:

  Sample names to report on.

- locus:

  Locus name, e.g. "HLA-A".

## Value

data.frame(sample, n_copies, call_state) where call_state is "complete"
(\>= 2 copies), "partial" (exactly 1) or "absent" (none).

## Details

Counted per SAMPLE, never pooled across a donor's samples: two samples
with one copy each are two partial calls, not one diploid call.

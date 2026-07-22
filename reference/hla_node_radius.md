# Node radius whose AREA is proportional to the clone count

\`r = R_MIN \* sqrt(count)\` makes area exactly proportional to
\`count\`, so twice the area means twice the units. Radius is capped at
\[HLA_NODE_R_MAX\], i.e. proportionality holds up to
\[HLA_NODE_MAX_EXACT\] units and above that every node draws the same.
Callers must state that cap rather than let it read as data; the tooltip
carries the exact count either way.

## Usage

``` r
hla_node_radius(clone_count, scale = 1)
```

## Arguments

- clone_count:

  Numeric vector of per-node clone sizes. NA and values below 1 are
  floored to 1 (a drawn node stands for at least one unit).

- scale:

  Display multiplier applied to every radius, clamped to
  \`\[HLA_NODE_SCALE_MIN, HLA_NODE_SCALE_MAX\]\`. It scales the cap by
  the same factor, so the area-proportional reading is unchanged – only
  how much of the canvas the network occupies. Invalid or non-positive
  values fall back to 1.

## Value

Numeric vector of radii in px.

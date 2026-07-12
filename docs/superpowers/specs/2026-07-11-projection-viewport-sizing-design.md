# Projection viewport sizing design

## Problem

Projection tabs currently assign Plotly a fixed viewport formula such as
`calc(100vh - 235px)`. The custom HTML legend is inserted above the Plotly
widget as a sibling and can wrap to multiple rows. A fixed subtraction cannot
account for that runtime height: large categorical legends make the whole box
overflow the viewport, while Spatial's larger fixed subtraction leaves unused
space when its legend is short.

## Constraints

- Overview, Gene expression, Spatial, and Trajectory use one sizing behavior.
- The projection box should use the available viewport height without extending
  below it on normal desktop side-by-side layouts.
- Legend wrapping, conditional rows, footer controls, and box padding must be
  measured rather than represented by tab-specific constants.
- Spatial background images and scatter points must retain their existing
  data-coordinate registration during every resize.
- Narrow layouts may still scroll because the parameter column stacks above the
  plot; the projection itself must remain usable rather than collapse to zero.

## Considered approaches

1. **Tune fixed `vh - px` offsets per tab.** Smallest change, but repeats the
   current failure whenever legend rows, fonts, controls, or viewport sizes
   change. Rejected.
2. **Make the entire box a CSS viewport-height flex container.** This avoids
   arithmetic but conflicts with Shiny/Plotly's generated fixed-height widget
   wrappers and conditional content. It also risks clipping footers and spinner
   overlays. Rejected.
3. **Measure DOM chrome and resize the Plotly widget dynamically.** A shared
   controller can subtract the widget's actual top position and actual content
   below it from the viewport, then react to legend/container/window changes.
   Selected because it directly models the required behavior and has no
   tab-specific height guesses.

## Design

Add a viewport-sizing controller to the shared projection JavaScript. For a
projection plot id, it locates the htmlwidget wrapper and containing box. Its
target height is:

```
viewport bottom
- widget wrapper top
- measured box content below the widget
- normal page bottom gap
```

The controller applies that height to both the generated htmlwidget wrapper and
the Plotly graph div, then synchronizes Plotly's explicit layout width/height
through `Plotly.relayout`. A CSS resize or `Plotly.Plots.resize()` alone is not
enough after `Plotly.react` has received explicit dimensions: the internal SVG
can retain its old height and let axis labels overflow into the footer even when
the outer div is correct. A small usability floor
prevents collapse on short or stacked layouts; when the floor cannot fit, normal
page scrolling is preferable to making the plot unusable.

The sizing element must be resolved structurally. A Plotly output wrapped by
`withSpinner()` uses the `.shiny-spinner-output-container`; an unwrapped output
uses the Plotly element itself. An arbitrary parent must never be treated as the
plot wrapper because it may be the entire box body containing legends, footers,
and controls (as in Trajectory).

Sizing runs after a legend is created, hidden, or replaced, after Plotly render,
on window resize, and through a `ResizeObserver` watching the legend and box.
Updates are scheduled through `requestAnimationFrame` and ignore unchanged
heights to avoid feedback loops.

All projection UIs use a neutral initial height only for first paint. The shared
controller becomes the runtime source of truth, removing the differing fixed
offset formulas.

## Spatial registration

The Spatial background remains owned by `js_spatial_background.js`. It maps
image bounds through Plotly's current `xaxis.l2p`/`yaxis.l2p` transforms and
reapplies placement on `plotly_afterplot`. The controller resizes the complete
Plotly viewport and does not independently resize or transform the image layer.
After Plotly resizes, the existing afterplot hook recomputes the clip rectangle,
image rectangle, and data-unit offsets, preserving point/image alignment.

## Trajectory controls

`Choose a method` and `Choose a trajectory` belong in the Trajectory Main
parameters box alongside `Color cells by`. They must not sit in a page-wide row
above the visualization. Their presence is not part of the height calculation:
the controller remains responsible for fitting any surrounding page chrome.

Projection outputs receive no synthetic marker text or tag-list attributes.
In particular, attributes must not be appended directly to the dependency-
carrying tag list returned by `plotlyOutput()`, because that can render an
attribute value as visible text.

## Verification

- Unit-test the pure target-height calculation for single-row and wrapped
  legends, Spatial's extra conditional row/footer, viewport growth, and minimum
  usable height.
- In the real Trajectory app, assert that the internal Plotly SVG and every x/y
  tick label stay inside the plot div and above the selected-cells footer.
- Source-level tests ensure every projection UI opts into the shared behavior
  and no tab-specific `calc(100vh - Npx)` formula remains.
- Existing spatial tests must pass, and JavaScript syntax must validate.
- Verify the Spatial background code still uses Plotly axis mapping and the
  afterplot synchronization hook.

// Shared plotly layout factory for projection plots.
//
// Why this file exists:
//   - overview / spatial / gene_expression / module/projection each rendered
//     a UMAP via plotly with a layout object. The four files defined four
//     near-identical ~60-line const layout objects. Color tweaks required
//     editing all four.
//   - This factory is the single source of truth. Each consumer module
//     prepends this file via `paste(shared_layouts_js, module_js)` in its
//     R UI and calls `window.cerebroProjectionLayout.make2D()` /
//     `make3D()` to get a fresh layout object.
//
// Plotly cannot read CSS variables, so the equivalent Fluent neutral hex
// values are inlined here (kept in sync with custom.css --neutral-* tokens).

(function () {
  const fontFamily =
    '"Segoe UI Variable", "Segoe UI", -apple-system, BlinkMacSystemFont, ' +
    '"Helvetica Neue", Arial, sans-serif';

  // Mirrors of custom.css Fluent neutrals — keep in sync with :root tokens.
  const C = {
    grid:         '#edebe9', // --neutral-light
    line:         '#d2d0ce', // --neutral-quaternary
    tick:         '#605e5c', // --neutral-secondary
    title:        '#323130', // --neutral-primary
    hoverBg:      'rgba(255, 255, 255, 0.95)',
    transparent:  'rgba(255, 255, 255, 0)',
  };

  function makeAxis() {
    return {
      autorange: true,
      mirror: true,
      showline: true,
      zeroline: false,
      range: [],
      gridcolor: C.grid,
      linecolor: C.line,
      tickfont:  { color: C.tick,  family: fontFamily },
      titlefont: { color: C.title, family: fontFamily },
    };
  }

  function makeHoverLabel() {
    return {
      font: { size: 12, color: C.title, family: fontFamily },
      bgcolor: C.hoverBg,
      bordercolor: C.grid,
      align: 'left',
    };
  }

  /**
   * Build a 2D projection layout.
   * @param {Object} [opts]
   * @param {string} [opts.uirevision]  if provided, sets layout.uirevision
   * @param {boolean} [opts.legend=true]  include legend.itemsizing
   *                                       (gene_expression sets false)
   * @returns {Object} a fresh plotly layout
   */
  function make2D(opts) {
    opts = opts || {};
    const layout = {
      hovermode: 'closest',
      dragmode: 'select',
      margin: { l: 50, r: 50, b: 50, t: 50, pad: 4 },
      xaxis: makeAxis(),
      yaxis: makeAxis(),
      hoverlabel: makeHoverLabel(),
      plot_bgcolor:  C.transparent,
      paper_bgcolor: C.transparent,
    };
    if (opts.legend !== false) layout.legend = { itemsizing: 'constant' };
    if (opts.uirevision != null) layout.uirevision = opts.uirevision;
    return layout;
  }

  /**
   * Build a 3D projection layout. Same options as make2D.
   */
  function make3D(opts) {
    opts = opts || {};
    const layout = {
      hovermode: 'closest',
      margin: { l: 50, r: 50, b: 50, t: 50, pad: 4 },
      scene: { xaxis: makeAxis(), yaxis: makeAxis(), zaxis: makeAxis() },
      hoverlabel: makeHoverLabel(),
      plot_bgcolor:  C.transparent,
      paper_bgcolor: C.transparent,
    };
    if (opts.legend !== false) layout.legend = { itemsizing: 'constant' };
    if (opts.uirevision != null) layout.uirevision = opts.uirevision;
    return layout;
  }

  // Idempotent: prepended into every projection module's extendShinyjs(text=)
  // means this IIFE may run multiple times in the same document; assigning
  // to window is safe.
  window.cerebroProjectionLayout = { make2D: make2D, make3D: make3D };
})();

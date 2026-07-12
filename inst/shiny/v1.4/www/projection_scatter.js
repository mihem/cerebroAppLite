// =============================================================================
// Shared projection-scatter renderer.
//
// This is spatial's mature projection JS (custom top legend, persistent x|y
// selection, group labels, group hulls, modebar-off, container sizing),
// GENERALISED so every projection tab (spatial / overview / gene_expression /
// trajectory / immune_repertoire) renders through the SAME code.
//
// The one real generalisation is PLOT-ID NAMESPACING. spatial hardcoded
// 'spatial_projection' as the DOM id, the Plotly.react target, the event
// source and the Shiny input key. Here every render call carries its own plot
// id in `params.meta.plot_id`; the legend-container id, the persistent-
// selection input key (`<plot_id>_persistent_selection`) and the Plotly target
// all derive from it. Per-plot state (the selection key set) lives in a Map
// keyed by plot id, so two projection plots never share a selection.
//
// Tab-specific features (histology background, convex-hull outlines,
// co-expression RGB colouring, multi-panel, trajectory-line shapes, IR grey
// "Other cells" background) are OPTIONAL params — a tab that doesn't use one
// simply omits it / passes an empty list.
//
// This file is prepended into each tab's extendShinyjs(text=) via
// paste(read_file(projection_scatter.js), read_file(tab_js)) exactly like the
// existing projection_layouts.js, so all functions share one global scope. It
// is idempotent: the IIFE assigns to window, safe to run once per tab.
// =============================================================================

(function () {
  if (window.cerebroProjection && window.cerebroProjection.__ready) {
    return;
  }

  // --- per-plot state ---------------------------------------------------------
  // Persistent selection, decoupled from every plot parameter. Keyed on cell
  // position (x|y), so it survives changes to the colouring variable, point
  // size, opacity, "show % of cells", background, etc. Held per plot id, so
  // each projection plot has its own independent selection.
  const selectionByPlot = new Map(); // plotId -> Set<"x|y"> (or absent)

  // Groups hidden via the legend, per plot. Pushed to Shiny so the selected-
  // cells count/panels can exclude cells in hidden groups. Kept separate from
  // the Plotly trace visibility so it survives re-renders that rebuild traces.
  const hiddenGroupsByPlot = new Map(); // plotId -> Set<groupName>
  function setHiddenGroup(plotId, groupName, hidden) {
    let set = hiddenGroupsByPlot.get(plotId);
    if (!set) {
      set = new Set();
      hiddenGroupsByPlot.set(plotId, set);
    }
    if (hidden) {
      set.add(groupName);
    } else {
      set.delete(groupName);
    }
    if (typeof Shiny !== 'undefined' && Shiny.setInputValue) {
      Shiny.setInputValue(plotId + '_hidden_groups', Array.from(set));
    }
  }

  // --- viewport sizing -------------------------------------------------------
  // Projection legends and footers are ordinary HTML outside Plotly's fixed-
  // height widget. Their height is only known after layout (and categorical
  // legends may wrap), so fixed `100vh - Npx` formulas cannot fit both sparse
  // and dense legends. Measure the real chrome and give Plotly exactly what is
  // left in the viewport instead.
  const projectionResizeState = new Map(); // plotId -> controller state
  const PROJECTION_MIN_HEIGHT = 240;
  const PROJECTION_BOTTOM_GAP = 18;
  let projectionWindowResizeBound = false;

  function projectionTargetHeight(
    viewportHeight,
    wrapperTop,
    contentBelow,
    bottomGap,
    minimumHeight
  ) {
    const available = Math.floor(
      viewportHeight - wrapperTop - contentBelow - bottomGap
    );
    return Math.max(minimumHeight, available);
  }

  // withSpinner() adds one wrapper whose bounds are exactly the output bounds.
  // Without a spinner, Plotly itself is the sizing element; its parent is the
  // whole box body and may also contain legends, footers and other controls.
  // Treating that parent as the plot double-counts its children and makes the
  // box taller than the viewport (Trajectory is intentionally spinner-free).
  function projectionSizingElement(plot) {
    const parent = plot && plot.parentElement;
    if (
      parent &&
      parent.classList &&
      parent.classList.contains('shiny-spinner-output-container')
    ) {
      return parent;
    }
    return plot;
  }

  function projectionElements(plotId) {
    const plot = document.getElementById(plotId);
    if (!plot) return null;
    const wrapper = projectionSizingElement(plot);
    const box = typeof plot.closest === 'function' ? plot.closest('.box') : null;
    if (!box || !wrapper.getBoundingClientRect || !box.getBoundingClientRect) {
      return null;
    }
    return {
      plot: plot,
      wrapper: wrapper,
      box: box,
      host: wrapper.parentElement || wrapper,
      legend: document.getElementById(plotId + '_legend'),
    };
  }

  // First-paint flash suppression. The output ships at a fixed 60vh placeholder
  // height, then the data arrives from the server and the measured viewport
  // height replaces it a frame later — so on first open the empty placeholder
  // paints and the user sees the plot jump from one size to the settled size.
  //
  // The hide must beat the very first paint, which happens the instant Shiny
  // inserts the output — before registerPlot has a plot to touch and long before
  // any render() runs (render waits on the server round trip). Only CSS in the
  // initial stylesheet is early enough. A class cannot ride on the plotly output
  // itself: the htmlwidget rewrites className on its own .js-plotly-plot div and
  // drops it. So each output is wrapped in a plain <div class="cerebro-
  // projection-gate"> (Shiny renders it, plotly never reconstructs it) and
  // custom.css hides `.cerebro-projection-gate .js-plotly-plot` from first paint.
  // This JS only REVEALS: add `is-sized` to the gate once the measured height
  // has STABILISED on a plot that already holds data, so the settled size is the
  // first thing the user sees. Keyed per plot id so a re-render never re-hides.
  //
  // "Stabilised" matters: the first measurement after data lands is not final.
  // The custom HTML legend lays out a frame later and its height feeds back into
  // the measurement (via the legend ResizeObserver), so the height steps once
  // more (e.g. 775 -> 754). Revealing on the first measurement would show 775
  // and then visibly shrink 21px. Reveal only when a measurement equals the
  // previous one (two equal frames = the legend has settled), so the user's
  // first visible frame is already the final height with zero jump.
  const PROJECTION_GATE_CLASS = 'cerebro-projection-gate';
  const PROJECTION_SIZED_CLASS = 'is-sized';
  const projectionRevealed = new Set(); // plotIds revealed at least once
  function shouldRevealProjection(fullLayoutPresent, height, settledHeight) {
    return Boolean(fullLayoutPresent) && height === settledHeight;
  }
  function revealProjectionHost(plot) {
    const gate =
      plot && typeof plot.closest === 'function'
        ? plot.closest('.' + PROJECTION_GATE_CLASS)
        : null;
    if (gate && gate.classList) gate.classList.add(PROJECTION_SIZED_CLASS);
  }

  function resizeProjectionToViewport(plotId) {
    const elements = projectionElements(plotId);
    if (!elements || typeof window.innerHeight !== 'number') return;

    const wrapperRect = elements.wrapper.getBoundingClientRect();
    const boxRect = elements.box.getBoundingClientRect();
    // Everything below Plotly (selected-cell footer, buttons, box padding) is
    // measured from the live DOM. Legend height is already represented by the
    // wrapper's top coordinate because the legend is its preceding sibling.
    const contentBelow = Math.max(0, boxRect.bottom - wrapperRect.bottom);
    const height = projectionTargetHeight(
      window.innerHeight,
      wrapperRect.top,
      contentBelow,
      PROJECTION_BOTTOM_GAP,
      PROJECTION_MIN_HEIGHT
    );
    const width = Math.floor(wrapperRect.width);
    const fullLayout = elements.plot._fullLayout;
    const plotlySizeMatches =
      fullLayout &&
      Math.abs(fullLayout.height - height) <= 1 &&
      Math.abs(fullLayout.width - width) <= 1;

    const state = projectionResizeState.get(plotId);

    // Reveal gate — evaluated BEFORE the size-matches short-circuit below, so a
    // plot that is stable-but-still-hidden (its size already matches, so the
    // short-circuit would return early) still gets revealed on this frame.
    //
    // Reveal only once the measured height has stabilised on a plot that holds
    // data (see shouldRevealProjection): the first post-data measurement is not
    // final because the legend lays out a frame later and nudges the height, so
    // revealing then would show one size and visibly shrink to the next. When
    // this measurement is not yet stable, record it and force one more resize so
    // a confirming frame is guaranteed even without any external trigger.
    //
    // Why state-driven, not a timer: do NOT "simplify" this into
    // setTimeout(reveal, N) / a debounce. The number of settling frames is not a
    // fixed duration — it depends on legend wrap, font load and viewport — so any
    // constant N either flashes (too short) or stalls visibly blank (too long) on
    // some machine. Revealing on two equal measurements is deterministic: it
    // fires exactly when layout has actually settled, on every machine, with no
    // magic number to tune.
    if (state && fullLayout && !projectionRevealed.has(plotId)) {
      if (shouldRevealProjection(fullLayout, height, state.settledHeight)) {
        revealProjectionHost(elements.plot);
        projectionRevealed.add(plotId);
      } else {
        state.settledHeight = height;
        scheduleProjectionResize(plotId);
      }
    }

    if (
      state &&
      state.height === height &&
      state.width === width &&
      plotlySizeMatches
    ) {
      return;
    }
    if (state) {
      state.height = height;
      state.width = width;
    }

    elements.wrapper.style.height = height + 'px';
    elements.plot.style.height = height + 'px';
    // Plotly.react receives an explicit width/height from the Shiny round trip.
    // Merely changing CSS and calling Plots.resize does not replace those layout
    // values, leaving the internal SVG at its old size and letting axis labels
    // overflow into the footer. Synchronise Plotly's layout itself whenever it
    // disagrees with the measured DOM target; keep resize as the pre-init/fallback
    // path for outputs that do not have a full layout yet.
    if (
      typeof Plotly !== 'undefined' &&
      fullLayout &&
      typeof Plotly.relayout === 'function' &&
      !plotlySizeMatches
    ) {
      Plotly.relayout(elements.plot, { width: width, height: height });
    } else if (
      typeof Plotly !== 'undefined' &&
      Plotly.Plots &&
      Plotly.Plots.resize
    ) {
      Plotly.Plots.resize(elements.plot);
    }
  }

  function observeProjectionElements(plotId) {
    const state = projectionResizeState.get(plotId);
    const elements = projectionElements(plotId);
    if (!state || !elements || typeof ResizeObserver === 'undefined') return;

    if (!state.observer) {
      state.observer = new ResizeObserver(function () {
        scheduleProjectionResize(plotId);
      });
      state.observer.observe(elements.box);
    }
    if (elements.legend && state.legend !== elements.legend) {
      if (state.legend) state.observer.unobserve(state.legend);
      state.legend = elements.legend;
      state.observer.observe(elements.legend);
    }
  }

  function scheduleProjectionResize(plotId) {
    let state = projectionResizeState.get(plotId);
    if (!state) {
      state = {
        frame: null,
        height: null,
        width: null,
        settledHeight: null,
        observer: null,
        legend: null,
      };
      projectionResizeState.set(plotId, state);
    }
    if (state.frame !== null) return;
    state.frame = window.requestAnimationFrame(function () {
      state.frame = null;
      observeProjectionElements(plotId);
      resizeProjectionToViewport(plotId);
    });
  }

  function bindProjectionWindowResize() {
    if (projectionWindowResizeBound) return;
    projectionWindowResizeBound = true;
    window.addEventListener('resize', function () {
      projectionResizeState.forEach(function (_state, plotId) {
        scheduleProjectionResize(plotId);
      });
    });
  }

  function getSelection(plotId) {
    const s = selectionByPlot.get(plotId);
    return s && s.size ? s : null;
  }

  // Push the current selection to Shiny as {x:[...], y:[...]} (or null) under
  // `<plot_id>_persistent_selection`. R rebuilds its "x-y" identifiers from
  // these, matching how the selected-cells table keys cells. No
  // {priority:'event'}: this is persistent selection STATE that must remain
  // readable across later reactive invalidations (an event-priority input
  // resets to null after one flush, dropping the selection on the next
  // re-render).
  function syncSelectionToShiny(plotId) {
    if (typeof Shiny === 'undefined' || !Shiny.setInputValue) return;
    const keys = selectionByPlot.get(plotId);
    let payload = null;
    if (keys && keys.size) {
      const x = [];
      const y = [];
      keys.forEach((k) => {
        const sep = k.indexOf('|');
        x.push(parseFloat(k.slice(0, sep)));
        y.push(parseFloat(k.slice(sep + 1)));
      });
      payload = { x: x, y: y };
    }
    Shiny.setInputValue(plotId + '_persistent_selection', payload);
  }

  // Record a fresh selection from a plotly_selected event.
  function setSelectionFromEvent(plotId, eventData) {
    if (!eventData || !eventData.points || !eventData.points.length) {
      selectionByPlot.delete(plotId);
    } else {
      const keys = new Set();
      eventData.points.forEach((p) => {
        keys.add(p.x + '|' + p.y);
      });
      selectionByPlot.set(plotId, keys);
    }
    syncSelectionToShiny(plotId);
  }

  // Re-apply a harvested selection to freshly built traces: mark the points
  // whose x|y is in the set as selectedpoints so Plotly keeps them at full
  // opacity and dims the rest. No-op when nothing is selected.
  function applySelection(traces, selectedKeys) {
    if (!selectedKeys || selectedKeys.size === 0) return;
    traces.forEach((trace) => {
      if (!trace.x || trace.mode === 'text' || trace.mode === 'lines') return;
      const picked = [];
      for (let i = 0; i < trace.x.length; i++) {
        if (selectedKeys.has(trace.x[i] + '|' + trace.y[i])) picked.push(i);
      }
      if (picked.length) trace.selectedpoints = picked;
    });
  }

  // The dashed selection outline lives in layout.selections, a layout-level
  // state that Plotly.react drops when it swaps in a fresh layout. Grab it from
  // the live plot so it can be carried over, but only while a selection is
  // active (a cleared selection must not resurrect the outline).
  function harvestSelectionOutline(plotId) {
    if (!getSelection(plotId)) return null;
    const pc = document.getElementById(plotId);
    if (pc && pc.layout && pc.layout.selections && pc.layout.selections.length) {
      return pc.layout.selections;
    }
    return null;
  }

  // --- zoom to selection ------------------------------------------------------
  // Extra span added to the framed box so the zoom never butts the selection
  // right up against the plot edge — a little breathing room all around. This is
  // the TOTAL fractional growth (split evenly, so each side gets half). Applied
  // after the aspect-ratio match, so it scales both axes equally and the 1:1
  // data-per-pixel is preserved.
  const ZOOM_FRAME_PADDING = 0.08;

  // Expand a data-space selection box to the plot area's pixel aspect ratio so
  // that after zooming one data unit spans the same number of pixels on x and y
  // — the selected region is framed, never stretched. We only ever GROW the
  // shorter axis (and centre the box within it), so the whole selection stays
  // visible with letterbox whitespace on the longer side, then add a uniform
  // margin on all sides. A zero-area (single point / degenerate) selection is
  // padded to a tiny non-zero span first, so the ratio maths never divides by
  // zero and Plotly gets a valid range.
  function computeEqualAspectRange(xMin, xMax, yMin, yMax, pxW, pxH) {
    let dataW = xMax - xMin;
    let dataH = yMax - yMin;
    let cx = (xMin + xMax) / 2;
    let cy = (yMin + yMax) / 2;
    // Degenerate box: give it a small span around its centre.
    if (!(dataW > 0)) dataW = Math.max(Math.abs(cx), 1) * 1e-3 || 1e-3;
    if (!(dataH > 0)) dataH = Math.max(Math.abs(cy), 1) * 1e-3 || 1e-3;
    // Guard against a zero/invalid pixel box (pre-layout): fall back to square.
    const pxRatio = pxW > 0 && pxH > 0 ? pxW / pxH : 1;
    // Target: dataW/dataH === pxW/pxH. Grow whichever axis is too short.
    if (dataW / dataH < pxRatio) {
      dataW = dataH * pxRatio; // widen x
    } else {
      dataH = dataW / pxRatio; // heighten y
    }
    // Uniform margin on all sides (scales both axes equally -> ratio unchanged).
    const scale = 1 + ZOOM_FRAME_PADDING;
    dataW *= scale;
    dataH *= scale;
    return {
      xRange: [cx - dataW / 2, cx + dataW / 2],
      yRange: [cy - dataH / 2, cy + dataH / 2],
    };
  }

  // Data-space bounding box of the currently selected points (or null).
  function selectionBounds(plotId) {
    const keys = getSelection(plotId);
    if (!keys) return null;
    let xMin = Infinity, xMax = -Infinity, yMin = Infinity, yMax = -Infinity;
    keys.forEach((k) => {
      const sep = k.indexOf('|');
      const x = parseFloat(k.slice(0, sep));
      const y = parseFloat(k.slice(sep + 1));
      if (Number.isFinite(x)) {
        if (x < xMin) xMin = x;
        if (x > xMax) xMax = x;
      }
      if (Number.isFinite(y)) {
        if (y < yMin) yMin = y;
        if (y > yMax) yMax = y;
      }
    });
    if (xMin === Infinity || yMin === Infinity) return null;
    return { xMin, xMax, yMin, yMax };
  }

  // Which plots are currently zoomed into their selection. Drives the toggle
  // (zoom in vs. reset) and the button style/label reported to Shiny.
  const zoomedPlots = new Set();
  // Plotly's native selection rectangle stashed on zoom-in (per plot), so reset
  // can restore it after it was cleared to hide the editable drag handles.
  const zoomSavedSelections = new Map();

  // Pure decision for the zoom toggle. Not zoomed -> zoom in and LOCK the plot
  // (dragmode false: no box-select while zoomed, so the user must reset before
  // selecting again). Zoomed -> reset to the full view and UNLOCK (dragmode
  // 'select'). Returned `zoomed` is the state to report to Shiny for the button.
  function nextZoomAction(isZoomed) {
    return isZoomed
      ? { zoomIn: false, zoomed: false, dragmode: 'select' }
      : { zoomIn: true, zoomed: true, dragmode: false };
  }

  // Report the zoom state to Shiny so the button can switch style/label. Named
  // <plot_id>_zoom_state; true while zoomed into the selection.
  function reportZoomState(plotId, zoomed) {
    if (typeof Shiny !== 'undefined' && Shiny.setInputValue) {
      Shiny.setInputValue(plotId + '_zoom_state', zoomed);
    }
  }

  // Toggle zoom-to-selection. Frames the selection at the true data aspect ratio
  // (no stretch) and locks selection while zoomed; toggling again resets to the
  // full autorange view and unlocks. The persistent selection and data are
  // untouched, so selected points stay highlighted throughout.
  // A dashed rectangle marking the selection bounds. While zoomed the plot is
  // locked (dragmode:false), which hides Plotly's own selection outline, so we
  // draw our own layout shape instead — it is independent of dragmode, so the
  // user still sees exactly which region was zoomed. Tagged via `name` so it can
  // be stripped on reset without touching tab-specific shapes (trajectory path).
  const ZOOM_MARKER_NAME = 'cerebro-zoom-marker';
  function zoomMarkerShape(bounds) {
    return {
      name: ZOOM_MARKER_NAME,
      type: 'rect',
      xref: 'x',
      yref: 'y',
      x0: bounds.xMin,
      x1: bounds.xMax,
      y0: bounds.yMin,
      y1: bounds.yMax,
      line: { color: '#2c7ab3', width: 1.5, dash: 'dash' },
      fillcolor: 'rgba(44, 122, 179, 0.015)',
      layer: 'above',
    };
  }
  // Current shapes minus any previous zoom marker (keeps tab shapes intact).
  function shapesWithoutZoomMarker(plot) {
    const shapes = (plot._fullLayout && plot._fullLayout.shapes) || [];
    return shapes.filter((s) => s && s.name !== ZOOM_MARKER_NAME);
  }

  function toggleZoom(plotId) {
    const plot = document.getElementById(plotId);
    if (!plot || !plot._fullLayout || typeof Plotly === 'undefined') return;
    const action = nextZoomAction(zoomedPlots.has(plotId));

    if (action.zoomIn) {
      const bounds = selectionBounds(plotId);
      if (!bounds) return; // nothing selected -> nothing to zoom into
      const xa = plot._fullLayout.xaxis;
      const ya = plot._fullLayout.yaxis;
      // Plotly stores each axis's pixel length on _length after layout.
      const pxW = xa && xa._length ? xa._length : plot._fullLayout.width;
      const pxH = ya && ya._length ? ya._length : plot._fullLayout.height;
      const r = computeEqualAspectRange(
        bounds.xMin,
        bounds.xMax,
        bounds.yMin,
        bounds.yMax,
        pxW,
        pxH
      );
      const shapes = shapesWithoutZoomMarker(plot).concat([
        zoomMarkerShape(bounds),
      ]);
      // Stash Plotly's native selection rectangle so it can be restored on
      // reset, then drop it: while zoomed we show our own static marker, so the
      // native editable outline (with its drag handles) would be a redundant,
      // misleading "you can still drag this" affordance. Clearing it also removes
      // the handles the user asked to hide.
      zoomSavedSelections.set(plotId, harvestSelectionOutline(plotId));
      Plotly.relayout(plot, {
        'xaxis.autorange': false,
        'yaxis.autorange': false,
        'xaxis.range': r.xRange,
        'yaxis.range': r.yRange,
        dragmode: action.dragmode,
        shapes: shapes,
        selections: [],
      });
      zoomedPlots.add(plotId);
    } else {
      // Restore the native selection outline harvested on zoom-in, so returning
      // to the full view leaves the box exactly as it was before zooming.
      const savedSelections = zoomSavedSelections.get(plotId) || [];
      zoomSavedSelections.delete(plotId);
      Plotly.relayout(plot, {
        'xaxis.autorange': true,
        'yaxis.autorange': true,
        dragmode: action.dragmode,
        shapes: shapesWithoutZoomMarker(plot),
        selections: savedSelections,
      });
      zoomedPlots.delete(plotId);
    }
    reportZoomState(plotId, action.zoomed);
  }

  // --- legend -----------------------------------------------------------------
  // Min/max over an array WITHOUT the spread operator. `Math.min(...arr)`
  // overflows V8's argument/stack limit (~1e5) on full Xenium/MERFISH slides.
  function finiteExtent(arr) {
    let min = Infinity;
    let max = -Infinity;
    for (let i = 0; i < arr.length; i++) {
      const v = arr[i];
      if (typeof v === 'number' && Number.isFinite(v)) {
        if (v < min) min = v;
        if (v > max) max = v;
      }
    }
    if (min === Infinity) return { min: 0, max: 0 };
    return { min, max };
  }

  // Resolve where the legend bar should live and (re)insert it there. The
  // plotly html-widget wraps the plot div in a fixed-height, overflow:hidden
  // wrapper. A legend inside that wrapper competes with the plot for the fixed
  // height and gets clipped when it wraps. Instead the legend is inserted as a
  // SIBLING of the wrapper (one level up, in the auto-height spinner/box-body
  // container), so a taller legend grows the container, never the plot.
  function ensureLegendContainer(plotId) {
    const plotContainer = document.getElementById(plotId);
    if (!plotContainer) return null;
    const widgetWrapper = plotContainer.parentElement || plotContainer;
    const host = widgetWrapper.parentElement || widgetWrapper;
    const legendId = plotId + '_legend';

    let legendContainer = document.getElementById(legendId);
    if (!legendContainer) {
      legendContainer = document.createElement('div');
      legendContainer.id = legendId;
      // Generic class so ONE CSS block styles every projection's legend.
      legendContainer.className = 'cerebro-projection-legend';
    }
    if (
      legendContainer.parentElement !== host ||
      legendContainer.nextElementSibling !== widgetWrapper
    ) {
      host.insertBefore(legendContainer, widgetWrapper);
    }
    return legendContainer;
  }

  function createCustomLegend(plotId, traces, colors) {
    const legendContainer = ensureLegendContainer(plotId);
    if (!legendContainer) return;

    legendContainer.innerHTML = '';
    legendContainer.style.display = 'flex';
    legendContainer.classList.remove('is-continuous');

    const count = traces.length;
    let fontSize = 13;
    let itemMargin = 6;
    let itemPadding = 4;
    let itemPaddingX = 6;
    let boxSize = 16;

    if (count > 10) {
      if (count <= 20) {
        fontSize = 12; itemMargin = 4; itemPadding = 3; boxSize = 14;
      } else if (count <= 30) {
        fontSize = 11; itemMargin = 3; itemPadding = 2; boxSize = 12;
      } else if (count <= 50) {
        fontSize = 10; itemMargin = 2; itemPadding = 1; boxSize = 10;
      } else {
        fontSize = 9; itemMargin = 1; itemPadding = 0; boxSize = 8;
      }
    }

    traces.forEach((traceName, index) => {
      const item = document.createElement('div');
      item.className = 'custom-legend-item';
      item.style.marginBottom = itemMargin + 'px';
      item.style.padding = itemPadding + 'px ' + itemPaddingX + 'px';

      const colorBox = document.createElement('span');
      colorBox.className = 'legend-color-box';
      colorBox.style.backgroundColor = colors[index];
      colorBox.style.width = boxSize + 'px';
      colorBox.style.height = boxSize + 'px';

      const text = document.createElement('span');
      text.className = 'legend-text';
      text.innerText = traceName;
      text.style.fontSize = fontSize + 'px';

      item.appendChild(colorBox);
      item.appendChild(text);

      // Toggle visibility on click. Trace index corresponds to legend index.
      item.onclick = function () {
        if (legendContainer.dataset.isDragging === 'true') return;
        const plot = document.getElementById(plotId);
        let isVisible = true;
        if (plot.data && plot.data[index]) {
          isVisible =
            plot.data[index].visible !== false &&
            plot.data[index].visible !== 'legendonly';
        }
        const newVisible = isVisible ? false : true;
        Plotly.restyle(plotId, { visible: newVisible }, [index]);
        item.classList.toggle('legend-item-hidden', isVisible);
        // Report the now-hidden groups to Shiny so the selected-cells count and
        // panels can drop cells in hidden groups. traceName is the group label.
        setHiddenGroup(plotId, traceName, !newVisible);
      };

      legendContainer.appendChild(item);
    });
    scheduleProjectionResize(plotId);
  }

  function removeCustomLegend(plotId) {
    const legendContainer = document.getElementById(plotId + '_legend');
    if (legendContainer) legendContainer.style.display = 'none';
    scheduleProjectionResize(plotId);
  }

  function createContinuousLegend(plotId, title, colorMin, colorMax, colorscale) {
    const legendContainer = ensureLegendContainer(plotId);
    if (!legendContainer) return;

    legendContainer.innerHTML = '';
    legendContainer.style.display = 'flex';
    legendContainer.classList.add('is-continuous');

    const header = document.createElement('div');
    header.className = 'legend-header';
    const titleEl = document.createElement('span');
    titleEl.className = 'legend-title-text';
    titleEl.innerText = title;
    header.appendChild(titleEl);
    legendContainer.appendChild(header);

    const contentEl = document.createElement('div');
    contentEl.className = 'continuous-legend-content';

    const gradientEl = document.createElement('div');
    gradientEl.className = 'continuous-legend-gradient';
    const gradientColors = colorscale.map((item) => item[1]).join(', ');
    gradientEl.style.background = `linear-gradient(to right, ${gradientColors})`;

    const minLabel = document.createElement('span');
    minLabel.className = 'continuous-legend-label';
    minLabel.innerText = colorMin.toFixed(2);

    const maxLabel = document.createElement('span');
    maxLabel.className = 'continuous-legend-label';
    maxLabel.innerText = colorMax.toFixed(2);

    contentEl.appendChild(minLabel);
    contentEl.appendChild(gradientEl);
    contentEl.appendChild(maxLabel);
    legendContainer.appendChild(contentEl);
    scheduleProjectionResize(plotId);
  }

  function removeContinuousLegend(plotId) {
    const legendContainer = document.getElementById(plotId + '_legend');
    if (legendContainer) {
      legendContainer.classList.remove('is-continuous');
      legendContainer.style.display = 'none';
    }
    scheduleProjectionResize(plotId);
  }

  // Fluent blue ramp for continuous colouring (matches --theme-primary family).
  const CONTINUOUS_COLORSCALE = [
    [0,   '#f7fbff'],
    [0.2, '#dbeaf6'],
    [0.4, '#a4c8e1'],
    [0.6, '#5e9bc7'],
    [0.8, '#2c7ab3'],
    [1,   '#0c4b85'],
  ];

  // gene_expression lets the user pick a Plotly NAMED colorscale (a string like
  // 'YlGnBu'). Plotly's marker accepts the string directly, but the custom
  // continuous legend needs a [[stop,color],...] array to build its gradient.
  // Map each named scale we expose to a representative gradient so the legend
  // matches the scatter. reversescale is applied by the caller when needed.
  const NAMED_COLORSCALES = {
    YlGnBu: [[0,'#ffffd9'],[0.25,'#c7e9b4'],[0.5,'#41b6c4'],[0.75,'#225ea8'],[1,'#081d58']],
    YlOrRd: [[0,'#ffffcc'],[0.25,'#fed976'],[0.5,'#fd8d3c'],[0.75,'#e31a1c'],[1,'#800026']],
    Blues:  [[0,'#f7fbff'],[0.25,'#c6dbef'],[0.5,'#6baed6'],[0.75,'#2171b5'],[1,'#08306b']],
    Greens: [[0,'#f7fcf5'],[0.25,'#c7e9c0'],[0.5,'#74c476'],[0.75,'#238b45'],[1,'#00441b']],
    Reds:   [[0,'#fff5f0'],[0.25,'#fcbba1'],[0.5,'#fb6a4a'],[0.75,'#cb181d'],[1,'#67000d']],
    RdBu:   [[0,'#67001f'],[0.25,'#f4a582'],[0.5,'#f7f7f7'],[0.75,'#92c5de'],[1,'#053061']],
    Viridis:[[0,'#440154'],[0.25,'#3b528b'],[0.5,'#21918c'],[0.75,'#5ec962'],[1,'#fde725']],
  };

  // Resolve any colorscale spec (array, named string, or undefined) to a
  // [[stop,color],...] array for the legend gradient. `reverse` flips it to
  // match a reversescale marker.
  function resolveColorscaleArray(scale, reverse) {
    let arr;
    if (Array.isArray(scale)) {
      arr = scale;
    } else if (typeof scale === 'string' && NAMED_COLORSCALES[scale]) {
      arr = NAMED_COLORSCALES[scale];
    } else {
      arr = CONTINUOUS_COLORSCALE;
    }
    if (reverse) {
      arr = arr.map((item, i, a) => [item[0], a[a.length - 1 - i][1]]);
    }
    return arr;
  }

  const HOVERLABEL = {
    bgcolor: 'rgba(255, 255, 255, 0.95)',
    bordercolor: '#E2E8F0',
    font: {
      color: '#2D3748',
      size: 12,
      family:
        '-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif',
    },
  };

  // --- layout helpers ---------------------------------------------------------
  function baseLayout2D() {
    return JSON.parse(
      JSON.stringify(window.cerebroProjectionLayout.make2D({ uirevision: 'true' }))
    );
  }
  function baseLayout3D() {
    return JSON.parse(
      JSON.stringify(window.cerebroProjectionLayout.make3D({ uirevision: 'true' }))
    );
  }

  function applyContainerSize(layout, plotId, container) {
    if (container && container.width && container.height) {
      layout.width = container.width;
      layout.height = container.height;
    } else {
      const plotContainer = document.getElementById(plotId);
      if (plotContainer && plotContainer.parentElement) {
        layout.width = plotContainer.parentElement.clientWidth;
        layout.height = plotContainer.parentElement.clientHeight;
      }
    }
  }

  function apply2DAxes(layout, data) {
    if (data.reset_axes) {
      layout.xaxis.autorange = true;
      delete layout.xaxis.range;
      layout.yaxis.autorange = true;
      delete layout.yaxis.range;
    } else {
      layout.xaxis.autorange = false;
      layout.xaxis.range = Array.isArray(data.x_range) ? [...data.x_range] : data.x_range;
      layout.yaxis.autorange = false;
      layout.yaxis.range = Array.isArray(data.y_range) ? [...data.y_range] : data.y_range;
    }
  }

  const REACT_CONFIG = { displayModeBar: false, displaylogo: false };

  // Optional histology background sync (spatial only). syncProjectionBackground
  // is defined in js_spatial_background.js and only prepended for the spatial
  // tab; guard so the other tabs (which never pass a background) don't error.
  function syncBackground(plotId, meta) {
    if (typeof shinyjs.syncSpatialBackground !== 'function') return;
    if (meta && meta.background_image) {
      shinyjs.syncSpatialBackground(
        meta.background_image,
        meta.background_flip_x,
        meta.background_flip_y,
        meta.background_scale_x,
        meta.background_scale_y,
        meta.background_opacity,
        meta.image_bounds,
        meta.background_offset_x,
        meta.background_offset_y
      );
    } else {
      shinyjs.syncSpatialBackground(null, false, false, 1, 1, 1, null, 0, 0);
    }
  }

  function detachModebar(plotId) {
    const plotContainer = document.getElementById(plotId);
    if (!plotContainer) return;
    const parent = plotContainer.parentElement;
    if (parent) {
      parent.querySelectorAll('.detached-modebar').forEach((el) => el.remove());
    }
    plotContainer
      .querySelectorAll('.modebar-container, .modebar')
      .forEach((el) => el.remove());
  }

  // Our own plotly_selected handlers, one per plot id, so we can detach ONLY
  // ours on re-render without touching plotly-binding's handler on the same div.
  const selectionHandlers = new Map(); // plotId -> function

  // Attach the plotly_selected listener. This runs in EVERY render's .then(),
  // because Plotly.react rebuilds the graph div's event emitter and drops
  // listeners bound to the previous one — a one-time DOM-flag guard would keep
  // the flag set while the actual listener was gone, so selection would work on
  // the first render and silently stop after any re-colour/re-size. So we
  // detach our prior handler (if the emitter still holds it) and re-bind fresh
  // each time. We deliberately do NOT clear on plotly_deselect (Plotly fires
  // deselect during every re-render); selection is cleared only by an empty
  // selection event or the Clear action.
  function setupSelection(plotId) {
    const plotContainer = document.getElementById(plotId);
    if (!plotContainer || typeof plotContainer.on !== 'function') return;
    const prev = selectionHandlers.get(plotId);
    if (prev && typeof plotContainer.removeListener === 'function') {
      plotContainer.removeListener('plotly_selected', prev);
    }
    const handler = function (eventData) {
      if (eventData && eventData.points && eventData.points.length) {
        setSelectionFromEvent(plotId, eventData);
      }
    };
    selectionHandlers.set(plotId, handler);
    plotContainer.on('plotly_selected', handler);
  }

  // --- the four render entry points -------------------------------------------
  // Each takes the SAME (meta, data, hover, group_centers, container, extra)
  // positional shape the R dispatchers already produce. `extra` carries
  // tab-specific optional payloads (group hulls, trajectory shapes,
  // coexpression swatch colours). meta.plot_id selects the target.

  function render2DContinuous(meta, data, hover, group_centers, container, extra) {
    const plotId = meta.plot_id;
    extra = extra || {};
    const selectedKeys = getSelection(plotId);
    const selectionOutline = harvestSelectionOutline(plotId);
    removeCustomLegend(plotId);
    removeContinuousLegend(plotId);

    const traces = [];
    const isCoexpr = meta.color_type === 'coexpression';
    if (isCoexpr) {
      traces.push({
        x: data.x,
        y: data.y,
        mode: 'markers',
        type: 'scattergl',
        marker: {
          size: data.point_size,
          opacity: data.point_opacity,
          line: data.point_line,
          color: data.color,
        },
        hoverinfo: hover.hoverinfo,
        hoverlabel: HOVERLABEL,
      });
      applySelection(traces, selectedKeys);
      createCustomLegend(plotId, meta.traces, extra.coexpr_colors || meta.coexpr_colors);
    } else {
      const { min: colorMin, max: colorMax } = finiteExtent(data.color);
      // gene_expression passes an explicit colour range + scale; honour it.
      const cmin = data.color_range ? data.color_range[0] : colorMin;
      const cmax = data.color_range ? data.color_range[1] : colorMax;
      const colorscale = data.colorscale || CONTINUOUS_COLORSCALE;
      const marker = {
        size: data.point_size,
        opacity: data.point_opacity,
        line: data.point_line,
        color: data.color,
        cmin: cmin,
        cmax: cmax,
        colorscale: colorscale,
        showscale: false,
      };
      if (data.reversescale) marker.reversescale = true;
      traces.push({
        x: data.x,
        y: data.y,
        mode: 'markers',
        type: 'scattergl',
        marker: marker,
        hoverinfo: hover.hoverinfo,
        text: hover.text,
        hoverlabel: HOVERLABEL,
      });
      applySelection(traces, selectedKeys);
      createContinuousLegend(
        plotId,
        meta.color_variable,
        cmin,
        cmax,
        resolveColorscaleArray(colorscale, data.reversescale)
      );
    }

    const layout = baseLayout2D();
    if (selectionOutline) layout.selections = selectionOutline;
    if (extra.shapes) layout.shapes = extra.shapes;
    apply2DAxes(layout, data);
    applyContainerSize(layout, plotId, container);

    Plotly.react(plotId, traces, layout, REACT_CONFIG).then(() => {
      setupSelection(plotId);
      syncBackground(plotId, meta);
      detachModebar(plotId);
      scheduleProjectionResize(plotId);
    });
  }

  function render3DContinuous(meta, data, hover, group_centers, container, extra) {
    const plotId = meta.plot_id;
    extra = extra || {};
    const selectedKeys = getSelection(plotId);
    removeCustomLegend(plotId);
    removeContinuousLegend(plotId);

    const { min: colorMin, max: colorMax } = finiteExtent(data.color);
    const cmin = data.color_range ? data.color_range[0] : colorMin;
    const cmax = data.color_range ? data.color_range[1] : colorMax;
    const colorscale = data.colorscale || CONTINUOUS_COLORSCALE;
    const marker = {
      size: data.point_size,
      opacity: data.point_opacity,
      line: data.point_line,
      color: data.color,
      cmin: cmin,
      cmax: cmax,
      colorscale: colorscale,
      showscale: false,
    };
    if (data.reversescale) marker.reversescale = true;
    const traces = [{
      x: data.x,
      y: data.y,
      z: data.z,
      mode: 'markers',
      type: 'scatter3d',
      marker: marker,
      hoverinfo: hover.hoverinfo,
      text: hover.text,
      hoverlabel: HOVERLABEL,
      showlegend: false,
    }];
    applySelection(traces, selectedKeys);
    createContinuousLegend(
      plotId,
      meta.color_variable,
      cmin,
      cmax,
      resolveColorscaleArray(colorscale, data.reversescale)
    );

    const layout = baseLayout3D();
    applyContainerSize(layout, plotId, container);
    Plotly.react(plotId, traces, layout, REACT_CONFIG).then(() => {
      setupSelection(plotId);
      syncBackground(plotId, meta);
      detachModebar(plotId);
      scheduleProjectionResize(plotId);
    });
  }

  function render2DCategorical(meta, data, hover, group_centers, container, extra) {
    const plotId = meta.plot_id;
    extra = extra || {};
    const selectedKeys = getSelection(plotId);
    const selectionOutline = harvestSelectionOutline(plotId);
    removeContinuousLegend(plotId);
    createCustomLegend(plotId, meta.traces, data.color);

    const traces = data.x.map((xVal, i) => ({
      x: xVal,
      y: data.y[i],
      name: meta.traces[i],
      mode: 'markers',
      type: 'scattergl',
      marker: {
        size: data.point_size,
        opacity: data.point_opacity,
        line: data.point_line,
        color: data.color[i],
      },
      hoverinfo: hover.hoverinfo,
      text: hover.text[i],
      hoverlabel: HOVERLABEL,
      showlegend: false,
    }));

    // Optional per-group convex-hull outlines (spatial). Drawn under labels.
    const hulls = extra.group_hulls;
    if (hulls && hulls.group && hulls.group.length >= 1) {
      hulls.group.forEach((g, i) => {
        traces.push({
          x: hulls.x[i],
          y: hulls.y[i],
          type: 'scatter',
          mode: 'lines',
          name: g + ' region',
          line: { color: hulls.color[i], width: 2 },
          fill: 'toself',
          fillcolor: 'rgba(0,0,0,0)',
          opacity: 0.7,
          hoverinfo: 'skip',
          inherit: false,
          showlegend: false,
        });
      });
    }

    if (group_centers && group_centers.group && group_centers.group.length >= 1) {
      traces.push({
        x: group_centers.x,
        y: group_centers.y,
        text: group_centers.group,
        type: 'scatter',
        mode: 'text',
        name: 'Labels',
        textposition: 'middle center',
        textfont: { color: '#000000', size: 16 },
        hoverinfo: 'skip',
        inherit: false,
        showlegend: false,
      });
    }

    applySelection(traces, selectedKeys);

    const layout = baseLayout2D();
    if (selectionOutline) layout.selections = selectionOutline;
    if (extra.shapes) layout.shapes = extra.shapes;
    apply2DAxes(layout, data);
    applyContainerSize(layout, plotId, container);

    Plotly.react(plotId, traces, layout, REACT_CONFIG).then(() => {
      setupSelection(plotId);
      syncBackground(plotId, meta);
      detachModebar(plotId);
      scheduleProjectionResize(plotId);
    });
  }

  function render3DCategorical(meta, data, hover, group_centers, container, extra) {
    const plotId = meta.plot_id;
    extra = extra || {};
    const selectedKeys = getSelection(plotId);
    removeContinuousLegend(plotId);
    createCustomLegend(plotId, meta.traces, data.color);

    const traces = data.x.map((xVal, i) => ({
      x: xVal,
      y: data.y[i],
      z: data.z[i],
      name: meta.traces[i],
      mode: 'markers',
      type: 'scatter3d',
      marker: {
        size: data.point_size,
        opacity: data.point_opacity,
        line: data.point_line,
        color: data.color[i],
      },
      hoverinfo: hover.hoverinfo,
      text: hover.text[i],
      hoverlabel: HOVERLABEL,
      showlegend: false,
    }));

    if (group_centers && group_centers.group && group_centers.group.length >= 1) {
      traces.push({
        x: group_centers.x,
        y: group_centers.y,
        z: group_centers.z,
        text: group_centers.group,
        type: 'scatter3d',
        mode: 'text',
        name: 'Labels',
        textposition: 'middle center',
        textfont: { color: '#000000', size: 16 },
        hoverinfo: 'skip',
        inherit: false,
        showlegend: false,
      });
    }

    applySelection(traces, selectedKeys);

    const layout = baseLayout3D();
    applyContainerSize(layout, plotId, container);
    Plotly.react(plotId, traces, layout, REACT_CONFIG).then(() => {
      setupSelection(plotId);
      syncBackground(plotId, meta);
      detachModebar(plotId);
      scheduleProjectionResize(plotId);
    });
  }

  // Clear the selection for one plot (button / Esc / Delete). Also drop any
  // zoom-into-selection state: with no selection there is nothing to stay zoomed
  // on, so return to the full autorange view, unlock, and reset the button.
  function clearSelection(plotId) {
    selectionByPlot.delete(plotId);
    syncSelectionToShiny(plotId);
    const wasZoomed = zoomedPlots.delete(plotId);
    zoomSavedSelections.delete(plotId);
    if (wasZoomed) reportZoomState(plotId, false);
    const plotContainer = document.getElementById(plotId);
    if (plotContainer && plotContainer.data) {
      const relayout = { selections: [], dragmode: 'select' };
      if (wasZoomed) {
        relayout['xaxis.autorange'] = true;
        relayout['yaxis.autorange'] = true;
        relayout.shapes = shapesWithoutZoomMarker(plotContainer);
      }
      Plotly.update(plotId, { selectedpoints: null }, relayout).then(function () {
        plotContainer.emit('plotly_deselect');
      });
    }
  }

  function getContainerDimensions(plotId) {
    const plotContainer = document.getElementById(plotId);
    if (plotContainer && plotContainer.parentElement) {
      return {
        width: plotContainer.parentElement.clientWidth,
        height: plotContainer.parentElement.clientHeight,
      };
    }
    return { width: 0, height: 0 };
  }

  // Global Delete/Backspace/Escape -> clear the visible projection's selection.
  // Any registered plot whose Clear button is currently visible is cleared.
  const registeredPlots = new Set();
  let keyHandlerBound = false;
  function bindKeyHandler() {
    if (keyHandlerBound) return;
    keyHandlerBound = true;
    document.addEventListener('keydown', function (e) {
      if (e.key !== 'Delete' && e.key !== 'Backspace' && e.key !== 'Escape') return;
      const tag = (e.target.tagName || '').toLowerCase();
      if (
        tag === 'input' || tag === 'textarea' || tag === 'select' ||
        e.target.isContentEditable
      ) {
        return;
      }
      registeredPlots.forEach((plotId) => {
        const btn = document.getElementById(plotId + '_clear_selection');
        if (btn && btn.offsetParent !== null) {
          e.preventDefault();
          btn.click();
        }
      });
    });
  }

  // Public API. Each tab's thin shinyjs wrappers delegate here; nothing else
  // needs to know about plot ids beyond passing meta.plot_id.
  window.cerebroProjection = {
    __ready: true,
    render2DContinuous: render2DContinuous,
    render3DContinuous: render3DContinuous,
    render2DCategorical: render2DCategorical,
    render3DCategorical: render3DCategorical,
    clearSelection: clearSelection,
    zoomToSelection: toggleZoom,
    getContainerDimensions: getContainerDimensions,
    // Hide both legend variants for a plot. Used by tab-specific render modes
    // that draw their own legend (gene_expression multi-panel uses a native
    // plotly colorbar), so the shared custom legend bar doesn't linger above.
    hideLegend: function (plotId) {
      removeCustomLegend(plotId);
      removeContinuousLegend(plotId);
    },
    registerPlot: function (plotId) {
      registeredPlots.add(plotId);
      bindKeyHandler();
      bindProjectionWindowResize();
      scheduleProjectionResize(plotId);
    },
    _finiteExtent: finiteExtent,
    _projectionTargetHeight: projectionTargetHeight,
    _projectionSizingElement: projectionSizingElement,
    _revealProjectionHost: revealProjectionHost,
    _shouldRevealProjection: shouldRevealProjection,
    _projectionGateClass: PROJECTION_GATE_CLASS,
    _projectionSizedClass: PROJECTION_SIZED_CLASS,
    _computeEqualAspectRange: computeEqualAspectRange,
    _nextZoomAction: nextZoomAction,
    _zoomMarkerShape: zoomMarkerShape,
    _shapesWithoutZoomMarker: shapesWithoutZoomMarker,
  };

  bindKeyHandler();
})();

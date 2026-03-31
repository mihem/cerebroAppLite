// layout for 2D projections in a single panel
const expression_projection_layout_2D = {
  uirevision: 'true',
  hovermode: 'closest',
  dragmode: 'select',
  margin: {
    l: 50,
    r: 50,
    b: 50,
    t: 50,
    pad: 4,
  },
  xaxis: {
    autorange: true,
    mirror: true,
    showline: true,
    zeroline: false,
    range: [],
    gridcolor: '#E2E8F0',
    linecolor: '#CBD5E0',
    tickfont: {
      color: '#718096',
      family: '-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif',
    },
  },
  yaxis: {
    autorange: true,
    mirror: true,
    showline: true,
    zeroline: false,
    range: [],
    gridcolor: '#E2E8F0',
    linecolor: '#CBD5E0',
    tickfont: {
      color: '#718096',
      family: '-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif',
    },
  },
  hoverlabel: {
    font: {
      size: 12,
      color: '#2D3748',
      family: '-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif',
    },
    bgcolor: 'rgba(255, 255, 255, 0.95)',
    bordercolor: '#E2E8F0',
    align: 'left',
  },
  plot_bgcolor: 'rgba(255, 255, 255, 0)',
  paper_bgcolor: 'rgba(255, 255, 255, 0)',
  shapes: [],
};

// layout for 2D projections with multiple panels
const expression_projection_layout_2D_multi_panel = {
  uirevision: 'true',
  hovermode: 'closest',
  margin: {
    l: 50,
    r: 50,
    b: 50,
    t: 50,
    pad: 4,
  },
  hoverlabel: {
    font: {
      size: 12,
      color: '#2D3748',
      family: '-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif',
    },
    bgcolor: 'rgba(255, 255, 255, 0.95)',
    bordercolor: '#E2E8F0',
    align: 'left',
  },
  plot_bgcolor: 'rgba(255, 255, 255, 0)',
  paper_bgcolor: 'rgba(255, 255, 255, 0)',
  shapes: [],
};

// layout for 3D projections
const expression_projection_layout_3D = {
  uirevision: 'true',
  hovermode: 'closest',
  margin: {
    l: 50,
    r: 50,
    b: 50,
    t: 50,
    pad: 4,
  },
  scene: {
    xaxis: {
      autorange: true,
      mirror: true,
      showline: true,
      zeroline: false,
      range: [],
      gridcolor: '#E2E8F0',
      linecolor: '#CBD5E0',
      tickfont: {
        color: '#718096',
        family: '-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif',
      },
    },
    yaxis: {
      autorange: true,
      mirror: true,
      showline: true,
      zeroline: false,
      range: [],
      gridcolor: '#E2E8F0',
      linecolor: '#CBD5E0',
      tickfont: {
        color: '#718096',
        family: '-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif',
      },
    },
    zaxis: {
      autorange: true,
      mirror: true,
      showline: true,
      zeroline: false,
      gridcolor: '#E2E8F0',
      linecolor: '#CBD5E0',
      tickfont: {
        color: '#718096',
        family: '-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif',
      },
    },
  },
  hoverlabel: {
    font: {
      size: 12,
      color: '#2D3748',
      family: '-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif',
    },
    bgcolor: 'rgba(255, 255, 255, 0.95)',
    bordercolor: '#E2E8F0',
    align: 'left',
  },
  plot_bgcolor: 'rgba(255, 255, 255, 0)',
  paper_bgcolor: 'rgba(255, 255, 255, 0)',
};

// Inject CSS for expression projection
(function () {
  const style = document.createElement('style');
  style.innerHTML = `
    /* Continuous Legend Styles for Expression */
    #expression_projection_continuous_legend {
      position: absolute;
      top: 10px;
      right: 10px;
      background: rgba(255, 255, 255, 0.95);
      border: 1px solid #E2E8F0;
      border-radius: 8px;
      padding: 12px;
      z-index: 1000;
      box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.1);
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif;
      cursor: move;
      min-width: 80px;
    }

    /* Legend Header with Drag Handle */
    .legend-header {
      display: flex;
      align-items: center;
      margin-bottom: 8px;
      padding-bottom: 6px;
      border-bottom: 1px solid #E2E8F0;
      cursor: grab;
    }
    .legend-header:active {
      cursor: grabbing;
    }
    .legend-drag-handle {
      display: flex;
      flex-direction: column;
      gap: 2px;
      margin-right: 8px;
      opacity: 0.4;
      transition: opacity 0.2s ease;
    }
    .expression-continuous-legend-content:hover .legend-drag-handle,
    #expression_projection_continuous_legend:hover .legend-drag-handle {
      opacity: 0.7;
    }
    .legend-drag-handle-dots {
      display: flex;
      gap: 2px;
    }
    .legend-drag-handle-dot {
      width: 3px;
      height: 3px;
      background-color: #718096;
      border-radius: 50%;
    }
    .legend-title-text {
      font-size: 12px;
      color: #718096;
      font-weight: 500;
      flex-grow: 1;
    }

    /* Drag Tip Tooltip */
    .legend-drag-tip {
      position: absolute;
      top: -8px;
      left: 50%;
      transform: translateX(-50%) translateY(-100%);
      background: #2D3748;
      color: white;
      padding: 6px 10px;
      border-radius: 6px;
      font-size: 11px;
      white-space: nowrap;
      box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.15);
      z-index: 1001;
      animation: legendTipFadeIn 0.3s ease;
    }
    .legend-drag-tip::after {
      content: '';
      position: absolute;
      bottom: -6px;
      left: 50%;
      transform: translateX(-50%);
      border-width: 6px 6px 0 6px;
      border-style: solid;
      border-color: #2D3748 transparent transparent transparent;
    }
    @keyframes legendTipFadeIn {
      from { opacity: 0; transform: translateX(-50%) translateY(-90%); }
      to { opacity: 1; transform: translateX(-50%) translateY(-100%); }
    }
    @keyframes legendTipFadeOut {
      from { opacity: 1; transform: translateX(-50%) translateY(-100%); }
      to { opacity: 0; transform: translateX(-50%) translateY(-90%); }
    }

    .expression-continuous-legend-title {
      font-size: 13px;
      color: #2D3748;
      font-weight: 500;
      margin-bottom: 8px;
      text-align: center;
    }
    .expression-continuous-legend-gradient {
      width: 20px;
      height: 150px;
      margin: 0 auto;
      border-radius: 4px;
      box-shadow: 0 1px 2px rgba(0, 0, 0, 0.1);
    }
    .expression-continuous-legend-labels {
      display: flex;
      flex-direction: column;
      justify-content: space-between;
      height: 150px;
      margin-left: 8px;
    }
    .expression-continuous-legend-label {
      font-size: 11px;
      color: #718096;
      font-weight: 400;
    }
    .expression-continuous-legend-content {
      display: flex;
      align-items: center;
    }
    .expression-detached-modebar {
      position: absolute !important;
      top: 0px !important;
      right: 0px !important;
      z-index: 1001 !important;
    }
    .expression-detached-modebar .modebar-btn {
      background: transparent;
      border: none;
      border-radius: 4px;
      box-shadow: none;
      transition: all 0.2s ease;
    }
    .expression-detached-modebar .modebar-btn:hover {
      background: rgba(91, 124, 153, 0.1);
      border: none;
      transform: translateY(-1px);
      box-shadow: none;
    }
    .expression-detached-modebar .modebar-btn svg {
      fill: #5B7C99;
    }
    .expression-detached-modebar .modebar-btn:hover svg {
      fill: #3D5A73;
    }
    .expression-detached-modebar .modebar-group {
      display: flex !important;
      flex-direction: row !important;
      align-items: center !important;
      gap: 4px !important;
    }
    .expression-detached-modebar .modebar {
      display: flex !important;
      flex-direction: row !important;
      align-items: center !important;
      gap: 8px !important;
    }
  `;
  document.head.appendChild(style);
})();

// default structure of input data
const expression_projection_default_params = {
  data: {
    x: [],
    y: [],
    z: [],
    color: [],
    size: '',
    opacity: '',
    line: {},
    x_range: [],
    y_range: [],
    reset_axes: false,
  },
  hover: {
    hoverinfo: '',
    text: [],
  },
  color: {
    scale: '',
    range: [0, 1],
  },
  trajectory: [],
};

// =============================================================================
// Custom Legend Helper Functions
// =============================================================================

// Helper: Create legend drag handle
function createLegendDragHandle() {
  const handle = document.createElement('div');
  handle.className = 'legend-drag-handle';

  const row1 = document.createElement('div');
  row1.className = 'legend-drag-handle-dots';
  const row2 = document.createElement('div');
  row2.className = 'legend-drag-handle-dots';

  for (let i = 0; i < 3; i++) {
    const dot1 = document.createElement('div');
    dot1.className = 'legend-drag-handle-dot';
    row1.appendChild(dot1);
    const dot2 = document.createElement('div');
    dot2.className = 'legend-drag-handle-dot';
    row2.appendChild(dot2);
  }

  handle.appendChild(row1);
  handle.appendChild(row2);
  return handle;
}

// Helper: Create legend header with drag handle
function createLegendHeader(titleText) {
  const header = document.createElement('div');
  header.className = 'legend-header';

  const handle = createLegendDragHandle();
  header.appendChild(handle);

  if (titleText) {
    const title = document.createElement('div');
    title.className = 'legend-title-text';
    title.innerText = titleText;
    header.appendChild(title);
  }

  return header;
}

// Helper: Show first-time drag tip
function showLegendDragTip(legendContainer) {
  // Check if user has already dragged before
  if (localStorage.getItem('cerebro_legend_dragged')) {
    return;
  }

  // Create tip element
  const tip = document.createElement('div');
  tip.className = 'legend-drag-tip';
  tip.innerHTML = '💡 Drag to reposition';
  legendContainer.appendChild(tip);

  // Auto-hide after 4 seconds
  setTimeout(() => {
    if (tip.parentElement) {
      tip.style.animation = 'legendTipFadeOut 0.3s ease forwards';
      setTimeout(() => tip.remove(), 300);
    }
  }, 4000);
}

// Make an element draggable
shinyjs.expressionMakeDraggable = function (el) {
  let isDragging = false;
  let hasMoved = false;
  let startX, startY, initialLeft, initialTop;

  el.onmousedown = function (e) {
    // Only left mouse button
    if (e.button !== 0) return;

    isDragging = true;
    hasMoved = false;
    startX = e.clientX;
    startY = e.clientY;

    // Get current position
    const rect = el.getBoundingClientRect();
    const parentRect = el.parentElement.getBoundingClientRect();

    // Convert to relative position (left/top)
    initialLeft = rect.left - parentRect.left;
    initialTop = rect.top - parentRect.top;

    // Switch to left/top positioning if not already
    el.style.right = 'auto';
    el.style.bottom = 'auto';
    el.style.left = initialLeft + 'px';
    el.style.top = initialTop + 'px';

    el.style.cursor = 'grabbing';

    document.addEventListener('mousemove', onMouseMove);
    document.addEventListener('mouseup', onMouseUp);

    // Prevent default text selection
    e.preventDefault();
  };

  function onMouseMove(e) {
    if (!isDragging) return;

    const dx = e.clientX - startX;
    const dy = e.clientY - startY;

    if (dx !== 0 || dy !== 0) {
      hasMoved = true;
      el.dataset.isDragging = 'true';

      // Mark as dragged in localStorage so tip doesn't show again
      if (!localStorage.getItem('cerebro_legend_dragged')) {
        localStorage.setItem('cerebro_legend_dragged', 'true');
        // Remove tip if exists
        const tip = el.querySelector('.legend-drag-tip');
        if (tip) tip.remove();
      }
    }

    el.style.left = initialLeft + dx + 'px';
    el.style.top = initialTop + dy + 'px';
  }

  function onMouseUp(e) {
    isDragging = false;
    el.style.cursor = 'move';
    document.removeEventListener('mousemove', onMouseMove);
    document.removeEventListener('mouseup', onMouseUp);

    if (hasMoved) {
      // Keep the flag for a short moment to block click events on children
      setTimeout(() => {
        el.dataset.isDragging = 'false';
      }, 50);
    } else {
      el.dataset.isDragging = 'false';
    }
  }
};

// Create continuous legend for expression
shinyjs.expressionCreateContinuousLegend = function (title, colorMin, colorMax, colorscale) {
  const plotContainer = document.getElementById('expression_projection');
  if (!plotContainer) return;

  const parent = plotContainer.parentElement;
  if (getComputedStyle(parent).position === 'static') {
    parent.style.position = 'relative';
  }

  let legendContainer = document.getElementById('expression_projection_continuous_legend');
  if (!legendContainer) {
    legendContainer = document.createElement('div');
    legendContainer.id = 'expression_projection_continuous_legend';
    parent.appendChild(legendContainer);
  }

  shinyjs.expressionMakeDraggable(legendContainer);
  legendContainer.innerHTML = '';
  legendContainer.style.display = 'block';

  // Add Header
  legendContainer.appendChild(createLegendHeader(title));

  // Show tip if needed
  showLegendDragTip(legendContainer);

  const contentEl = document.createElement('div');
  contentEl.className = 'expression-continuous-legend-content';

  const gradientEl = document.createElement('div');
  gradientEl.className = 'expression-continuous-legend-gradient';

  // Build gradient from colorscale (reversed for expression - high on top)
  const gradientColors = colorscale
    .map((item) => item[1])
    .reverse()
    .join(', ');
  gradientEl.style.background = `linear-gradient(to bottom, ${gradientColors})`;

  const labelsEl = document.createElement('div');
  labelsEl.className = 'expression-continuous-legend-labels';

  const maxLabel = document.createElement('div');
  maxLabel.className = 'expression-continuous-legend-label';
  maxLabel.innerText = colorMax.toFixed(2);

  const minLabel = document.createElement('div');
  minLabel.className = 'expression-continuous-legend-label';
  minLabel.innerText = colorMin.toFixed(2);

  labelsEl.appendChild(maxLabel);
  labelsEl.appendChild(minLabel);

  contentEl.appendChild(gradientEl);
  contentEl.appendChild(labelsEl);
  legendContainer.appendChild(contentEl);
};

// Remove continuous legend
shinyjs.expressionRemoveContinuousLegend = function () {
  const legendContainer = document.getElementById('expression_projection_continuous_legend');
  if (legendContainer) {
    legendContainer.style.display = 'none';
  }
};

// Detach modebar for expression projection
shinyjs.expressionDetachModebar = function () {
  const plotContainer = document.getElementById('expression_projection');
  if (!plotContainer) return;

  const parent = plotContainer.parentElement;
  if (getComputedStyle(parent).position === 'static') {
    parent.style.position = 'relative';
  }

  // Find the modebar inside the plot container
  const modebar = plotContainer.querySelector('.modebar-container') || plotContainer.querySelector('.modebar');

  if (modebar) {
    // Remove stale detached modebars
    const staleModebars = parent.querySelectorAll('.expression-detached-modebar');
    staleModebars.forEach((el) => el.remove());

    parent.appendChild(modebar);
    modebar.classList.add('expression-detached-modebar');
  }
};

// =============================================================================
// Selection Event Handling
// =============================================================================

// Setup selection event listeners
shinyjs.expressionSetupSelectionListeners = function () {
  const plotContainer = document.getElementById('expression_projection');
  if (!plotContainer) {
    return;
  }

  // Monitor plotly_selected event
  plotContainer.on('plotly_selected', function (eventData) {
    // Check if Shiny is available
    if (typeof Shiny !== 'undefined') {
      // Event will be sent to Shiny automatically via plotly input binding
    }
  });

  // Monitor plotly_deselect event
  plotContainer.on('plotly_deselect', function () {
    // Selection cleared
  });
};

// Auto-setup selection listeners when document is ready
$(document).ready(function () {
  // Wait for plot to be initialized
  setTimeout(function () {
    shinyjs.expressionSetupSelectionListeners();
  }, 2000);

  // Also setup on any plot update
  const observer = new MutationObserver(function (mutations) {
    const plotContainer = document.getElementById('expression_projection');
    if (plotContainer && !plotContainer.dataset.selectionListenerAttached) {
      shinyjs.expressionSetupSelectionListeners();
      plotContainer.dataset.selectionListenerAttached = 'true';
    }
  });

  observer.observe(document.body, { childList: true, subtree: true });
});

// =============================================================================
// Plot Update Functions
// =============================================================================

// update 2D projection with single panel
shinyjs.expressionProjectionUpdatePlot2D = function (params) {
  params = shinyjs.getParams(params, expression_projection_default_params);

  // Remove any existing legend first
  shinyjs.expressionRemoveContinuousLegend();

  const colorArray = params.data.color;
  const colorMin = params.color.range[0];
  const colorMax = params.color.range[1];

  // Convert colorscale string to array if needed
  let colorscaleArray = params.color.scale;
  if (typeof colorscaleArray === 'string') {
    // Default colorscale if string provided
    colorscaleArray = [
      [0, '#E8F4F8'],
      [0.2, '#D1E8ED'],
      [0.4, '#A8D0DC'],
      [0.6, '#7FB8CB'],
      [0.8, '#5B9FB8'],
      [1, '#3D7A9E'],
    ];
  }

  const data = [];
  data.push({
    x: params.data.x,
    y: params.data.y,
    mode: 'markers',
    type: 'scattergl',
    marker: {
      size: params.data.point_size,
      opacity: params.data.point_opacity,
      line: params.data.point_line,
      color: params.data.color,
      colorscale: params.color.scale,
      reversescale: true,
      cauto: false,
      cmin: colorMin,
      cmax: colorMax,
      showscale: false,
    },
    hoverinfo: params.hover.hoverinfo,
    text: params.hover.text,
    showlegend: false,
  });

  // Create custom legend
  shinyjs.expressionCreateContinuousLegend('Expression', colorMin, colorMax, colorscaleArray);

  // deep clone layout to prevent global state pollution
  const layout_here = JSON.parse(JSON.stringify(expression_projection_layout_2D));

  // dynamic uirevision to allow axis resets while preserving zoom state otherwise
  layout_here.uirevision = params.data.reset_axes ? Date.now().toString() : 'true';

  if (params.data.reset_axes) {
    layout_here.xaxis['autorange'] = true;
    layout_here.yaxis['autorange'] = true;
  } else {
    layout_here.xaxis['autorange'] = false;
    layout_here.xaxis['range'] = params.data.x_range;
    layout_here.yaxis['autorange'] = false;
    layout_here.yaxis['range'] = params.data.y_range;
  }
  layout_here.shapes = params.trajectory;

  Plotly.react('expression_projection', data, layout_here).then(() => {
    shinyjs.expressionSetupSelectionListeners();
    shinyjs.expressionDetachModebar();
  });
};

// update 2D projection with multiple panels
shinyjs.expressionProjectionUpdatePlot2DMultiPanel = function (params) {
  params = shinyjs.getParams(params, expression_projection_default_params);

  // Remove legend for multi-panel (each panel could have different scale)
  shinyjs.expressionRemoveContinuousLegend();

  if (Array.isArray(params.data.color)) {
    return null;
  }
  // deep clone layout
  const layout_here = JSON.parse(JSON.stringify(expression_projection_layout_2D_multi_panel));

  // dynamic uirevision
  layout_here.uirevision = params.data.reset_axes ? Date.now().toString() : 'true';

  layout_here.shapes = params.trajectory;
  const number_of_genes = Object.keys(params.data.color).length;
  let n_rows = 1;
  let n_cols = 1;
  if (number_of_genes == 2) {
    n_rows = 1;
    n_cols = 2;
  } else if (number_of_genes <= 4) {
    n_rows = 2;
    n_cols = 2;
  } else if (number_of_genes <= 6) {
    n_rows = 2;
    n_cols = 3;
  } else if (number_of_genes <= 9) {
    n_rows = 3;
    n_cols = 3;
  }
  layout_here.grid = { rows: n_rows, columns: n_cols, pattern: 'independent' };
  layout_here.annotations = [];

  // Use map for cleaner array construction
  const data = Object.keys(params.data.color).map(function (gene, index) {
    const x_axis = index === 0 ? 'xaxis' : `xaxis${index + 1}`;
    const y_axis = index === 0 ? 'yaxis' : `yaxis${index + 1}`;
    const x_anchor = `x${index + 1}`;
    const y_anchor = `y${index + 1}`;

    // add X/Y axis attributes to layout
    layout_here[x_axis] = {
      title: gene,
      autorange: true,
      mirror: true,
      showline: true,
      zeroline: false,
      range: [],
      anchor: x_anchor,
      gridcolor: '#E2E8F0',
      linecolor: '#CBD5E0',
      tickfont: {
        color: '#718096',
        family: '-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif',
      },
    };
    layout_here[y_axis] = {
      autorange: true,
      mirror: true,
      showline: true,
      zeroline: false,
      range: [],
      anchor: y_anchor,
      gridcolor: '#E2E8F0',
      linecolor: '#CBD5E0',
      tickfont: {
        color: '#718096',
        family: '-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif',
      },
    };
    if (params.data.reset_axes) {
      layout_here[x_axis]['autorange'] = true;
      layout_here[y_axis]['autorange'] = true;
    } else {
      layout_here[x_axis]['autorange'] = false;
      layout_here[x_axis]['range'] = params.data.x_range;
      layout_here[y_axis]['autorange'] = false;
      layout_here[y_axis]['range'] = params.data.y_range;
    }

    const trace = {
      x: params.data.x,
      y: params.data.y,
      xaxis: x_anchor,
      yaxis: y_anchor,
      mode: 'markers',
      type: 'scattergl',
      marker: {
        size: params.data.point_size,
        opacity: params.data.point_opacity,
        line: params.data.point_line,
        color: params.data.color[gene],
        colorscale: params.color.scale,
        reversescale: true,
        cauto: false,
        cmin: params.color.range[0],
        cmax: params.color.range[1],
      },
      hoverinfo: params.hover.hoverinfo,
      text: params.hover.text,
      showlegend: false,
    };

    // add colorbar only to first trace
    if (index === 0) {
      trace.marker.colorbar = {
        title: {
          text: 'Expression',
          ticks: 'outside',
          outlinewidth: 1,
          outlinecolor: 'black',
        },
      };
    }

    return trace;
  });

  // update plot
  Plotly.react('expression_projection', data, layout_here).then(() => {
    shinyjs.expressionDetachModebar();
  });
};

// update 3D projection
shinyjs.expressionProjectionUpdatePlot3D = function (params) {
  params = shinyjs.getParams(params, expression_projection_default_params);

  // Remove legend for 3D (use built-in colorbar)
  shinyjs.expressionRemoveContinuousLegend();

  const data = [];
  data.push({
    x: params.data.x,
    y: params.data.y,
    z: params.data.z,
    mode: 'markers',
    type: 'scatter3d',
    marker: {
      size: params.data.point_size,
      opacity: params.data.point_opacity,
      line: params.data.point_line,
      color: params.data.color,
      colorscale: params.color.scale,
      reversescale: true,
      cauto: false,
      cmin: params.color.range[0],
      cmax: params.color.range[1],
      colorbar: {
        title: {
          text: 'Expression',
          ticks: 'outside',
          outlinewidth: 1,
          outlinecolor: 'black',
        },
      },
    },
    hoverinfo: params.hover.hoverinfo,
    text: params.hover.text,
    showlegend: false,
  });

  // deep clone layout
  const layout_here = JSON.parse(JSON.stringify(expression_projection_layout_3D));

  // dynamic uirevision (though 3D plots handle cameras differently, uirevision helps with state)
  layout_here.uirevision = params.data.reset_axes ? Date.now().toString() : 'true';

  Plotly.react('expression_projection', data, layout_here).then(() => {
    shinyjs.expressionDetachModebar();
  });
};

// =============================================================================
// Selection Clear Function
// =============================================================================

// Clear selection on the expression projection plot
shinyjs.expressionProjectionClearSelection = function () {
  const plotContainer = document.getElementById('expression_projection');
  if (plotContainer && plotContainer.data) {
    // Use Plotly.update to reset both data selection and layout in one call
    // Setting selectedpoints to null for all traces restores full opacity
    const numTraces = plotContainer.data.length;
    const restyleUpdate = {};
    for (let i = 0; i < numTraces; i++) {
      restyleUpdate.selectedpoints = restyleUpdate.selectedpoints || [];
      restyleUpdate.selectedpoints.push(null);
    }

    // Combine restyle and relayout in one update call
    Plotly.update(
      'expression_projection',
      { selectedpoints: null }, // Reset selected points for all traces
      { selections: [], dragmode: 'select' } // Clear selection box, keep select mode
    ).then(function () {
      // Emit deselect event after update completes
      plotContainer.emit('plotly_deselect');
    });
  }
};

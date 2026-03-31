// layout for 2D projections
const spatial_projection_layout_2D = {
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
  legend: {
    itemsizing: 'constant',
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
    titlefont: {
      color: '#2D3748',
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
    titlefont: {
      color: '#2D3748',
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
};

// Inject CSS for spatial projection
(function () {
  const style = document.createElement('style');
  style.innerHTML = `
    /* Custom Legend Styles */
    #spatial_projection_legend {
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
    }
    .custom-legend-item {
      display: flex;
      align-items: center;
      margin-bottom: 6px;
      cursor: pointer;
      user-select: none;
      padding: 4px 6px;
      border-radius: 4px;
      transition: background-color 0.2s ease;
    }
    .custom-legend-item:hover {
      background-color: rgba(91, 124, 153, 0.08);
    }
    .custom-legend-item:last-child {
      margin-bottom: 0;
    }
    .legend-color-box {
      width: 16px;
      height: 16px;
      margin-right: 10px;
      border-radius: 4px;
      flex-shrink: 0;
      box-shadow: 0 1px 2px rgba(0, 0, 0, 0.1);
    }
    .legend-text {
      font-size: 13px;
      color: #2D3748;
      font-weight: 500;
    }
    .legend-item-hidden .legend-text {
      text-decoration: line-through;
      color: #A0AEC0;
    }
    .legend-item-hidden .legend-color-box {
      opacity: 0.4;
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
    .custom-legend-item:hover .legend-drag-handle,
    #spatial_projection_legend:hover .legend-drag-handle,
    .continuous-legend:hover .legend-drag-handle {
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

    /* Continuous Legend Styles */
    .continuous-legend {
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
    .continuous-legend-title {
      font-size: 13px;
      color: #2D3748;
      font-weight: 500;
      margin-bottom: 8px;
      text-align: center;
    }
    .continuous-legend-gradient {
      width: 20px;
      height: 150px;
      margin: 0 auto;
      border-radius: 4px;
      box-shadow: 0 1px 2px rgba(0, 0, 0, 0.1);
    }
    .continuous-legend-labels {
      display: flex;
      flex-direction: column;
      justify-content: space-between;
      height: 150px;
      margin-left: 8px;
    }
    .continuous-legend-label {
      font-size: 11px;
      color: #718096;
      font-weight: 400;
    }
    .continuous-legend-content {
      display: flex;
      align-items: center;
    }
    .detached-modebar {
      position: absolute !important;
      top: 0px !important;
      right: 0px !important;
      z-index: 1001 !important;
    }
    .detached-modebar .modebar-btn {
      background: transparent;
      border: none;
      border-radius: 4px;
      box-shadow: none;
      transition: all 0.2s ease;
    }
    .detached-modebar .modebar-btn:hover {
      background: rgba(91, 124, 153, 0.1);
      border: none;
      transform: translateY(-1px);
      box-shadow: none;
    }
    .detached-modebar .modebar-btn svg {
      fill: #5B7C99;
    }
    .detached-modebar .modebar-btn:hover svg {
      fill: #3D5A73;
    }
    .detached-modebar .modebar-group {
      display: flex !important;
      flex-direction: row !important;
      align-items: center !important;
      gap: 4px !important;
    }
    .detached-modebar .modebar {
      display: flex !important;
      flex-direction: row !important;
      align-items: center !important;
      gap: 8px !important;
    }
    #spatial_projection_background {
      position: absolute;
      left: 0;
      top: 0;
      width: 100%;
      height: 100%;
      z-index: 0;
      background-repeat: no-repeat;
      background-position: center center;
      background-size: 100% 100%;
      pointer-events: none;
      transform-origin: center center;
    }
    #spatial_background_label {
      position: absolute;
      z-index: 0;
      pointer-events: none;
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif;
      font-size: 14px;
      font-weight: 500;
      color: rgba(45, 55, 72, 0.7);
      background: rgba(255, 255, 255, 0.6);
      padding: 4px 12px;
      border-radius: 4px;
      white-space: nowrap;
    }

    /* Scroll Down Arrow Indicator */
    .scroll-down-indicator {
      position: fixed;
      bottom: 80px;
      left: 50%;
      transform: translateX(-50%);
      z-index: 9999;
      display: flex;
      flex-direction: column;
      align-items: center;
      gap: 8px;
      cursor: pointer;
      transition: opacity 0.4s ease;
    }
    .scroll-down-indicator.hiding {
      opacity: 0;
      pointer-events: none;
    }
    .scroll-down-arrow {
      width: 50px;
      height: 50px;
      display: flex;
      align-items: center;
      justify-content: center;
      background: rgba(49, 130, 206, 0.15);
      border: 2px solid rgba(49, 130, 206, 0.4);
      border-radius: 50%;
      animation: scrollArrowBreathe 2s ease-in-out infinite;
    }
    .scroll-down-arrow svg {
      width: 28px;
      height: 28px;
      fill: none;
      stroke: #3182ce;
      stroke-width: 2.5;
      stroke-linecap: round;
      stroke-linejoin: round;
      animation: scrollArrowBounce 2s ease-in-out infinite;
    }
    .scroll-down-text {
      font-size: 13px;
      color: #3182ce;
      font-weight: 500;
      background: rgba(255, 255, 255, 0.9);
      padding: 4px 12px;
      border-radius: 12px;
      box-shadow: 0 2px 8px rgba(0, 0, 0, 0.1);
    }
    @keyframes scrollArrowBreathe {
      0%, 100% {
        transform: scale(1);
        background: rgba(49, 130, 206, 0.15);
        border-color: rgba(49, 130, 206, 0.4);
      }
      50% {
        transform: scale(1.1);
        background: rgba(49, 130, 206, 0.25);
        border-color: rgba(49, 130, 206, 0.6);
      }
    }
    @keyframes scrollArrowBounce {
      0%, 100% { transform: translateY(0); }
      50% { transform: translateY(5px); }
    }
  `;
  document.head.appendChild(style);
})();

// Scroll down indicator functions
shinyjs.showScrollDownIndicator = function (message) {
  // Remove existing indicator if any
  shinyjs.hideScrollDownIndicator();

  const indicator = document.createElement('div');
  indicator.id = 'scroll-down-indicator';
  indicator.className = 'scroll-down-indicator';
  indicator.innerHTML = `
    <div class="scroll-down-arrow">
      <svg viewBox="0 0 24 24">
        <polyline points="6 9 12 15 18 9"></polyline>
      </svg>
    </div>
    <div class="scroll-down-text">${message || 'Charts generated below'}</div>
  `;

  document.body.appendChild(indicator);

  // Click indicator to scroll down and hide
  indicator.onclick = function () {
    window.scrollBy({ top: 300, behavior: 'smooth' });
    shinyjs.hideScrollDownIndicator();
  };

  // Hide on scroll
  let scrollTimeout;
  const onScroll = function () {
    clearTimeout(scrollTimeout);
    scrollTimeout = setTimeout(function () {
      shinyjs.hideScrollDownIndicator();
      window.removeEventListener('scroll', onScroll);
    }, 100);
  };
  window.addEventListener('scroll', onScroll);

  // Hide on any click outside the indicator
  const onClickOutside = function (e) {
    if (!indicator.contains(e.target)) {
      shinyjs.hideScrollDownIndicator();
      document.removeEventListener('click', onClickOutside);
    }
  };
  // Delay adding click listener to avoid immediate trigger
  setTimeout(function () {
    document.addEventListener('click', onClickOutside);
  }, 100);

  // Store cleanup functions
  indicator.dataset.cleanup = 'true';
  indicator._onScroll = onScroll;
  indicator._onClickOutside = onClickOutside;
};

shinyjs.hideScrollDownIndicator = function () {
  const indicator = document.getElementById('scroll-down-indicator');
  if (indicator) {
    // Clean up event listeners
    if (indicator._onScroll) {
      window.removeEventListener('scroll', indicator._onScroll);
    }
    if (indicator._onClickOutside) {
      document.removeEventListener('click', indicator._onClickOutside);
    }
    // Fade out animation
    indicator.classList.add('hiding');
    setTimeout(function () {
      if (indicator.parentElement) {
        indicator.remove();
      }
    }, 400);
  }
};

shinyjs.detachModebar = function () {
  const plotContainer = document.getElementById('spatial_projection');
  if (!plotContainer) return;

  const parent = plotContainer.parentElement;
  if (getComputedStyle(parent).position === 'static') {
    parent.style.position = 'relative';
  }

  // Find the modebar inside the plot container
  const modebar = plotContainer.querySelector('.modebar-container') || plotContainer.querySelector('.modebar');

  if (modebar) {
    // Remove stale detached modebars
    const staleModebars = parent.querySelectorAll('.detached-modebar');
    staleModebars.forEach((el) => el.remove());

    parent.appendChild(modebar);
    modebar.classList.add('detached-modebar');
  }
};

shinyjs.applySpatialBackground = function () {
  const plotContainer = document.getElementById('spatial_projection');
  const bg = document.getElementById('spatial_projection_background');
  if (!plotContainer || !bg) return;

  const backgroundImage = bg.dataset.backgroundImage;
  const parent = bg.parentElement;

  // Get or create the label element
  let label = document.getElementById('spatial_background_label');

  if (backgroundImage) {
    bg.style.display = 'block';
    bg.style.backgroundImage = `url("${backgroundImage}")`;

    const flipX = bg.dataset.flipX === 'true';
    const flipY = bg.dataset.flipY === 'true';
    const scaleX = parseFloat(bg.dataset.scaleX) || 1;
    const scaleY = parseFloat(bg.dataset.scaleY) || 1;
    const opacity = parseFloat(bg.dataset.opacity);

    const finalScaleX = (flipX ? -1 : 1) * scaleX;
    const finalScaleY = (flipY ? -1 : 1) * scaleY;
    bg.style.transform = `scale(${finalScaleX}, ${finalScaleY})`;
    bg.style.opacity = isNaN(opacity) ? 1 : opacity;

    const size = plotContainer._fullLayout && plotContainer._fullLayout._size ? plotContainer._fullLayout._size : null;
    if (size) {
      bg.style.left = size.l + 'px';
      bg.style.top = size.t + 'px';
      bg.style.width = size.w + 'px';
      bg.style.height = size.h + 'px';

      // Create label if it doesn't exist
      if (!label) {
        label = document.createElement('div');
        label.id = 'spatial_background_label';
        label.innerText = 'Towards brain';
        parent.insertBefore(label, bg.nextSibling);
      }
      // Position label at top center of the background image area
      label.style.display = 'block';
      label.style.left = size.l + size.w / 2 + 'px';
      label.style.top = size.t + 8 + 'px';
      label.style.transform = 'translateX(-50%)';
    } else {
      bg.style.left = '0px';
      bg.style.top = '0px';
      bg.style.width = parent.clientWidth + 'px';
      bg.style.height = parent.clientHeight + 'px';

      // Create label if it doesn't exist
      if (!label) {
        label = document.createElement('div');
        label.id = 'spatial_background_label';
        label.innerText = 'Towards brain';
        parent.insertBefore(label, bg.nextSibling);
      }
      // Position label at top center
      label.style.display = 'block';
      label.style.left = '50%';
      label.style.top = '8px';
      label.style.transform = 'translateX(-50%)';
    }
  } else {
    bg.style.display = 'none';
    bg.style.backgroundImage = '';
    bg.style.transform = '';
    bg.style.opacity = '';

    // Hide label when no background image
    if (label) {
      label.style.display = 'none';
    }
  }
};

shinyjs.syncSpatialBackground = function (backgroundImage, flipX, flipY, scaleX, scaleY, opacity) {
  const plotContainer = document.getElementById('spatial_projection');
  if (!plotContainer) return;
  let parent = plotContainer.parentElement;
  let wrapper = parent && parent.id === 'spatial_projection_wrapper' ? parent : null;
  if (!wrapper) {
    wrapper = document.createElement('div');
    wrapper.id = 'spatial_projection_wrapper';
    wrapper.style.position = 'relative';
    wrapper.style.width = '100%';
    wrapper.style.height = '100%';
    wrapper.style.overflow = 'hidden';
    parent.insertBefore(wrapper, plotContainer);
    wrapper.appendChild(plotContainer);
  }
  parent = wrapper;
  let bg = document.getElementById('spatial_projection_background');
  if (!bg) {
    bg = document.createElement('div');
    bg.id = 'spatial_projection_background';
    bg.style.transition = 'transform 0.5s cubic-bezier(0.4, 0, 0.2, 1), opacity 0.3s ease';
    parent.insertBefore(bg, plotContainer);
  }

  if (backgroundImage !== undefined) bg.dataset.backgroundImage = backgroundImage || '';
  if (flipX !== undefined) bg.dataset.flipX = String(flipX);
  if (flipY !== undefined) bg.dataset.flipY = String(flipY);
  if (scaleX !== undefined) bg.dataset.scaleX = String(scaleX || 1);
  if (scaleY !== undefined) bg.dataset.scaleY = String(scaleY || 1);
  if (opacity !== undefined) bg.dataset.opacity = String(opacity === null ? 1 : opacity);

  shinyjs.applySpatialBackground();

  plotContainer.style.position = 'relative';
  plotContainer.style.zIndex = '1';

  if (!plotContainer.dataset.bgListenerAttached && typeof plotContainer.on === 'function') {
    plotContainer.on('plotly_afterplot', shinyjs.applySpatialBackground);
    plotContainer.dataset.bgListenerAttached = 'true';
  }
};

// Helper: Create drag handle element
function createLegendDragHandle() {
  const handle = document.createElement('div');
  handle.className = 'legend-drag-handle';
  // Create 3 rows of 2 dots each
  for (let i = 0; i < 3; i++) {
    const row = document.createElement('div');
    row.className = 'legend-drag-handle-dots';
    for (let j = 0; j < 2; j++) {
      const dot = document.createElement('div');
      dot.className = 'legend-drag-handle-dot';
      row.appendChild(dot);
    }
    handle.appendChild(row);
  }
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

// Custom Legend Helper Functions
shinyjs.makeDraggable = function (el) {
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

      // Record that user has dragged a legend (first time)
      if (!localStorage.getItem('cerebro_legend_dragged')) {
        localStorage.setItem('cerebro_legend_dragged', 'true');
        // Remove tip if it exists
        const tip = el.querySelector('.legend-drag-tip');
        if (tip) {
          tip.style.animation = 'legendTipFadeOut 0.2s ease forwards';
          setTimeout(() => tip.remove(), 200);
        }
      }
    }

    el.style.left = initialLeft + dx + 'px';
    el.style.top = initialTop + dy + 'px';
  }

  function onMouseUp(e) {
    isDragging = false;
    el.style.cursor = 'grab';
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

shinyjs.createCustomLegend = function (traces, colors) {
  const plotContainer = document.getElementById('spatial_projection');
  if (!plotContainer) return;

  // Ensure parent has relative positioning
  const parent = plotContainer.parentElement;
  if (getComputedStyle(parent).position === 'static') {
    parent.style.position = 'relative';
  }

  // Find or create legend container
  let legendContainer = document.getElementById('spatial_projection_legend');
  if (!legendContainer) {
    legendContainer = document.createElement('div');
    legendContainer.id = 'spatial_projection_legend';
    parent.appendChild(legendContainer);
  }

  // Enable dragging
  shinyjs.makeDraggable(legendContainer);

  // Reset content
  legendContainer.innerHTML = '';
  legendContainer.style.display = 'block';
  legendContainer.style.cursor = 'grab';

  // Add header with drag handle
  const header = createLegendHeader('Legend');
  legendContainer.appendChild(header);

  // Show first-time tip
  showLegendDragTip(legendContainer);

  // Calculate scaling based on number of traces
  const count = traces.length;
  let fontSize = 13;
  let itemMargin = 6;
  let itemPadding = 4; // top/bottom padding
  let itemPaddingX = 6; // left/right padding
  let boxSize = 16;

  if (count > 10) {
    if (count <= 20) {
      fontSize = 12;
      itemMargin = 4;
      itemPadding = 3;
      boxSize = 14;
    } else if (count <= 30) {
      fontSize = 11;
      itemMargin = 3;
      itemPadding = 2;
      boxSize = 12;
    } else if (count <= 50) {
      fontSize = 10;
      itemMargin = 2;
      itemPadding = 1;
      boxSize = 10;
    } else {
      fontSize = 9;
      itemMargin = 1;
      itemPadding = 0;
      boxSize = 8;
    }
  }

  // Create legend items
  traces.forEach((traceName, index) => {
    const item = document.createElement('div');
    item.className = 'custom-legend-item';

    // Apply dynamic styles
    item.style.marginBottom = itemMargin + 'px';
    item.style.padding = itemPadding + 'px ' + itemPaddingX + 'px';

    const colorBox = document.createElement('span');
    colorBox.className = 'legend-color-box';
    colorBox.style.backgroundColor = colors[index];
    // Apply dynamic box size
    colorBox.style.width = boxSize + 'px';
    colorBox.style.height = boxSize + 'px';

    const text = document.createElement('span');
    text.className = 'legend-text';
    text.innerText = traceName;
    // Apply dynamic font size
    text.style.fontSize = fontSize + 'px';

    item.appendChild(colorBox);
    item.appendChild(text);

    // Toggle visibility on click
    item.onclick = function () {
      if (legendContainer.dataset.isDragging === 'true') return;

      const plot = document.getElementById('spatial_projection');
      // Check current visibility status (default is visible/true)
      // We assume trace index corresponds to legend index
      let isVisible = true;
      if (plot.data && plot.data[index]) {
        isVisible = plot.data[index].visible !== false && plot.data[index].visible !== 'legendonly';
      }

      const newVisible = isVisible ? false : true;
      Plotly.restyle('spatial_projection', { visible: newVisible }, [index]);

      item.classList.toggle('legend-item-hidden', isVisible);
    };

    legendContainer.appendChild(item);
  });
};

shinyjs.removeCustomLegend = function () {
  const legendContainer = document.getElementById('spatial_projection_legend');
  if (legendContainer) {
    legendContainer.style.display = 'none';
  }
};

shinyjs.createContinuousLegend = function (title, colorMin, colorMax, colorscale) {
  const plotContainer = document.getElementById('spatial_projection');
  if (!plotContainer) return;

  const parent = plotContainer.parentElement;
  if (getComputedStyle(parent).position === 'static') {
    parent.style.position = 'relative';
  }

  let legendContainer = document.getElementById('spatial_projection_continuous_legend');
  if (!legendContainer) {
    legendContainer = document.createElement('div');
    legendContainer.id = 'spatial_projection_continuous_legend';
    parent.appendChild(legendContainer);
  }

  shinyjs.makeDraggable(legendContainer);
  legendContainer.innerHTML = '';
  legendContainer.style.display = 'block';
  legendContainer.className = 'continuous-legend';
  legendContainer.style.cursor = 'grab';

  // Add header with drag handle and title
  const header = createLegendHeader(title);
  legendContainer.appendChild(header);

  // Show first-time tip
  showLegendDragTip(legendContainer);

  const contentEl = document.createElement('div');
  contentEl.className = 'continuous-legend-content';

  const gradientEl = document.createElement('div');
  gradientEl.className = 'continuous-legend-gradient';

  const gradientColors = colorscale.map((item) => item[1]).join(', ');
  gradientEl.style.background = `linear-gradient(to top, ${gradientColors})`;

  const labelsEl = document.createElement('div');
  labelsEl.className = 'continuous-legend-labels';

  const minLabel = document.createElement('div');
  minLabel.className = 'continuous-legend-label';
  minLabel.innerText = colorMin.toFixed(2);

  const maxLabel = document.createElement('div');
  maxLabel.className = 'continuous-legend-label';
  maxLabel.innerText = colorMax.toFixed(2);

  labelsEl.appendChild(maxLabel);
  labelsEl.appendChild(minLabel);

  contentEl.appendChild(gradientEl);
  contentEl.appendChild(labelsEl);
  legendContainer.appendChild(contentEl);
};

shinyjs.removeContinuousLegend = function () {
  const legendContainer = document.getElementById('spatial_projection_continuous_legend');
  if (legendContainer) {
    legendContainer.style.display = 'none';
  }
};

// layout for 3D projections
const spatial_projection_layout_3D = {
  uirevision: 'true',
  hovermode: 'closest',
  margin: {
    l: 50,
    r: 50,
    b: 50,
    t: 50,
    pad: 4,
  },
  legend: {
    itemsizing: 'constant',
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
      titlefont: {
        color: '#2D3748',
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
      titlefont: {
        color: '#2D3748',
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
      titlefont: {
        color: '#2D3748',
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

// structure of input data
const spatial_projection_default_params = {
  meta: {
    color_type: '',
    traces: [],
    color_variable: '',
  },
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
  group_centers: {
    group: [],
    x: [],
    y: [],
    z: [],
  },
  container: {
    width: null,
    height: null,
  },
};

// update 2D projection with continuous coloring
shinyjs.updatePlot2DContinuousSpatial = function (params) {
  params = shinyjs.getParams(params, spatial_projection_default_params);

  shinyjs.removeCustomLegend();
  shinyjs.removeContinuousLegend();
  const data = [];
  const colorArray = params.data.color;
  const colorMin = Math.min(...colorArray);
  const colorMax = Math.max(...colorArray);
  const colorscale = [
    [0, '#E8F4F8'],
    [0.2, '#D1E8ED'],
    [0.4, '#A8D0DC'],
    [0.6, '#7FB8CB'],
    [0.8, '#5B9FB8'],
    [1, '#3D7A9E'],
  ];
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
      cmin: colorMin,
      cmax: colorMax,
      colorscale: colorscale,
      showscale: false,
    },
    hoverinfo: params.hover.hoverinfo,
  });
  shinyjs.createContinuousLegend(params.meta.color_variable, colorMin, colorMax, colorscale);

  // Use deep clone to avoid mutating global layout
  const layout_here = JSON.parse(JSON.stringify(spatial_projection_layout_2D));

  if (params.data.reset_axes) {
    layout_here.xaxis['autorange'] = true;
    layout_here.yaxis['autorange'] = true;
  } else {
    layout_here.xaxis['autorange'] = false;
    layout_here.xaxis['range'] = params.data.x_range;
    layout_here.yaxis['autorange'] = false;
    layout_here.yaxis['range'] = params.data.y_range;
  }
  if (params.container && params.container.width && params.container.height) {
    layout_here.width = params.container.width;
    layout_here.height = params.container.height;
  } else {
    const plotContainer = document.getElementById('spatial_projection');
    if (plotContainer && plotContainer.parentElement) {
      layout_here.width = plotContainer.parentElement.clientWidth;
      layout_here.height = plotContainer.parentElement.clientHeight;
    }
  }

  Plotly.react('spatial_projection', data, layout_here).then(() => {
    // Re-attach selection debug listeners
    if (typeof shinyjs.setupSelectionDebug === 'function') {
      shinyjs.setupSelectionDebug();
    }

    shinyjs.syncSpatialBackground(
      params.meta.background_image,
      params.meta.background_flip_x,
      params.meta.background_flip_y,
      params.meta.background_scale_x,
      params.meta.background_scale_y,
      params.meta.background_opacity
    );
    shinyjs.detachModebar();
  });
};

// update 3D projection with continuous coloring
shinyjs.updatePlot3DContinuousSpatial = function (params) {
  params = shinyjs.getParams(params, spatial_projection_default_params);
  shinyjs.removeCustomLegend();
  shinyjs.removeContinuousLegend();
  const data = [];
  const colorArray = params.data.color;
  const colorMin = Math.min(...colorArray);
  const colorMax = Math.max(...colorArray);
  const colorscale = [
    [0, '#E8F4F8'],
    [0.2, '#D1E8ED'],
    [0.4, '#A8D0DC'],
    [0.6, '#7FB8CB'],
    [0.8, '#5B9FB8'],
    [1, '#3D7A9E'],
  ];
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
      cmin: colorMin,
      cmax: colorMax,
      colorscale: colorscale,
      reversescale: true,
      showscale: false,
    },
    showlegend: false,
  });
  shinyjs.createContinuousLegend(params.meta.color_variable, colorMin, colorMax, colorscale);

  // Use deep clone
  const layout_here = JSON.parse(JSON.stringify(spatial_projection_layout_3D));

  if (params.container && params.container.width && params.container.height) {
    layout_here.width = params.container.width;
    layout_here.height = params.container.height;
  } else {
    const plotContainer = document.getElementById('spatial_projection');
    if (plotContainer && plotContainer.parentElement) {
      layout_here.width = plotContainer.parentElement.clientWidth;
      layout_here.height = plotContainer.parentElement.clientHeight;
    }
  }
  Plotly.react('spatial_projection', data, layout_here).then(() => {
    shinyjs.syncSpatialBackground(null, false, false, 1, 1, 1);
    shinyjs.detachModebar();
  });
};

shinyjs.getContainerDimensions = function () {
  const plotContainer = document.getElementById('spatial_projection');
  if (plotContainer) {
    const parentContainer = plotContainer.parentElement;
    return {
      width: parentContainer.clientWidth,
      height: parentContainer.clientHeight,
    };
  }
  return { width: 0, height: 0 };
};

// update 2D projection with categorical coloring
shinyjs.updatePlot2DCategoricalSpatial = function (params) {
  params = shinyjs.getParams(params, spatial_projection_default_params);

  shinyjs.removeContinuousLegend();
  shinyjs.createCustomLegend(params.meta.traces, params.data.color);

  // Optimization: Use map instead of loop push
  const data = params.data.x.map((xVal, i) => ({
    x: xVal,
    y: params.data.y[i],
    name: params.meta.traces[i],
    mode: 'markers',
    type: 'scattergl',
    marker: {
      size: params.data.point_size,
      opacity: params.data.point_opacity,
      line: params.data.point_line,
      color: params.data.color[i],
    },
    hoverinfo: params.hover.hoverinfo,
    text: params.hover.text[i],
    hoverlabel: {
      bgcolor: 'rgba(255, 255, 255, 0.95)',
      bordercolor: '#E2E8F0',
      font: {
        color: '#2D3748',
        size: 12,
        family: '-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif',
      },
    },
    showlegend: false,
  }));

  if (params.group_centers.group.length >= 1) {
    data.push({
      x: params.group_centers.x,
      y: params.group_centers.y,
      text: params.group_centers.group,
      type: 'scatter',
      mode: 'text',
      name: 'Labels',
      textposition: 'middle center',
      textfont: {
        color: '#000000',
        size: 16,
      },
      hoverinfo: 'skip',
      inherit: false,
      showlegend: false,
    });
  }

  // Use deep clone
  const layout_here = JSON.parse(JSON.stringify(spatial_projection_layout_2D));

  if (params.data.reset_axes) {
    layout_here.xaxis.autorange = true;
    delete layout_here.xaxis.range;
    layout_here.yaxis.autorange = true;
    delete layout_here.yaxis.range;
  } else {
    layout_here.xaxis.autorange = false;
    layout_here.xaxis.range = [...params.data.x_range];
    layout_here.yaxis.autorange = false;
    layout_here.yaxis.range = [...params.data.y_range];
  }
  if (params.container && params.container.width && params.container.height) {
    layout_here.width = params.container.width;
    layout_here.height = params.container.height;
  } else {
    const plotContainer = document.getElementById('spatial_projection');
    if (plotContainer && plotContainer.parentElement) {
      layout_here.width = plotContainer.parentElement.clientWidth;
      layout_here.height = plotContainer.parentElement.clientHeight;
    }
  }

  Plotly.react('spatial_projection', data, layout_here).then(() => {
    // Re-attach selection debug listeners
    if (typeof shinyjs.setupSelectionDebug === 'function') {
      shinyjs.setupSelectionDebug();
    }

    shinyjs.syncSpatialBackground(
      params.meta.background_image,
      params.meta.background_flip_x,
      params.meta.background_flip_y,
      params.meta.background_scale_x,
      params.meta.background_scale_y,
      params.meta.background_opacity
    );
    shinyjs.detachModebar();
  });
};

// update 3D projection with categorical coloring
shinyjs.updatePlot3DCategoricalSpatial = function (params) {
  params = shinyjs.getParams(params, spatial_projection_default_params);
  shinyjs.removeContinuousLegend();
  shinyjs.createCustomLegend(params.meta.traces, params.data.color);

  // Optimization: Use map
  const data = params.data.x.map((xVal, i) => ({
    x: xVal,
    y: params.data.y[i],
    z: params.data.z[i],
    name: params.meta.traces[i],
    mode: 'markers',
    type: 'scatter3d',
    marker: {
      size: params.data.point_size,
      opacity: params.data.point_opacity,
      line: params.data.point_line,
      color: params.data.color[i],
    },
    hoverinfo: params.hover.hoverinfo,
    text: params.hover.text[i],
    hoverlabel: {
      bgcolor: 'rgba(255, 255, 255, 0.95)',
      bordercolor: '#E2E8F0',
      font: {
        color: '#2D3748',
        size: 12,
        family: '-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif',
      },
    },
    showlegend: false,
  }));

  if (params.group_centers.group.length >= 1) {
    data.push({
      x: params.group_centers.x,
      y: params.group_centers.y,
      z: params.group_centers.z,
      text: params.group_centers.group,
      type: 'scatter3d',
      mode: 'text',
      name: 'Labels',
      textposition: 'middle center',
      textfont: {
        color: '#000000',
        size: 16,
      },
      hoverinfo: 'skip',
      inherit: false,
      showlegend: false,
    });
  }

  // Use deep clone
  const layout_here = JSON.parse(JSON.stringify(spatial_projection_layout_3D));

  if (params.container && params.container.width && params.container.height) {
    layout_here.width = params.container.width;
    layout_here.height = params.container.height;
  } else {
    const plotContainer = document.getElementById('spatial_projection');
    if (plotContainer && plotContainer.parentElement) {
      layout_here.width = plotContainer.parentElement.clientWidth;
      layout_here.height = plotContainer.parentElement.clientHeight;
    }
  }
  Plotly.react('spatial_projection', data, layout_here).then(() => {
    shinyjs.syncSpatialBackground(null, false, false, 1, 1, 1);
    shinyjs.detachModebar();
  });
};

// =============================================================================
// DEBUG: Selection Event Monitoring
// =============================================================================

// Debug helper to monitor plotly selection events
shinyjs.setupSelectionDebug = function () {
  const plotContainer = document.getElementById('spatial_projection');
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

// Debug function to check plot configuration
shinyjs.debugPlotConfig = function () {
  const plotContainer = document.getElementById('spatial_projection');
  if (!plotContainer) {
    return;
  }
  // Debug info suppressed for production
};

// Auto-setup debug when document is ready
$(document).ready(function () {
  // Wait for plot to be initialized
  setTimeout(function () {
    shinyjs.setupSelectionDebug();
  }, 2000);

  // Also setup on any plot update
  const observer = new MutationObserver(function (mutations) {
    const plotContainer = document.getElementById('spatial_projection');
    if (plotContainer && !plotContainer.dataset.debugListenerAttached) {
      shinyjs.setupSelectionDebug();
      plotContainer.dataset.debugListenerAttached = 'true';
    }
  });

  observer.observe(document.body, { childList: true, subtree: true });
});

// Clear selection on the spatial projection plot
shinyjs.spatialClearSelection = function () {
  const plotContainer = document.getElementById('spatial_projection');
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
      'spatial_projection',
      { selectedpoints: null }, // Reset selected points for all traces
      { selections: [], dragmode: 'select' } // Clear selection box, keep select mode
    ).then(function () {
      // Emit deselect event after update completes
      plotContainer.emit('plotly_deselect');
    });
  }
};

// Spatial background-overlay layer.
//
// Split out of js_projection_update_plot.js so the histology background
// (placement, clipping, move/scale/flip/rotate, and the async appearance
// channel) lives on its own, separate from the scatter rendering and legend
// code. UI.R concatenates this file together with js_projection_update_plot.js
// into a SINGLE extendShinyjs() text, so these functions share the same global
// scope as before — the split is organisational only, not a runtime boundary.
//
// Public (called from R via js$...): updateSpatialBackgroundAppearance.
// The others (spatialBgRectFromBounds, applySpatialBackground,
// syncSpatialBackground) are called from the plot functions in the sibling
// file, which is why both files must be loaded together.

// Map the background image's data-space extent (image_bounds) onto the plot in
// PIXELS, so the image sits in the cells' fixed coordinate system instead of the
// axes bending to fit the image. Returns a rect relative to the wrapper, or null
// when bounds/axes are unavailable (caller then falls back to filling the area).
//
// This is the core of the decoupling: the scatter plot's axes are owned by the
// cell coordinates alone; the image is a passenger placed via l2p (data→pixel).
// An image larger than the spot bbox simply overflows the plot area and is
// clipped by the wrapper's overflow:hidden — the points never move.
function spatialBgRectFromBounds(plotContainer) {
  const fl = plotContainer._fullLayout;
  if (!fl || !fl._size || !fl.xaxis || !fl.yaxis) return null;
  if (typeof fl.xaxis.l2p !== 'function' || typeof fl.yaxis.l2p !== 'function') {
    return null;
  }
  const bg = document.getElementById('spatial_projection_background');
  const xmin = parseFloat(bg.dataset.boundsXmin);
  const xmax = parseFloat(bg.dataset.boundsXmax);
  const ymin = parseFloat(bg.dataset.boundsYmin);
  const ymax = parseFloat(bg.dataset.boundsYmax);
  if (![xmin, xmax, ymin, ymax].every(isFinite) || xmax <= xmin || ymax <= ymin) {
    return null;
  }
  const s = fl._size;
  // l2p returns pixels relative to the plot-area origin (s.l, s.t).
  const px = (v) => s.l + fl.xaxis.l2p(v);
  const py = (v) => s.t + fl.yaxis.l2p(v);
  const left = px(xmin);
  const right = px(xmax);
  // y axis points up, so ymax is the top edge of the image in screen space.
  const top = py(ymax);
  const bottom = py(ymin);
  return { left, top, width: right - left, height: bottom - top };
}

shinyjs.applySpatialBackground = function () {
  const plotContainer = document.getElementById('spatial_projection');
  const bg = document.getElementById('spatial_projection_background');
  if (!plotContainer || !bg) return;

  const backgroundImage = bg.dataset.backgroundImage;
  // The label must live in the WRAPPER, not in the clip layer (which is
  // overflow:hidden and would cut it off). bg.parentElement becomes the clip
  // layer after the first placement, so resolve the wrapper explicitly.
  const parent =
    document.getElementById('spatial_projection_wrapper') || bg.parentElement;

  // Get or create the label element
  let label = document.getElementById('spatial_background_label');

  if (backgroundImage) {
    bg.style.display = 'block';
    bg.style.position = 'absolute';
    bg.style.pointerEvents = 'none';
    bg.style.zIndex = '0';

    const flipX = bg.dataset.flipX === 'true';
    const flipY = bg.dataset.flipY === 'true';
    // Scale is a SINGLE source of truth: the Scale slider(s), which the UI seeds
    // from the build-config `spatial_images_scale_x/y` preset. There is no longer
    // a separate dataset.scaleX factor multiplied on top (that produced a squared
    // scale, e.g. 1.55 × 1.55). scaleX/scaleY are independent when the user
    // unlocks the aspect ratio; locked, the X slider drives both.
    const scaleX = parseFloat(bg.dataset.scaleX);
    const scaleY = parseFloat(bg.dataset.scaleY);
    const userScaleX = Number.isFinite(scaleX) ? scaleX : 1;
    const userScaleY = Number.isFinite(scaleY) ? scaleY : 1;
    const rotate = parseFloat(bg.dataset.rotate) || 0;
    const offsetX = parseFloat(bg.dataset.offsetX) || 0; // in data (x) units
    const offsetY = parseFloat(bg.dataset.offsetY) || 0; // in data (y) units
    const opacity = parseFloat(bg.dataset.opacity);
    const imgW = parseInt(bg.dataset.imgWidth) || 0;
    const imgH = parseInt(bg.dataset.imgHeight) || 0;

    // flip is a mirror on top of the placement; scale is applied as-is.
    const finalScaleX = (flipX ? -1 : 1) * userScaleX;
    const finalScaleY = (flipY ? -1 : 1) * userScaleY;

    const size =
      plotContainer._fullLayout && plotContainer._fullLayout._size
        ? plotContainer._fullLayout._size
        : null;
    // Primary path: place the image by mapping its data-space bounds to pixels,
    // so it aligns to the cells in their own (unchanged) coordinate system.
    const rect = size ? spatialBgRectFromBounds(plotContainer) : null;

    if (rect) {
      // Clip layer: a box sized to exactly the plot DRAWING AREA (inside the
      // axes), with overflow:hidden. The background div lives inside it, so any
      // part of the image that falls outside the axes — however it was moved,
      // scaled or flipped — is simply hidden, and the axis ticks/frame stay
      // visible. This layer carries no transform of its own, so the image's CSS
      // transform can't drag the clip box around.
      const size2 = plotContainer._fullLayout._size;
      let clip = document.getElementById('spatial_projection_clip');
      if (!clip) {
        clip = document.createElement('div');
        clip.id = 'spatial_projection_clip';
        clip.style.position = 'absolute';
        clip.style.overflow = 'hidden';
        clip.style.pointerEvents = 'none';
        clip.style.zIndex = '0';
        bg.parentElement.insertBefore(clip, bg);
      }
      if (bg.parentElement !== clip) clip.appendChild(bg);
      clip.style.left = size2.l + 'px';
      clip.style.top = size2.t + 'px';
      clip.style.width = size2.w + 'px';
      clip.style.height = size2.h + 'px';

      // Position the div at the mapped rect, now expressed RELATIVE to the clip
      // layer (subtract the clip's own origin). The interactive move/flip/scale/
      // rotate are then applied as ONE CSS transform about the rect centre, so
      // they shift/mirror/spin the image in place without moving the points.
      bg.style.left = rect.left - size2.l + 'px';
      bg.style.top = rect.top - size2.t + 'px';
      bg.style.width = rect.width + 'px';
      bg.style.height = rect.height + 'px';
      bg.style.transformOrigin = '50% 50%';
      // Move is specified in DATA units so it stays locked to the cells across
      // zoom/resize: convert Δdata → Δpixel through the same axis mapping.
      const fl = plotContainer._fullLayout;
      // Round to whole pixels so sub-pixel l2p jitter between renders does not
      // count as a change below.
      const dxPix = Math.round(fl.xaxis.l2p(offsetX) - fl.xaxis.l2p(0));
      const dyPix = Math.round(fl.yaxis.l2p(offsetY) - fl.yaxis.l2p(0));
      // Order (applied right→left): flip+scale, then rotate, then translate.
      const parts = [];
      if (dxPix !== 0 || dyPix !== 0) {
        parts.push(`translate(${dxPix}px, ${dyPix}px)`);
      }
      if (rotate !== 0) parts.push(`rotate(${rotate}deg)`);
      if (finalScaleX !== 1 || finalScaleY !== 1) {
        parts.push(`scale(${finalScaleX}, ${finalScaleY})`);
      }
      const nextTransform = parts.join(' ');
      // The 0.5s CSS transition on `transform` is meant to smooth a genuine user
      // adjustment. But applySpatialBackground also runs on every plotly
      // afterplot and on unrelated appearance changes, each time re-assigning the
      // SAME transform — which replays the transition and makes the (possibly
      // large, preset-offset) image visibly slide. Only write when the value
      // actually changes so the animation fires on real edits alone.
      if (bg.dataset.lastTransform !== nextTransform) {
        // First placement of this image (no prior transform): apply it WITHOUT
        // the transition so the preset offset/scale lands instantly instead of
        // animating in from the origin. Subsequent user edits keep the smooth
        // 0.5s transition.
        const firstPlacement = bg.dataset.lastTransform === undefined;
        if (firstPlacement) {
          const savedTransition = bg.style.transition;
          bg.style.transition = 'none';
          bg.style.transform = nextTransform;
          // Force a reflow so the no-transition assignment is committed before
          // the transition is restored, otherwise the browser may still tween.
          void bg.offsetWidth;
          bg.style.transition = savedTransition;
        } else {
          bg.style.transform = nextTransform;
        }
        bg.dataset.lastTransform = nextTransform;
      }
      if (imgW > 0 && imgH > 0) {
        // native-resolution <img>, stretched to the mapped rect
        if (!bg._imgEl) {
          const img = document.createElement('img');
          img.style.width = '100%';
          img.style.height = '100%';
          img.style.display = 'block';
          img.draggable = false;
          bg.appendChild(img);
          bg._imgEl = img;
        }
        bg._imgEl.src = backgroundImage;
        bg.style.backgroundImage = '';
      } else {
        // SVG / dimensionless raster → CSS background stretched to the rect
        if (bg._imgEl) bg._imgEl.src = '';
        bg.style.backgroundImage = `url("${backgroundImage}")`;
        bg.style.backgroundSize = '100% 100%';
        bg.style.backgroundRepeat = 'no-repeat';
      }
      bg.style.opacity = isNaN(opacity) ? 1 : opacity;

      if (!label) {
        label = document.createElement('div');
        label.id = 'spatial_background_label';
        label.innerText = 'Towards brain';
        parent.appendChild(label);
      }
      // Label sits at the top-centre of the plot drawing area (not the image),
      // so it stays put regardless of how far the image overflows.
      label.style.display = 'block';
      label.style.left = size.l + size.w / 2 + 'px';
      label.style.top = size.t + 8 + 'px';
      label.style.transform = 'translateX(-50%)';
    } else {
      // Fallback: no bounds or no Plotly geometry yet — fill the wrapper so the
      // image is at least visible; it will snap to the mapped rect on the next
      // afterplot once geometry is available.
      const parentW = parent.clientWidth;
      const parentH = parent.clientHeight;
      if (bg._imgEl) bg._imgEl.src = '';
      bg.style.backgroundImage = `url("${backgroundImage}")`;
      bg.style.backgroundSize = '100% 100%';
      bg.style.backgroundRepeat = 'no-repeat';
      bg.style.left = '0px';
      bg.style.top = '0px';
      bg.style.width = parentW + 'px';
      bg.style.height = parentH + 'px';
      bg.style.transformOrigin = '50% 50%';
      const fallbackTransform = `scale(${finalScaleX}, ${finalScaleY})`;
      if (bg.dataset.lastTransform !== fallbackTransform) {
        bg.style.transform = fallbackTransform;
        bg.dataset.lastTransform = fallbackTransform;
      }
      bg.style.opacity = isNaN(opacity) ? 1 : opacity;

      if (!label) {
        label = document.createElement('div');
        label.id = 'spatial_background_label';
        label.innerText = 'Towards brain';
        parent.appendChild(label);
      }
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
    if (bg._imgEl) bg._imgEl.src = '';

    // Hide label when no background image
    if (label) {
      label.style.display = 'none';
    }
  }
};

shinyjs.syncSpatialBackground = function (backgroundImage, flipX, flipY, scaleX, scaleY, opacity, imageBounds, offsetX, offsetY) {
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

  // Every syncSpatialBackground call is one full render pass, so the image
  // argument is authoritative: a real data: URI sets the background, while
  // undefined / null / '' all mean "no background for this dataset" and MUST
  // clear it. (R's NULL arrives here as undefined; treating undefined as "leave
  // it alone" left a previous dataset's tissue image showing behind a bead-only
  // platform like Slide-seq.) Normalise all of them to '' before comparing.
  {
    const normalizedImage = backgroundImage || '';
    // When the image itself CHANGES (dataset switch, picking a different
    // background, or clearing it), the user-interaction state belongs to the OLD
    // image and must not carry over. Clear the interaction-owned fields so the
    // block below re-seeds flip/opacity from the NEW image's dataset defaults,
    // and reset the interactive nudges (offset/scale/rotate) that were relative
    // to the old image. Same image (a plain scatter re-render) → leave intact.
    const imageChanged = bg.dataset.backgroundImage !== normalizedImage;
    if (imageChanged) {
      delete bg.dataset.lastTransform;
      delete bg.dataset.flipX;
      delete bg.dataset.flipY;
      delete bg.dataset.opacity;
      delete bg.dataset.scaleX;
      delete bg.dataset.scaleY;
      delete bg.dataset.rotate;
      delete bg.dataset.offsetX;
      delete bg.dataset.offsetY;
    }
    bg.dataset.backgroundImage = normalizedImage;
  }
  // scaleX/scaleY seed the Scale slider(s) from the build-config preset, the
  // same SEED-ONLY way as flip/opacity below: set once when the image first
  // appears, then owned by the user (the appearance channel writes them). A
  // plain scatter re-render must not clobber a scale the user has adjusted.
  if (scaleX !== undefined && bg.dataset.scaleX === undefined) {
    bg.dataset.scaleX = String(scaleX || 1);
  }
  if (scaleY !== undefined && bg.dataset.scaleY === undefined) {
    bg.dataset.scaleY = String(scaleY || 1);
  }
  // offsetX/offsetY (the move preset) are seeded the SAME SEED-ONLY way. This is
  // what fixes the first-show jump: previously the offset reached the div only
  // via the async appearance channel, which could fire before this div existed
  // and get dropped, so the image opened un-shifted until the user nudged it.
  // Seeding here means the preset offset is present on the very first paint.
  if (offsetX !== undefined && bg.dataset.offsetX === undefined) {
    bg.dataset.offsetX = String(offsetX || 0);
  }
  if (offsetY !== undefined && bg.dataset.offsetY === undefined) {
    bg.dataset.offsetY = String(offsetY || 0);
  }
  // flipX/flipY/opacity are USER-interaction state, owned by the independent
  // appearance channel (updateSpatialBackgroundAppearance). The render pass must
  // NOT clobber them, or a scatter-plot re-render (colour/point-size/% change)
  // would reset the user's flip/opacity back to the dataset defaults. So only
  // SEED them here — the first time an image is shown, before the user has
  // touched anything — and leave them alone on every subsequent render.
  if (flipX !== undefined && bg.dataset.flipX === undefined) {
    bg.dataset.flipX = String(flipX);
  }
  if (flipY !== undefined && bg.dataset.flipY === undefined) {
    bg.dataset.flipY = String(flipY);
  }
  if (opacity !== undefined && bg.dataset.opacity === undefined) {
    bg.dataset.opacity = String(opacity === null ? 1 : opacity);
  }
  if (imageBounds !== undefined && imageBounds) {
    bg.dataset.imgWidth = String(imageBounds.img_width || 0);
    bg.dataset.imgHeight = String(imageBounds.img_height || 0);
    // Data-space extent of the image, used to place it in the cells' coordinate
    // system (see spatialBgRectFromBounds). Absent/empty → cleared so the rect
    // helper returns null and the fill-the-area fallback runs.
    if (
      imageBounds.xmin !== undefined &&
      imageBounds.xmax !== undefined &&
      imageBounds.ymin !== undefined &&
      imageBounds.ymax !== undefined
    ) {
      bg.dataset.boundsXmin = String(imageBounds.xmin);
      bg.dataset.boundsXmax = String(imageBounds.xmax);
      bg.dataset.boundsYmin = String(imageBounds.ymin);
      bg.dataset.boundsYmax = String(imageBounds.ymax);
    } else {
      delete bg.dataset.boundsXmin;
      delete bg.dataset.boundsXmax;
      delete bg.dataset.boundsYmin;
      delete bg.dataset.boundsYmax;
    }
  }

  shinyjs.applySpatialBackground();
  // Picking/seeding a background only re-styles the div; it does NOT trigger a
  // Plotly redraw, so plotly_afterplot won't fire and the axis mapping (l2p) may
  // not be settled yet on this first pass — the move offset would resolve to 0
  // and the image would sit un-shifted until the next user action nudged it into
  // place (a visible jump). Re-apply on the next animation frame, by when the
  // geometry is ready, so the offset lands correctly on first show.
  if (typeof requestAnimationFrame === 'function') {
    requestAnimationFrame(function () {
      shinyjs.applySpatialBackground();
    });
  }

  plotContainer.style.position = 'relative';
  plotContainer.style.zIndex = '1';

  if (!plotContainer.dataset.bgListenerAttached && typeof plotContainer.on === 'function') {
    plotContainer.on('plotly_afterplot', shinyjs.applySpatialBackground);
    plotContainer.dataset.bgListenerAttached = 'true';
  }
};

// Independent background-appearance channel. The Additional-parameters controls
// (opacity, move, flip, scale, rotate) call THIS — not the plot updater — so
// adjusting the background only re-styles the background <div> and never
// re-renders the scatter plot. This is the decoupling: the dimensional-reduction
// plot is a function of its own parameters alone; the image is a passenger.
//
// shinyjs passes ALL R arguments packed into a single `params` object (see
// shinyjs.getParams); it does NOT spread them into positional formals. So this
// takes one object and unpacks it — the R side calls with named arguments
// (opacity=, offsetX=, ...). null/undefined fields are left unchanged, so R can
// push a single field or all of them.
shinyjs.updateSpatialBackgroundAppearance = function (params) {
  params = shinyjs.getParams(params, {
    opacity: null,
    offsetX: null,
    offsetY: null,
    flipX: undefined,
    flipY: undefined,
    scaleX: null,
    scaleY: null,
    rotate: null,
  });
  const bg = document.getElementById('spatial_projection_background');
  // No background div yet (no image chosen) → nothing to style. When an image is
  // later selected, syncSpatialBackground seeds the div and applies current data.
  if (!bg) return;
  if (params.opacity !== undefined && params.opacity !== null) {
    bg.dataset.opacity = String(params.opacity);
  }
  if (params.offsetX !== undefined && params.offsetX !== null) {
    bg.dataset.offsetX = String(params.offsetX);
  }
  if (params.offsetY !== undefined && params.offsetY !== null) {
    bg.dataset.offsetY = String(params.offsetY);
  }
  if (params.flipX !== undefined) bg.dataset.flipX = String(params.flipX);
  if (params.flipY !== undefined) bg.dataset.flipY = String(params.flipY);
  if (params.scaleX !== undefined && params.scaleX !== null) {
    bg.dataset.scaleX = String(params.scaleX || 1);
  }
  if (params.scaleY !== undefined && params.scaleY !== null) {
    bg.dataset.scaleY = String(params.scaleY || 1);
  }
  if (params.rotate !== undefined && params.rotate !== null) {
    bg.dataset.rotate = String(params.rotate);
  }
  // Re-style the div only. Plotly is never touched here.
  shinyjs.applySpatialBackground();
};

/* ==========================================================================
   Fill-to-viewport height, measured live.

   The systematic answer to "the plot is sometimes too short, sometimes taller
   than the screen." Every viz page has the same shape — sidebar | params | plot
   — but each output used to hardcode its own height: a fixed `640px` (ignores
   the viewport entirely) or `calc(100vh - <N>px)` where N is a hand-measured
   guess at the chrome above the plot. Both break the moment a margin, a title,
   a tab strip or a legend changes: the guess is now wrong and the plot either
   overflows or leaves a dead band.

   The robust height is not a constant. It is:

       height = viewport - (top of this element) - (bottom breathing room)

   `top of this element` is the live sum of everything above it (top bar, box
   title, tab strip, a wrapping legend), read from the DOM with
   getBoundingClientRect(). Nothing is hardcoded, so changing any spacing above
   the plot re-measures on the next frame and the height corrects itself. This
   is the same primitive projection_scatter.js already uses for the scatter
   plots (projectionTargetHeight); this file generalises it to any element that
   opts in with the `cerebro-fill` class.

   Opt in from R:

       div(class = "cerebro-fill", <the output at height = "100%">)

   custom.css makes `.cerebro-fill` a flex column whose child fills it, so the
   output (and any spinner wrapper between) inherits the measured height without
   needing its own resolved-height chain.
   ========================================================================== */
(function () {
  "use strict";

  var FILL_CLASS = "cerebro-fill";
  /* A small safety margin only. The real bottom breathing room comes for free
     from the box model that spaceBelow() already accounts for — the card's
     margin-bottom and the content-wrapper's padding-bottom sit below the plot
     and are measured, so the plot already stops well clear of the viewport edge.
     This is just a couple of pixels of slack so sub-pixel rounding can never tip
     the page into a scrollbar. */
  var BOTTOM_GAP = 4;
  /* Never collapse below this, however cramped the viewport: a plot shorter than
     this is useless, better to let the page scroll. */
  var MIN_HEIGHT = 240;

  /* height = viewport - element.top - contentBelow - gap, floored, clamped.
     Pure: measurements in, pixels out. `contentBelow` is everything that must
     stay visible under this element (a details panel, a note, a download row)
     plus the card's own bottom padding, so the WHOLE card fits the viewport
     rather than the plot filling it and shoving the rest off-screen. */
  function targetHeight(viewportHeight, elementTop, contentBelow, gap, minimum) {
    return Math.max(
      minimum,
      Math.floor(viewportHeight - elementTop - contentBelow - gap)
    );
  }

  function px(value) {
    var n = parseFloat(value);
    return isFinite(n) ? n : 0;
  }

  /* Everything that must stay below this element for the page to fit: its
     following siblings at every level up to the content root, plus each
     ancestor's bottom margin / padding / border along the way (a card's
     margin-bottom, the content-wrapper's padding-bottom, ...). Measured live and
     bottom-up, so it is immune to any spacing change above OR around the plot —
     the whole point. Deliberately does NOT read any ancestor's bottom
     COORDINATE: the content-wrapper is min-height:100vh, so its bottom is a lie
     (always ≥ viewport). Only concrete box-model values are summed. Stable under
     the element's own height because none of these terms depend on it. */
  function spaceBelow(el) {
    var root = (el.closest && el.closest(".content-wrapper")) || document.body;
    var total = 0;
    var node = el;
    while (node && node !== root && node.parentElement) {
      var sib = node.nextElementSibling;
      while (sib) {
        var scs = window.getComputedStyle(sib);
        if (scs.display !== "none") {
          total += sib.getBoundingClientRect().height +
            px(scs.marginTop) + px(scs.marginBottom);
        }
        sib = sib.nextElementSibling;
      }
      var pcs = window.getComputedStyle(node.parentElement);
      total += px(window.getComputedStyle(node).marginBottom) +
        px(pcs.paddingBottom) + px(pcs.borderBottomWidth);
      node = node.parentElement;
    }
    return Math.max(0, total);
  }

  function sizeOne(el) {
    if (!el || typeof window.innerHeight !== "number") {
      return;
    }
    var top = el.getBoundingClientRect().top;
    /* A hidden element (its tab is not active) reports top 0 / height 0. Sizing
       it then would bake in a wrong height that outlives the tab switch, so skip
       it until it is laid out; the observers below re-fire when it appears. */
    if (el.offsetParent === null && top === 0) {
      return;
    }
    var h = targetHeight(
      window.innerHeight,
      top,
      spaceBelow(el),
      BOTTOM_GAP,
      MIN_HEIGHT
    );
    /* Idempotent: only write when the value actually changed. This is what keeps
       the ResizeObserver below from looping — resizing this element changes the
       page height, which fires the observer, which recomputes the SAME height
       (our own top did not move), so the guard stops here instead of ping-pong. */
    if (el.__cerebroFillH !== h) {
      el.__cerebroFillH = h;
      el.style.height = h + "px";
    }
    /* Reveal only once a real height has been applied. Until then the element is
       transparent (custom.css) over a viewport-proportional placeholder, so the
       first paint reserves the right space but never shows the plot at the
       pre-measurement height — that intermediate size is what read as a "flash".
       Fades in via a CSS transition, the one place the app animates a resize. */
    if (!el.classList.contains("is-filled")) {
      el.classList.add("is-filled");
    }
  }

  function sizeAll() {
    var els = document.getElementsByClassName(FILL_CLASS);
    for (var i = 0; i < els.length; i++) {
      sizeOne(els[i]);
    }
  }

  /* Coalesce bursts of triggers into one measurement per frame. */
  var pending = false;
  function scheduleSize() {
    if (pending) {
      return;
    }
    pending = true;
    window.requestAnimationFrame(function () {
      pending = false;
      sizeAll();
    });
  }

  window.addEventListener("resize", scheduleSize);

  /* Chrome above the plot can change height WITHOUT a window resize — a legend
     wraps to another row, a caveat banner appears, the tab strip changes. A
     ResizeObserver on <body> catches every such reflow; the idempotent guard in
     sizeOne() makes observing the whole document loop-safe. */
  if (typeof window.ResizeObserver === "function") {
    var ro = new window.ResizeObserver(scheduleSize);
    if (document.body) {
      ro.observe(document.body);
    } else {
      document.addEventListener("DOMContentLoaded", function () {
        ro.observe(document.body);
      });
    }
  }

  /* Shiny re-renders outputs and swaps tab panes after the initial paint, so a
     fill element can arrive (or become visible) well after load. Re-measure when
     Shiny reports a value and when a Bootstrap tab is shown. */
  document.addEventListener("shiny:value", scheduleSize);
  document.addEventListener("shiny:connected", scheduleSize);
  if (window.jQuery) {
    window.jQuery(document).on(
      "shown.bs.tab shiny:visualchange",
      scheduleSize
    );
  }

  document.addEventListener("DOMContentLoaded", scheduleSize);
  scheduleSize();

  /* Exposed for unit testing the pure height formula and re-measuring on demand. */
  window.cerebroFill = { _targetHeight: targetHeight, resize: scheduleSize };
})();

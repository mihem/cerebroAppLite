# Projection viewport sizing implementation plan

> **For AI agent workers:** Required sub-skill: use superpowers:executing-plans to implement this plan task by task. Track progress with the checkboxes below.

**Goal:** Make every projection fill its actual remaining viewport height without overflowing when legends wrap, while preserving Spatial point/background registration.

**Architecture:** Add a pure height calculator and a DOM-driven resize controller to the shared projection renderer. Projection UIs provide only a safe first-paint height; after render, measured legend, footer, box, and viewport geometry determine the live Plotly height.

**Tech stack:** JavaScript, Shiny htmlwidgets/Plotly, R testthat, Node syntax checks

---

## File structure

- Modify `inst/shiny/v1.4/www/projection_scatter.js`: own the shared height calculation, observers, and resize scheduling.
- Modify projection UI files: replace tab-specific viewport subtraction formulas with one shared first-paint class/height contract.
- Create `tests/testthat/test-projection-viewport-sizing.R`: verify the shared source contract and pure sizing cases.

### Task 1: Specify dynamic sizing behavior with failing tests

**Files:**
- Create: `tests/testthat/test-projection-viewport-sizing.R`

- [ ] **Step 1: Write failing source-contract tests**

Add tests that load `projection_scatter.js` and assert it defines
`projectionTargetHeight`, accounts for measured content below the widget, uses
`ResizeObserver`, and triggers Spatial's existing background sync through a
Plotly resize. Load all four projection UIs and assert no
`calc(100vh - <number>px)` remains.

- [ ] **Step 2: Run the focused test and verify red**

Run:

```bash
Rscript -e 'testthat::test_file("tests/testthat/test-projection-viewport-sizing.R")'
```

Expected: FAIL because the shared calculator/controller does not exist and fixed
height formulas remain.

- [ ] **Step 3: Commit the red test**

```bash
git add tests/testthat/test-projection-viewport-sizing.R
git commit -m "test: specify projection viewport sizing"
```

### Task 2: Implement the shared measured-height controller

**Files:**
- Modify: `inst/shiny/v1.4/www/projection_scatter.js`
- Modify: `inst/shiny/v1.4/overview/UI_projection.R`
- Modify: `inst/shiny/v1.4/gene_expression/UI_projection.R`
- Modify: `inst/shiny/v1.4/spatial/UI_projection.R`
- Modify: `inst/shiny/v1.4/trajectory/projection.R`
- Test: `tests/testthat/test-projection-viewport-sizing.R`

- [ ] **Step 1: Add the pure calculator**

Implement a function with the contract:

```javascript
function projectionTargetHeight(viewportHeight, wrapperTop, contentBelow, bottomGap, minimumHeight) {
  const available = Math.floor(viewportHeight - wrapperTop - contentBelow - bottomGap);
  return Math.max(minimumHeight, available);
}
```

- [ ] **Step 2: Add idempotent resize scheduling and observation**

Create per-plot controller state. Measure the htmlwidget wrapper, containing
`.box`, content beneath the wrapper, and viewport. Apply changed heights to the
wrapper and plot div, then call `Plotly.Plots.resize`. Observe the containing box
and legend with `ResizeObserver`, listen to window resize once, and schedule all
updates with `requestAnimationFrame` to avoid observer feedback loops.

- [ ] **Step 3: Trigger sizing at every content transition**

Schedule sizing after categorical/continuous legend creation or removal and
after each successful `Plotly.react`. Spatial continues to use its existing
`plotly_afterplot` handler, which remaps the background through the resized
Plotly axes.

- [ ] **Step 4: Remove fixed per-tab formulas**

Give each `plotlyOutput` the same conservative initial height and a shared CSS
class or data contract. Do not retain separate 235/280/300px offsets.

- [ ] **Step 5: Run focused tests and JavaScript syntax validation**

```bash
Rscript -e 'testthat::test_file("tests/testthat/test-projection-viewport-sizing.R")'
node --check inst/shiny/v1.4/www/projection_scatter.js
node --check inst/shiny/v1.4/spatial/js_spatial_background.js
```

Expected: all tests PASS and both syntax checks exit 0.

- [ ] **Step 6: Run spatial and app source regression tests**

```bash
Rscript -e 'testthat::test_file("tests/testthat/test-spatial.R"); testthat::test_file("tests/testthat/test-app-new-modules.R")'
```

Expected: PASS with no new failures.

- [ ] **Step 7: Commit the implementation**

```bash
git add inst/shiny/v1.4/www/projection_scatter.js \
  inst/shiny/v1.4/overview/UI_projection.R \
  inst/shiny/v1.4/gene_expression/UI_projection.R \
  inst/shiny/v1.4/spatial/UI_projection.R \
  inst/shiny/v1.4/trajectory/projection.R
git commit -m "fix: size projections to available viewport"
```

### Task 3: Final regression verification

- [ ] **Step 1: Run the complete test suite**

```bash
Rscript -e 'devtools::test()'
```

Expected: no failures attributable to projection sizing.

- [ ] **Step 2: Inspect final diff and spatial registration invariants**

```bash
git diff HEAD~2..HEAD --check
rg -n "l2p|plotly_afterplot|applySpatialBackground" inst/shiny/v1.4/spatial/js_spatial_background.js
```

Expected: clean diff; data-to-pixel mapping and afterplot hook remain present.

### Task 4: Harden unwrapped outputs and Trajectory page structure

**Files:**
- Modify: `inst/shiny/v1.4/www/projection_scatter.js`
- Modify: `inst/shiny/v1.4/trajectory/UI.R`
- Modify: `inst/shiny/v1.4/trajectory/projection.R`
- Modify: `inst/shiny/v1.4/trajectory/select_method_and_name.R`
- Test: `tests/testthat/test-projection-viewport-sizing.R`
- Test: `tests/testthat/test-app-trajectory.R`

- [x] Remove the incorrectly rendered `cerebro-projection-plot` tag-list value.
- [x] Resolve the sizing element as the explicit spinner wrapper or Plotly div,
  never an arbitrary parent such as Trajectory's whole box body.
- [x] Move method and trajectory selectors into Main parameters.
- [x] Verify on the real PBMC app that both controls belong to Main parameters,
  no marker text is visible, and the projection box bottom is within viewport.
- [x] Verify and fix Plotly's internal SVG dimensions: relayout explicit width
  and height so axis tick labels remain inside the plot and above its footer.

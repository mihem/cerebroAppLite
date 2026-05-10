# R6 class in which data sets will be stored for visualization in Cerebro.

A `Cerebro_v1.3` object is an R6 class that contains several types of
data that can be visualized in Cerebro.

## Value

A new `Cerebro_v1.3` object.

## Public fields

- `version`:

  cerebroApp version that was used to create the object.

- `experiment`:

  `list` that contains meta data about the data set, including
  experiment name, species, date of export.

- `technical_info`:

  `list` that contains technical information about the analysis,
  including the R session info.

- `parameters`:

  `list` that contains important parameters that were used during the
  analysis, e.g. cut-off values for cell filtering.

- `groups`:

  `list` that contains specified grouping variables and and the group
  levels (subgroups) that belong to each of them. For each grouping
  variable, a corresponding column with the same name must exist in the
  meta data.

- `cell_cycle`:

  `vector` that contains the name of columns in the meta data that
  contain cell cycle assignments.

- `gene_lists`:

  `list` that contains gene lists, e.g. mitochondrial and/or ribosomal
  genes.

- `expression`:

  `matrix`-like object that holds transcript counts.

- `meta_data`:

  `data.frame` that contains cell meta data.

- `projections`:

  `list` that contains projections/dimensional reductions.

- `most_expressed_genes`:

  `list` that contains a `data.frame` holding the most expressed genes
  for each grouping variable that was specified during the call to
  [`getMostExpressedGenes`](https://mihem.github.io/cerebroAppLite/reference/getMostExpressedGenes.md).

- `marker_genes`:

  `list` that contains a `list` for every method that was used to
  calculate marker genes, and a `data.frame` for each grouping variable,
  e.g. those that were specified during the call to
  [`getMarkerGenes`](https://mihem.github.io/cerebroAppLite/reference/getMarkerGenes.md).

- `enriched_pathways`:

  `list` that contains a `list` for every method that was used to
  calculate marker genes, and a `data.frame` for each grouping variable,
  e.g. those that were specified during the call to
  [`getEnrichedPathways`](https://mihem.github.io/cerebroAppLite/reference/getEnrichedPathways.md)
  or
  [`performGeneSetEnrichmentAnalysis`](https://mihem.github.io/cerebroAppLite/reference/performGeneSetEnrichmentAnalysis.md).

- `trees`:

  `list` that contains a phylogenetic tree (class `phylo`) for grouping
  variables.

- `trajectories`:

  `list` that contains a `list` for every method that was used to
  calculate trajectories, and, depending on the method, a `data.frame`
  or `list` for each specific trajectory, e.g. those extracted with
  [`extractMonocleTrajectory`](https://mihem.github.io/cerebroAppLite/reference/extractMonocleTrajectory.md).

- `extra_material`:

  `list` that can contain additional material related to the data set;
  tables should be stored in `data.frame` format in a named `list`
  called \`tables\`

## Methods

### Public methods

- [`Cerebro_v1.3$new()`](#method-Cerebro_v1.3-new)

- [`Cerebro_v1.3$setVersion()`](#method-Cerebro_v1.3-setVersion)

- [`Cerebro_v1.3$getVersion()`](#method-Cerebro_v1.3-getVersion)

- [`Cerebro_v1.3$checkIfGroupExists()`](#method-Cerebro_v1.3-checkIfGroupExists)

- [`Cerebro_v1.3$checkIfColumnExistsInMetadata()`](#method-Cerebro_v1.3-checkIfColumnExistsInMetadata)

- [`Cerebro_v1.3$addExperiment()`](#method-Cerebro_v1.3-addExperiment)

- [`Cerebro_v1.3$getExperiment()`](#method-Cerebro_v1.3-getExperiment)

- [`Cerebro_v1.3$addParameters()`](#method-Cerebro_v1.3-addParameters)

- [`Cerebro_v1.3$getParameters()`](#method-Cerebro_v1.3-getParameters)

- [`Cerebro_v1.3$addTechnicalInfo()`](#method-Cerebro_v1.3-addTechnicalInfo)

- [`Cerebro_v1.3$getTechnicalInfo()`](#method-Cerebro_v1.3-getTechnicalInfo)

- [`Cerebro_v1.3$addGroup()`](#method-Cerebro_v1.3-addGroup)

- [`Cerebro_v1.3$getGroups()`](#method-Cerebro_v1.3-getGroups)

- [`Cerebro_v1.3$getGroupLevels()`](#method-Cerebro_v1.3-getGroupLevels)

- [`Cerebro_v1.3$setMetaData()`](#method-Cerebro_v1.3-setMetaData)

- [`Cerebro_v1.3$getMetaData()`](#method-Cerebro_v1.3-getMetaData)

- [`Cerebro_v1.3$addGeneList()`](#method-Cerebro_v1.3-addGeneList)

- [`Cerebro_v1.3$getGeneLists()`](#method-Cerebro_v1.3-getGeneLists)

- [`Cerebro_v1.3$setExpression()`](#method-Cerebro_v1.3-setExpression)

- [`Cerebro_v1.3$getCellNames()`](#method-Cerebro_v1.3-getCellNames)

- [`Cerebro_v1.3$getGeneNames()`](#method-Cerebro_v1.3-getGeneNames)

- [`Cerebro_v1.3$getMeanExpressionForGenes()`](#method-Cerebro_v1.3-getMeanExpressionForGenes)

- [`Cerebro_v1.3$getMeanExpressionForCells()`](#method-Cerebro_v1.3-getMeanExpressionForCells)

- [`Cerebro_v1.3$getExpressionMatrix()`](#method-Cerebro_v1.3-getExpressionMatrix)

- [`Cerebro_v1.3$setCellCycle()`](#method-Cerebro_v1.3-setCellCycle)

- [`Cerebro_v1.3$getCellCycle()`](#method-Cerebro_v1.3-getCellCycle)

- [`Cerebro_v1.3$addProjection()`](#method-Cerebro_v1.3-addProjection)

- [`Cerebro_v1.3$availableProjections()`](#method-Cerebro_v1.3-availableProjections)

- [`Cerebro_v1.3$getProjection()`](#method-Cerebro_v1.3-getProjection)

- [`Cerebro_v1.3$addTree()`](#method-Cerebro_v1.3-addTree)

- [`Cerebro_v1.3$getTree()`](#method-Cerebro_v1.3-getTree)

- [`Cerebro_v1.3$addMostExpressedGenes()`](#method-Cerebro_v1.3-addMostExpressedGenes)

- [`Cerebro_v1.3$getGroupsWithMostExpressedGenes()`](#method-Cerebro_v1.3-getGroupsWithMostExpressedGenes)

- [`Cerebro_v1.3$getMostExpressedGenes()`](#method-Cerebro_v1.3-getMostExpressedGenes)

- [`Cerebro_v1.3$addMarkerGenes()`](#method-Cerebro_v1.3-addMarkerGenes)

- [`Cerebro_v1.3$getMethodsForMarkerGenes()`](#method-Cerebro_v1.3-getMethodsForMarkerGenes)

- [`Cerebro_v1.3$getGroupsWithMarkerGenes()`](#method-Cerebro_v1.3-getGroupsWithMarkerGenes)

- [`Cerebro_v1.3$getMarkerGenes()`](#method-Cerebro_v1.3-getMarkerGenes)

- [`Cerebro_v1.3$addEnrichedPathways()`](#method-Cerebro_v1.3-addEnrichedPathways)

- [`Cerebro_v1.3$getMethodsForEnrichedPathways()`](#method-Cerebro_v1.3-getMethodsForEnrichedPathways)

- [`Cerebro_v1.3$getGroupsWithEnrichedPathways()`](#method-Cerebro_v1.3-getGroupsWithEnrichedPathways)

- [`Cerebro_v1.3$getEnrichedPathways()`](#method-Cerebro_v1.3-getEnrichedPathways)

- [`Cerebro_v1.3$addTrajectory()`](#method-Cerebro_v1.3-addTrajectory)

- [`Cerebro_v1.3$getMethodsForTrajectories()`](#method-Cerebro_v1.3-getMethodsForTrajectories)

- [`Cerebro_v1.3$getNamesOfTrajectories()`](#method-Cerebro_v1.3-getNamesOfTrajectories)

- [`Cerebro_v1.3$getTrajectory()`](#method-Cerebro_v1.3-getTrajectory)

- [`Cerebro_v1.3$addExtraMaterial()`](#method-Cerebro_v1.3-addExtraMaterial)

- [`Cerebro_v1.3$addExtraTable()`](#method-Cerebro_v1.3-addExtraTable)

- [`Cerebro_v1.3$addExtraPlot()`](#method-Cerebro_v1.3-addExtraPlot)

- [`Cerebro_v1.3$getExtraMaterialCategories()`](#method-Cerebro_v1.3-getExtraMaterialCategories)

- [`Cerebro_v1.3$checkForExtraTables()`](#method-Cerebro_v1.3-checkForExtraTables)

- [`Cerebro_v1.3$getNamesOfExtraTables()`](#method-Cerebro_v1.3-getNamesOfExtraTables)

- [`Cerebro_v1.3$getExtraTable()`](#method-Cerebro_v1.3-getExtraTable)

- [`Cerebro_v1.3$checkForExtraPlots()`](#method-Cerebro_v1.3-checkForExtraPlots)

- [`Cerebro_v1.3$getNamesOfExtraPlots()`](#method-Cerebro_v1.3-getNamesOfExtraPlots)

- [`Cerebro_v1.3$getExtraPlot()`](#method-Cerebro_v1.3-getExtraPlot)

- [`Cerebro_v1.3$print()`](#method-Cerebro_v1.3-print)

- [`Cerebro_v1.3$clone()`](#method-Cerebro_v1.3-clone)

------------------------------------------------------------------------

### Method `new()`

Create a new `Cerebro_v1.3` object.

#### Usage

    Cerebro_v1.3$new()

#### Returns

A new `Cerebro_v1.3` object.

------------------------------------------------------------------------

### Method `setVersion()`

Set the version of `cerebroApp` that was used to generate this object.

#### Usage

    Cerebro_v1.3$setVersion(version)

#### Arguments

- `version`:

  Version to set.

------------------------------------------------------------------------

### Method `getVersion()`

Get the version of `cerebroApp` that was used to generate this object.

#### Usage

    Cerebro_v1.3$getVersion()

#### Returns

Version as `package_version` class.

------------------------------------------------------------------------

### Method `checkIfGroupExists()`

Safety function that will check if a provided group name is present in
the `groups` field.

#### Usage

    Cerebro_v1.3$checkIfGroupExists(group_name)

#### Arguments

- `group_name`:

  Group name to be tested

------------------------------------------------------------------------

### Method `checkIfColumnExistsInMetadata()`

Safety function that will check if a provided group name is present in
the meta data.

#### Usage

    Cerebro_v1.3$checkIfColumnExistsInMetadata(group_name)

#### Arguments

- `group_name`:

  Group name to be tested.

------------------------------------------------------------------------

### Method `addExperiment()`

Add information to `experiment` field.

#### Usage

    Cerebro_v1.3$addExperiment(field, content)

#### Arguments

- `field`:

  Name of the information, e.g. `organism`.

- `content`:

  Actual information, e.g. `hg`.

------------------------------------------------------------------------

### Method `getExperiment()`

Retrieve information from `experiment` field.

#### Usage

    Cerebro_v1.3$getExperiment()

#### Returns

`list` of all entries in the `experiment` field.

------------------------------------------------------------------------

### Method `addParameters()`

Add information to `parameters` field.

#### Usage

    Cerebro_v1.3$addParameters(field, content)

#### Arguments

- `field`:

  Name of the information, e.g. `number_of_PCs`.

- `content`:

  Actual information, e.g. `30`.

------------------------------------------------------------------------

### Method `getParameters()`

Retrieve information from `parameters` field.

#### Usage

    Cerebro_v1.3$getParameters()

#### Returns

`list` of all entries in the `parameters` field.

------------------------------------------------------------------------

### Method `addTechnicalInfo()`

Add information to `technical_info` field.

#### Usage

    Cerebro_v1.3$addTechnicalInfo(field, content)

#### Arguments

- `field`:

  Name of the information, e.g. `R`.

- `content`:

  Actual information, e.g. `4.0.2`.

------------------------------------------------------------------------

### Method `getTechnicalInfo()`

Retrieve information from `technical_info` field.

#### Usage

    Cerebro_v1.3$getTechnicalInfo()

#### Returns

`list` of all entries in the `technical_info` field.

------------------------------------------------------------------------

### Method `addGroup()`

Add group to the groups registered in the `groups` field.

#### Usage

    Cerebro_v1.3$addGroup(group_name, levels)

#### Arguments

- `group_name`:

  Group name.

- `levels`:

  `vector` of group levels (subgroups).

------------------------------------------------------------------------

### Method `getGroups()`

Retrieve all names in the `groups` field.

#### Usage

    Cerebro_v1.3$getGroups()

#### Returns

`vector` of registered groups.

------------------------------------------------------------------------

### Method `getGroupLevels()`

Retrieve group levels for a group registered in the `groups` field.

#### Usage

    Cerebro_v1.3$getGroupLevels(group_name)

#### Arguments

- `group_name`:

  Group name for which to retrieve group levels.

#### Returns

`vector` of group levels.

------------------------------------------------------------------------

### Method `setMetaData()`

Set meta data for cells.

#### Usage

    Cerebro_v1.3$setMetaData(table)

#### Arguments

- `table`:

  `data.frame` that contains meta data for cells. The number of rows
  must be equal to the number of rows of projections and the number of
  columns in the transcript count matrix.

------------------------------------------------------------------------

### Method `getMetaData()`

Retrieve meta data for cells.

#### Usage

    Cerebro_v1.3$getMetaData()

#### Returns

`data.frame` containing meta data.

------------------------------------------------------------------------

### Method `addGeneList()`

Add a gene list to the `gene_lists`.

#### Usage

    Cerebro_v1.3$addGeneList(name, genes)

#### Arguments

- `name`:

  Name of the gene list.

- `genes`:

  `vector` of genes.

------------------------------------------------------------------------

### Method `getGeneLists()`

Retrieve gene lists from the `gene_lists`.

#### Usage

    Cerebro_v1.3$getGeneLists()

#### Returns

`list` of all entries in the `gene_lists` field.

------------------------------------------------------------------------

### Method `setExpression()`

Set transcript count matrix.

#### Usage

    Cerebro_v1.3$setExpression(counts)

#### Arguments

- `counts`:

  `matrix`-like object that contains transcript counts for cells in the
  data set. Number of columns must be equal to the number of rows in the
  `meta_data` field.

------------------------------------------------------------------------

### Method `getCellNames()`

Get names of all cells.

#### Usage

    Cerebro_v1.3$getCellNames()

#### Returns

`vector` containing all cell names/barcodes.

------------------------------------------------------------------------

### Method `getGeneNames()`

Get names of all genes in transcript count matrix.

#### Usage

    Cerebro_v1.3$getGeneNames()

#### Returns

`vector` containing all gene names in transcript count matrix.

------------------------------------------------------------------------

### Method `getMeanExpressionForGenes()`

Retrieve mean expression across all cells in the data set for a set of
genes.

#### Usage

    Cerebro_v1.3$getMeanExpressionForGenes(genes)

#### Arguments

- `genes`:

  Names of genes to extract; no default.

#### Returns

`data.frame` containing specified gene names and their respective mean
expression across all cells in the data set.

------------------------------------------------------------------------

### Method `getMeanExpressionForCells()`

Retrieve (mean) expression for a single gene or a set of genes for a
given set of cells.

#### Usage

    Cerebro_v1.3$getMeanExpressionForCells(cells = NULL, genes = NULL)

#### Arguments

- `cells`:

  Names/barcodes of cells to extract; defaults to `NULL`, which will
  return all cells.

- `genes`:

  Names of genes to extract; defaults to `NULL`, which will return all
  genes.

#### Returns

`vector` containing (mean) expression across all specified genes in each
specified cell.

------------------------------------------------------------------------

### Method `getExpressionMatrix()`

Retrieve transcript count matrix.

#### Usage

    Cerebro_v1.3$getExpressionMatrix(cells = NULL, genes = NULL)

#### Arguments

- `cells`:

  Names/barcodes of cells to extract; defaults to `NULL`, which will
  return all cells.

- `genes`:

  Names of genes to extract; defaults to `NULL`, which will return all
  genes.

#### Returns

Dense transcript count matrix for specified cells and genes.

------------------------------------------------------------------------

### Method `setCellCycle()`

Add columns containing cell cycle assignments to the `cell_cycle` field.

#### Usage

    Cerebro_v1.3$setCellCycle(cols)

#### Arguments

- `cols`:

  `vector` of columns names containing cell cycle assignments.

------------------------------------------------------------------------

### Method `getCellCycle()`

Retrieve column names containing cell cycle assignments.

#### Usage

    Cerebro_v1.3$getCellCycle()

#### Returns

`vector` of column names in meta data.

------------------------------------------------------------------------

### Method `addProjection()`

Add projections (dimensional reductions).

#### Usage

    Cerebro_v1.3$addProjection(name, projection)

#### Arguments

- `name`:

  Name of the projection.

- `projection`:

  `data.frame` containing positions of cells in projection.

------------------------------------------------------------------------

### Method `availableProjections()`

Get list of available projections (dimensional reductions).

#### Usage

    Cerebro_v1.3$availableProjections()

#### Returns

`vector` of projections / dimensional reductions that are available.

------------------------------------------------------------------------

### Method `getProjection()`

Retrieve data for a specific projection.

#### Usage

    Cerebro_v1.3$getProjection(name)

#### Arguments

- `name`:

  Name of projection.

#### Returns

`data.frame` containing the positions of cells in the projection.

------------------------------------------------------------------------

### Method `addTree()`

Add phylogenetic tree to `trees` field.

#### Usage

    Cerebro_v1.3$addTree(group_name, tree)

#### Arguments

- `group_name`:

  Group name that this tree belongs to.

- `tree`:

  Phylogenetic tree as `phylo` object.

------------------------------------------------------------------------

### Method `getTree()`

Retrieve phylogenetic tree for a specific group.

#### Usage

    Cerebro_v1.3$getTree(group_name)

#### Arguments

- `group_name`:

  Group name for which to retrieve phylogenetic tree.

#### Returns

Phylogenetic tree as `phylo` object.

------------------------------------------------------------------------

### Method `addMostExpressedGenes()`

Add table of most expressed genes.

#### Usage

    Cerebro_v1.3$addMostExpressedGenes(group_name, table)

#### Arguments

- `group_name`:

  Name of grouping variable that the most expressed genes belong to.
  Must be registered in the `groups` field.

- `table`:

  `data.frame` that contains the most expressed genes.

------------------------------------------------------------------------

### Method `getGroupsWithMostExpressedGenes()`

Retrieve names of grouping variables for which most expressed genes are
available.

#### Usage

    Cerebro_v1.3$getGroupsWithMostExpressedGenes()

#### Returns

`vector` of grouping variables for which most expressed genes are
available.

------------------------------------------------------------------------

### Method [`getMostExpressedGenes()`](https://mihem.github.io/cerebroAppLite/reference/getMostExpressedGenes.md)

Retrieve table of most expressed genes for a grouping variable.

#### Usage

    Cerebro_v1.3$getMostExpressedGenes(group_name)

#### Arguments

- `group_name`:

  Grouping variable for which most expressed genes should be retrieved.

#### Returns

`data.frame` that contains most expressed genes for group levels of the
specified grouping variable.

------------------------------------------------------------------------

### Method `addMarkerGenes()`

Add table of marker genes.

#### Usage

    Cerebro_v1.3$addMarkerGenes(method, name, table)

#### Arguments

- `method`:

  Name of method that was used to generate the marker genes.

- `name`:

  Name of table. This name will be used to select the table in Cerebro.
  It is recommended to use the grouping variable, e.g. `sample`.

- `table`:

  `data.frame` that contains the marker genes.

------------------------------------------------------------------------

### Method `getMethodsForMarkerGenes()`

Retrieve names of methods that were used to generate marker genes.

#### Usage

    Cerebro_v1.3$getMethodsForMarkerGenes()

#### Returns

`vector` of names of methods that were used to generate marker genes.

------------------------------------------------------------------------

### Method `getGroupsWithMarkerGenes()`

Retrieve grouping variables for which marker genes were generated using
a specified method.

#### Usage

    Cerebro_v1.3$getGroupsWithMarkerGenes(method)

#### Arguments

- `method`:

  Name of method.

#### Returns

`vector` of grouping variables for which marker genes were calculated
using the specified method.

------------------------------------------------------------------------

### Method [`getMarkerGenes()`](https://mihem.github.io/cerebroAppLite/reference/getMarkerGenes.md)

Retrieve table of marker genes for specific method and grouping
variable.

#### Usage

    Cerebro_v1.3$getMarkerGenes(method, name)

#### Arguments

- `method`:

  Name of method.

- `name`:

  Name of table.

#### Returns

`data.frame` that contains marker genes for the specified combination of
method and grouping variable.

------------------------------------------------------------------------

### Method `addEnrichedPathways()`

Add table of enriched pathways.

#### Usage

    Cerebro_v1.3$addEnrichedPathways(method, name, table)

#### Arguments

- `method`:

  Name of method that was used to generate the enriched pathways.

- `name`:

  Name of table. This name will be used to select the table in Cerebro.
  It is recommended to use the grouping variable, e.g. `sample`.

- `table`:

  `data.frame` that contains the enriched pathways.

------------------------------------------------------------------------

### Method `getMethodsForEnrichedPathways()`

Retrieve names of methods that were used to generate enriched pathways.

#### Usage

    Cerebro_v1.3$getMethodsForEnrichedPathways()

#### Returns

`vector` of names of methods that were used to generate enriched
pathways.

------------------------------------------------------------------------

### Method `getGroupsWithEnrichedPathways()`

Retrieve grouping variables for which enriched pathways were generated
using a specified method.

#### Usage

    Cerebro_v1.3$getGroupsWithEnrichedPathways(method)

#### Arguments

- `method`:

  Name of method.

#### Returns

`vector` of grouping variables for which enriched pathways were
calculated using the specified method.

------------------------------------------------------------------------

### Method [`getEnrichedPathways()`](https://mihem.github.io/cerebroAppLite/reference/getEnrichedPathways.md)

Retrieve table of enriched pathways for specific method and grouping
variable.

#### Usage

    Cerebro_v1.3$getEnrichedPathways(method, name)

#### Arguments

- `method`:

  Name of method.

- `name`:

  Grouping variable.

#### Returns

`data.frame` that contains enriched pathways for the specified
combination of method and grouping variable.

------------------------------------------------------------------------

### Method `addTrajectory()`

Add trajectory.

#### Usage

    Cerebro_v1.3$addTrajectory(method, name, content)

#### Arguments

- `method`:

  Name of method that was used to generate the trajectory.

- `name`:

  Name of the trajectory. This name will be used later in Cerebro to
  select the trajectory.

- `content`:

  Relevant data for the trajectory, depending on the method this could
  be a `list` holding edges, cell positions, pseudotime, etc.

------------------------------------------------------------------------

### Method `getMethodsForTrajectories()`

Retrieve names of methods that were used to generate trajectories.

#### Usage

    Cerebro_v1.3$getMethodsForTrajectories()

#### Returns

`vector` of names of methods that were used to generate trajectories.

------------------------------------------------------------------------

### Method `getNamesOfTrajectories()`

Retrieve names of available trajectories for a specified method.

#### Usage

    Cerebro_v1.3$getNamesOfTrajectories(method)

#### Arguments

- `method`:

  Name of method.

#### Returns

`vector` of available trajectory for the specified method.

------------------------------------------------------------------------

### Method `getTrajectory()`

Retrieve data for a specific trajectory.

#### Usage

    Cerebro_v1.3$getTrajectory(method, name)

#### Arguments

- `method`:

  Name of method.

- `name`:

  Name of trajectory.

#### Returns

The type of data depends on the method that was used to generate the
trajectory.

------------------------------------------------------------------------

### Method `addExtraMaterial()`

Add content to extra material field.

#### Usage

    Cerebro_v1.3$addExtraMaterial(category, name, content)

#### Arguments

- `category`:

  Name of category. At the moment, only `tables` and `plots` are valid
  categories. Tables must be in `data.frame` format and plots must be
  created with `ggplot2`.

- `name`:

  Name of material, will be used to select it in Cerebro.

- `content`:

  Data that should be added.

------------------------------------------------------------------------

### Method `addExtraTable()`

Add table to \`extra_material\` slot.

#### Usage

    Cerebro_v1.3$addExtraTable(name, table)

#### Arguments

- `name`:

  Name of material, will be used to select it in Cerebro.

- `table`:

  Table that should be added, must be `data.frame`.

------------------------------------------------------------------------

### Method `addExtraPlot()`

Add plot to \`extra_material\` slot.

#### Usage

    Cerebro_v1.3$addExtraPlot(name, plot)

#### Arguments

- `name`:

  Name of material, will be used to select it in Cerebro.

- `plot`:

  Plot that should be added, must be created with `ggplot2` (class:
  `ggplot`).

------------------------------------------------------------------------

### Method `getExtraMaterialCategories()`

Get names of categories for which extra material is available.

#### Usage

    Cerebro_v1.3$getExtraMaterialCategories()

#### Returns

`vector` with names of available categories.

------------------------------------------------------------------------

### Method `checkForExtraTables()`

Check whether there are tables in the extra materials.

#### Usage

    Cerebro_v1.3$checkForExtraTables()

#### Returns

`logical` indicating whether there are tables in the extra materials.

------------------------------------------------------------------------

### Method `getNamesOfExtraTables()`

Get names of tables in extra materials.

#### Usage

    Cerebro_v1.3$getNamesOfExtraTables()

#### Returns

`vector` containing names of tables in extra materials.

------------------------------------------------------------------------

### Method `getExtraTable()`

Get table from extra materials.

#### Usage

    Cerebro_v1.3$getExtraTable(name)

#### Arguments

- `name`:

  Name of table.

#### Returns

Requested table in `data.frame` format.

------------------------------------------------------------------------

### Method `checkForExtraPlots()`

Check whether there are plots in the extra materials.

#### Usage

    Cerebro_v1.3$checkForExtraPlots()

#### Returns

`logical` indicating whether there are plots in the extra materials.

------------------------------------------------------------------------

### Method `getNamesOfExtraPlots()`

Get names of plots in extra materials.

#### Usage

    Cerebro_v1.3$getNamesOfExtraPlots()

#### Returns

`vector` containing names of plots in extra materials.

------------------------------------------------------------------------

### Method `getExtraPlot()`

Get plot from extra materials.

#### Usage

    Cerebro_v1.3$getExtraPlot(name)

#### Arguments

- `name`:

  Name of plot.

#### Returns

Requested plot made with `ggplot2`.

------------------------------------------------------------------------

### Method [`print()`](https://rdrr.io/r/base/print.html)

Show overview of object and the data it contains. Print overview of
available marker gene results for `self$print()` function. Print
overview of available enriched pathway results for `self$print()`
function. Print overview of available trajectories for `self$print()`
function. Print overview of extra material for `self$print()` function.

#### Usage

    Cerebro_v1.3$print()

------------------------------------------------------------------------

### Method `clone()`

The objects of this class are cloneable with this method.

#### Usage

    Cerebro_v1.3$clone(deep = FALSE)

#### Arguments

- `deep`:

  Whether to make a deep clone.
